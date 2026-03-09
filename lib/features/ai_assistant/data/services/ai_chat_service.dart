import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../features/shelf/data/models/shelf_model.dart';

// ─── API constants ────────────────────────────────────────────────────────────

const _kBaseUrl = 'https://llm.alem.ai/v1/chat/completions';
const _kQwen3Key = 'sk-wiJgFZNHp5LUGeV3pVNNMA';
const _kQwen3Model = 'qwen3';

const _kMetricLabels = {
  'sebumBalance': 'баланс себума',
  'elasticity': 'эластичность',
  'hydration': 'увлажнённость',
  'smoothness': 'гладкость',
  'skinClarity': 'чистота кожи',
  'porePurity': 'чистота пор',
  'evenTone': 'ровный тон',
};

// ─── User context ─────────────────────────────────────────────────────────────

class UserContext {
  const UserContext({
    required this.skinType,
    required this.goal,
    required this.morningProducts,
    required this.eveningProducts,
    required this.recentMetrics,
  });

  final String skinType;
  final String goal;
  final String morningProducts;
  final String eveningProducts;
  final String recentMetrics;

  String get shelfBlock =>
      'Утренний уход: $morningProducts\nВечерний уход: $eveningProducts';
}

// ─── Service ──────────────────────────────────────────────────────────────────

class AiChatService {
  AiChatService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FirebaseStorage.instance;

  // ── Context ───────────────────────────────────────────────────────────────

  /// Fetches skinType, goal, shelf and last 7 metric assessments for the user.
  static Future<UserContext> buildUserContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    final skinType = (data['skinType'] as String?)?.trim() ?? 'не указан';
    final goal = (data['goal'] as String?)?.trim() ?? 'не указана';

    final rawShelf = data['shelf'];
    final shelf = rawShelf != null
        ? ShelfModel.fromJson(rawShelf as Map<String, dynamic>)
        : ShelfModel.empty();

    final morningProducts = shelf.my.morning.isEmpty
        ? 'нет средств'
        : shelf.my.morning.map((p) => '${p.name} (${p.category})').join(', ');

    final eveningProducts = shelf.my.evening.isEmpty
        ? 'нет средств'
        : shelf.my.evening.map((p) => '${p.name} (${p.category})').join(', ');

    // Last 7 assessments, ordered by date descending (doc ID = YYYY-MM-DD).
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('daily_assessments')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(7)
        .get();

    final metricLines = snap.docs
        .map((d) {
          final raw = d.data();
          final metrics = raw['metrics'] as Map<String, dynamic>? ?? {};
          final parts = metrics.entries
              .where((e) => e.value != null)
              .map((e) => '${_kMetricLabels[e.key] ?? e.key}: ${e.value}')
              .join(', ');
          return '${d.id}: $parts';
        })
        .join('\n  ');

    return UserContext(
      skinType: skinType,
      goal: goal,
      morningProducts: morningProducts,
      eveningProducts: eveningProducts,
      recentMetrics: metricLines.isEmpty ? 'нет данных' : metricLines,
    );
  }

  // ── Image upload ──────────────────────────────────────────────────────────

  /// Uploads [localPath] to `users/{uid}/ai_temp/` and returns the download URL.
  static Future<String> uploadTempImage(String localPath) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('users/$uid/ai_temp/$timestamp.jpg');
    final bytes = await XFile(localPath).readAsBytes();
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await snapshot.ref.getDownloadURL();

    // Schedule cleanup after 5 minutes — fire and forget.
    Future.delayed(const Duration(minutes: 5), () {
      ref.delete().catchError((_) {});
    });

    return url;
  }

  // ── General chat (qwen3, multi-turn, optional image) ─────────────────────

  static Future<String> sendGeneralChat({
    required List<Map<String, String>> history,
    required UserContext ctx,
    String? imageUrl, // optional — qwen3 multimodal when provided
  }) async {
    final systemPrompt =
        '''Ты — AI ассистент по уходу за кожей в мобильном приложении.
Тон общения мягкий и дружелюбный.

Твоя задача:
— помогать пользователю разбираться в уходе за кожей
— объяснять свойства косметических ингредиентов
— анализировать косметические продукты
— давать рекомендации по уходу

Тебе передается контекст пользователя:
— тип кожи ${ctx.skinType}
— цель ухода ${ctx.goal}
— метрики кожи (если есть) ${ctx.recentMetrics}
— текущие средства пользователя (его полка) ${ctx.shelfBlock}


Используй этот контекст при ответах, если он передан.

ПРОВЕРКА ТЕМЫ ВОПРОСА

Сначала проанализируй запрос пользователя.

Если вопрос НЕ связан с уходом за кожей, косметикой, ингредиентами или состоянием кожи — ответь только:

"Я могу помогать только с вопросами об уходе за кожей, давай вернемся к этому."

После этого не продолжай ответ.

ПРАВИЛА

1. Ты не врач и не ставишь медицинских диагнозов.
2. Отвечай простым и понятным языком.
3. Ответ должен быть коротким и полезным.
4. Не пиши длинные абзацы.
5. Если информации недостаточно — задай уточняющий вопрос.
6. Всегда объясняй причину рекомендации.
7. Используй дружелюбный и спокойный тон.
8. Не придумывай информацию. Если ты не уверен — честно скажи об этом.
9. Не используй сложные медицинские термины.

ЕСЛИ ПОЛЬЗОВАТЕЛЬ СПРАШИВАЕТ ПРО ИНГРЕДИЕНТ

— объясни его функцию
— возможные плюсы
— возможные риски для кожи

ЕСЛИ ПОЛЬЗОВАТЕЛЬ СПРАШИВАЕТ ПРО КОСМЕТИЧЕСКИЙ ПРОДУКТ

— объясни ключевые активные ингредиенты
— скажи для какого типа кожи продукт подходит
— кратко объясни зачем он используется

ОГРАНИЧЕНИЕ ОТВЕТА

Ответ должен:
— быть коротким
— не содержать длинных объяснений
— не выходить за тему ухода за кожей''';

    final List<Map<String, dynamic>> messages = [
      {'role': 'system', 'content': systemPrompt},
    ];

    for (var i = 0; i < history.length; i++) {
      final m = history[i];
      // If an image was attached, inject it into the last user message.
      if (imageUrl != null && i == history.length - 1 && m['role'] == 'user') {
        final textContent = m['content'] ?? '';
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'image_url', 'image_url': imageUrl},
            if (textContent.isNotEmpty) {'type': 'text', 'text': textContent},
          ],
        });
      } else {
        messages.add(Map<String, dynamic>.from(m));
      }
    }

    return _callQwen3Messages(messages);
  }

  // ── Skin photo analysis (qwen3, one-shot) ─────────────────────────────────

  static Future<String> sendSkinPhotoAnalysis({
    required String imageUrl,
    required String userText,
    required UserContext ctx,
  }) async {
    final prompt =
        '''Ты — AI ассистент по уходу за кожей в мобильном приложении.
Тон общения мягкий и дружелюбный.

Пользователь отправил фотографию лица для анализа состояния кожи.

Тебе может передаваться контекст пользователя:
— тип кожи   ${ctx.skinType}
— цель ухода  ${ctx.goal}
— метрики кожи  ${ctx.recentMetrics}
— полка пользователя (средства ухода)   ${ctx.shelfBlock}


ПРОВЕРКА КАЧЕСТВА ФОТОГРАФИИ

Проверь изображение.

Если лицо занимает меньше 50% кадра, ответь только:
"Не удалось корректно распознать лицо."

Если выполняется хотя бы одно из условий:
— фото размыто  
— лицо повернуто не фронтально  
— освещение очень слабое  

ответь только:
"Качество фотографии недостаточно для анализа кожи. Пожалуйста сделайте фото при хорошем освещении, держа камеру прямо перед лицом."

После этого НЕ продолжай анализ.

ПРАВИЛА АНАЛИЗА КОЖИ

Анализируй зоны лица:
— лоб  
— нос  
— щеки  
— подбородок

Ты можешь отметить только признаки, которые действительно могут быть видны на фото:
— возможная жирность  
— возможная сухость  
— неровный тон  
— расширенные поры  
— покраснения

Используй осторожные формулировки:
— может выглядеть  
— возможно заметно  
— может указывать на

Если признак не виден на фото — не упоминай его.

Никогда не придумывай признаки, которые не видны.

Не ставь медицинских диагнозов.

СВЯЗЬ С КОНТЕКСТОМ

Если переданы метрики кожи — кратко соотнеси наблюдения с ними.

Если передана полка пользователя:
— оцени, может ли текущий уход помогать
— не предлагай активные ингредиенты, которые уже используются

ПРАВИЛА РЕКОМЕНДАЦИЙ

Если кожа выглядит стабильной:
— не давай медицинских советов и не ставь диагнозы 
— не предлагай новые активные ингредиенты
— не предлагай менять уход
— можно отметить, что текущий уход может выглядеть сбалансированным
— рекомендация должна быть направлена только на поддержание состояния кожи

Если есть особенности кожи — дай мягкую рекомендацию по уходу.

СТРОГОЕ ОГРАНИЧЕНИЕ ОТВЕТА

Ответ должен:
— содержать максимум 15 предложений
— быть кратким и понятным
— не содержать длинных объяснений
— не добавлять новые разделы

ФОРМАТ ОТВЕТА

Наблюдения: …

Связь с метриками: …

Связь с текущим уходом: …

Что это может означать: …

Рекомендация: …


Если ты не уверен в наблюдении — не упоминай его.


Не прописывай названия каждого блока в формате ответа. 
просто строй свой ответ на основе этой структуры.''';

    return _callMultimodal(imageUrl: imageUrl, promptText: prompt);
  }

  // ── Product photo analysis (qwen3, one-shot) ──────────────────────────────

  static Future<String> sendProductPhotoAnalysis({
    required String imageUrl,
    required String userText,
    required UserContext ctx,
  }) async {
    final prompt =
        '''Сначала определи тип ингредиентов:
— активные ингредиенты (кислоты, ретиноиды, ниацинамид, витамин C и т.д.)
— вспомогательные ингредиенты (эмоленты, увлажнители, стабилизаторы)
— базовые ингредиенты (вода, растворители)

Фокусируйся только на активных и потенциально проблемных ингредиентах.
Игнорируй базовые компоненты, если они не влияют на кожу.
Если ингредиент неизвестен — скажи что информация ограничена.
Не придумывай свойства ингредиентов.

Также тебе передается контекст пользователя:
— тип кожи: ${ctx.skinType}
— цель ухода: ${ctx.goal}
— текущие метрики кожи:
  ${ctx.recentMetrics}
— средства, которые уже есть в его уходе (полка):
  ${ctx.shelfBlock}

Твоя задача:
Определи основные активные ингредиенты в составе.
Кратко объясни их действие.
Укажи возможные раздражающие или проблемные компоненты.
Скажи для какого типа кожи продукт обычно подходит.
Проанализируй текущий уход пользователя (его полку).
На основе контекста пользователя и его ухода сделай вывод — подходит ли этот продукт именно этому пользователю.

Учитывай:
— тип кожи пользователя
— цели ухода
— текущее состояние кожи (метрики)
— возможные конфликты с его текущими средствами

Если состав не содержит выраженных активных ингредиентов — скажи об этом.
Если ты не уверен в каком-то ингредиенте — не придумывай.

Формат ответа:
Активные ингредиенты:
— (ингредиент + краткое действие)

Потенциальные риски:
— (ингредиенты которые могут вызывать раздражение или конфликт)

Обычно подходит для:
— (тип кожи)

Совместимость с текущим уходом:
— (есть ли конфликты с продуктами пользователя)

Подходит ли пользователю:
— (учитывая его тип кожи, цель и текущий уход)

Итог:
— краткий вывод стоит ли пользователю использовать это средство и почему${userText.isNotEmpty ? '\n\nДополнительный комментарий пользователя: $userText' : ''}''';

    return _callMultimodal(imageUrl: imageUrl, promptText: prompt);
  }

  // ── Routine pick (qwen3, one-shot) ───────────────────────────────────────

  static Future<String> sendRoutinePick({
    required String userText,
    required UserContext ctx,
  }) async {
    final String prompt;

    if (userText.trim().isEmpty) {
      prompt =
          '''Ты — AI ассистент по уходу за кожей в мобильном приложении.
Тон общения мягкий и дружелюбный.

Пользователь хочет подобрать уход за кожей.

Тебе передается контекст пользователя:
— тип кожи: ${ctx.skinType}
— цель ухода: ${ctx.goal}
— текущие метрики кожи: ${ctx.recentMetrics}
— текущие средства пользователя (его полка): ${ctx.shelfBlock}

Если это не передано в контексте
— тип кожи
— цель ухода
— текущие метрики кожи

Добавь в начало сообщения:
"Информация может быть не точной из за недостатка информации"

ТВОЯ ЗАДАЧА

1. Проанализировать состояние кожи пользователя на основе переданного контекста.
2. Определить основные задачи ухода.
3. Проанализировать текущие средства пользователя и определить:
   — какие средства уже подходят
   — чего может не хватать
   — есть ли лишние или дублирующиеся средства.
4. Составить простую и понятную рутину ухода.
5. Рекомендовать конкретные средства.

Важно:
Не разделяй анализ кожи и не объясняй пользователю что ты его сделал.
Ты должен использовать анализ только для того, чтобы подобрать подходящий уход.

ПРАВИЛА СТРУКТУРЫ УХОДА

Рутина должна соответствовать общепринятой структуре ухода за кожей.

Утром и вечером обязательно должны быть:

1. очищение (умывалка)
2. увлажнение (крем)

Между ними может быть добавлен дополнительный шаг если он действительно нужен коже пользователя.

Ставь SPF всегда в конце утреннего списка и никогда не рекомендуй его на вечер.
ПРАВИЛА РЕКОМЕНДАЦИЙ



— всегда указывай полное название продукта (бренд + название средства)  
— не используй абстрактные шаги вроде "очищение", "крем", "увлажнение" без названия продукта  
— каждый шаг ухода должен содержать конкретный продукт  
— комментарий к каждому шагу должен быть максимум одно предложение  
— не предлагай слишком сложный уход  
— не ставь медицинских диагнозов  
— учитывай тип кожи, цель ухода и метрики кожи  
— если кожа пользователя выглядит в нормальном состоянии, предлагай поддерживающий уход без агрессивных изменений  
— если средство уже есть в полке пользователя, укажи его название  
— не упоминай и не рекомендуй активные ингредиенты  

СТРОГОЕ ОГРАНИЧЕНИЕ ОТВЕТА

Ответ должен:
— быть кратким и понятным  
— не содержать длинных объяснений  
— не добавлять новые разделы  

ФОРМАТ ОТВЕТА

Состояние кожи:
Максимум 2 предложения с оценкой состояния кожи на основе контекста.

Основные задачи ухода:
1–2 предложения.

Утренний уход:
Бренд + название продукта — короткое объяснение зачем этот шаг.

Вечерний уход:
Бренд + название продукта — короткое объяснение.

Итог:
Объяснение почему этот уход подходит пользователю.''';
    } else {
      prompt =
          '''Ты — AI ассистент по уходу за кожей в мобильном приложении.

Тон общения мягкий и дружелюбный.



Пользователь задает вопрос о подборе средства или конкретном шаге ухода.

Тебе передается контекст пользователя:
— текст запроса пользователя ${userText.trim()}
— тип кожи  ${ctx.skinType}
— цель ухода ${ctx.goal}
— последние оценки метрик кожи (если они есть)   ${ctx.recentMetrics}
— текущие средства пользователя (его полка)${ctx.shelfBlock}



ТВОЯ ЗАДАЧА

1. Проанализировать запрос пользователя.
2. Учитывая контекст пользователя:
   — тип кожи
   — состояние кожи
   — метрики кожи
   — текущие средства пользователя
дать точечную рекомендацию.

ПРАВИЛА РЕКОМЕНДАЦИЙ

— отвечай только на вопрос пользователя  
— не пересобирай весь уход  
— учитывай тип кожи, цель ухода и метрики кожи  
— учитывай средства которые уже есть у пользователя  
— если нужное средство уже есть на полке — предложи использовать его  
— если нужного средства нет — предложи конкретный продукт  
— не предлагай активные ингредиенты  
— объяснение должно быть кратким и понятным

СТРОГОЕ ОГРАНИЧЕНИЕ ОТВЕТА

Ответ должен:
— содержать максимум 12 предложений  
— быть кратким и понятным  
— НЕ ИПОЛЬЗОВАТЬ MARKDOWN в тексте
— не добавлять новые разделы  

ФОРМАТ ОТВЕТА

Рекомендация:
— конкретное средство или шаг ухода <Brand name> <Product Name>

Почему это подходит:
— краткое объяснение с учетом типа кожи, состояния кожи и цели ухода

Как использовать:
— когда применять (утро/вечер)  
— примерная частота использования''';
    }

    return _callQwen3Messages([
      {'role': 'user', 'content': prompt},
    ]);
  }

  // ── Private API helpers ───────────────────────────────────────────────────

  /// Sends any pre-built list of messages to qwen3 (supports multimodal content).
  static Future<String> _callQwen3Messages(
    List<Map<String, dynamic>> messages,
  ) async {
    final body = jsonEncode({'model': _kQwen3Model, 'messages': messages});

    final response = await http
        .post(
          Uri.parse(_kBaseUrl),
          headers: {
            'Authorization': 'Bearer $_kQwen3Key',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['choices']?[0]?['message']?['content'] ?? '') as String;
  }

  static Future<String> _callMultimodal({
    required String imageUrl,
    required String promptText,
  }) async {
    final body = jsonEncode({
      'model': _kQwen3Model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'image_url', 'image_url': imageUrl},
            {'type': 'text', 'text': promptText},
          ],
        },
      ],
    });

    final response = await http
        .post(
          Uri.parse(_kBaseUrl),
          headers: {
            'Authorization': 'Bearer $_kQwen3Key',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['choices']?[0]?['message']?['content'] ?? '') as String;
  }
}
