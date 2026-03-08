import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../../../../features/shelf/data/models/shelf_model.dart';

// ─── API constants ────────────────────────────────────────────────────────────

const _kBaseUrl = 'https://llm.alem.ai/v1/chat/completions';
const _kQwen3Key = 'sk-wiJgFZNHp5LUGeV3pVNNMA';
const _kGemma3Key = 'sk-9vEjfsCPLOKZ_Cqfkel6vA';
const _kQwen3Model = 'qwen3';
const _kGemma3Model = 'gemma3';

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
        : shelf.my.morning
            .map((p) => '${p.name} (${p.category})')
            .join(', ');

    final eveningProducts = shelf.my.evening.isEmpty
        ? 'нет средств'
        : shelf.my.evening
            .map((p) => '${p.name} (${p.category})')
            .join(', ');

    // Last 7 assessments, ordered by date descending (doc ID = YYYY-MM-DD).
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('daily_assessments')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(7)
        .get();

    final metricLines = snap.docs.map((d) {
      final raw = d.data();
      final metrics = raw['metrics'] as Map<String, dynamic>? ?? {};
      final parts = metrics.entries
          .where((e) => e.value != null)
          .map((e) => '${_kMetricLabels[e.key] ?? e.key}: ${e.value}')
          .join(', ');
      return '${d.id}: $parts';
    }).join('\n  ');

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
    final snapshot = await ref.putFile(
      File(localPath),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await snapshot.ref.getDownloadURL();

    // Schedule cleanup after 5 minutes — fire and forget.
    Future.delayed(const Duration(minutes: 5), () {
      ref.delete().catchError((_) {});
    });

    return url;
  }

  // ── General chat (gemma3, multi-turn) ────────────────────────────────────

  static Future<String> sendGeneralChat({
    required List<Map<String, String>> history,
    required UserContext ctx,
  }) async {
    final systemPrompt = '''Ты — AI ассистент по уходу за кожей в мобильном приложении.

Контекст пользователя:
— Тип кожи: ${ctx.skinType}
— Цель ухода: ${ctx.goal}
— Полка пользователя (средства, которые он использует):
  ${ctx.shelfBlock}
— Последние оценки состояния кожи (метрики):
  ${ctx.recentMetrics}

Отвечай кратко, понятно, используй только русский язык.
Не ставь медицинских диагнозов. Не придумывай факты.''';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
    ];

    return _callApi(model: _kGemma3Model, key: _kGemma3Key, messages: messages);
  }

  // ── Skin photo analysis (qwen3, one-shot) ─────────────────────────────────

  static Future<String> sendSkinPhotoAnalysis({
    required String imageUrl,
    required String userText,
    required UserContext ctx,
  }) async {
    final prompt = '''Пользователь отправил фотографию своего лица для анализа состояния кожи.

Также тебе передается контекст пользователя:
— тип кожи: ${ctx.skinType}
— цель ухода: ${ctx.goal}
— последние оценки метрик кожи (если они есть):
  ${ctx.recentMetrics}
— полка пользователя (средства, которые он использует):
  ${ctx.shelfBlock}

Сначала оцени качество фотографии.
Если:
— лицо плохо видно
— освещение слабое
— фото размыто
— лицо занимает слишком маленькую часть кадра
сообщи, что анализ может быть неточным.

При анализе обрати внимание на зоны лица:
— лоб
— нос
— щеки
— подбородок

Твоя задача:
Кратко описать общее состояние кожи на фото.
Отметить возможные особенности кожи (жирность, сухость, неровный тон, расширенные поры, покраснения).
Соотнести наблюдения с метриками пользователя (если они переданы).
Учитывая полку пользователя, отметить помогает ли текущий уход решать наблюдаемые особенности кожи.
Кратко объяснить возможные причины состояния кожи.
Дать мягкую рекомендацию по уходу.

При рекомендациях:
— учитывай средства, которые уже есть в полке пользователя
— не предлагай повторно те же активные ингредиенты, если они уже используются
— если уход выглядит сбалансированным, отметь это

Если кожа на фото выглядит в хорошем или стабильном состоянии (нет выраженных воспалений, сильного покраснения, сильной сухости или жирного блеска):
— не предлагай сильные изменения ухода
— рекомендация должна быть направлена только на поддержание текущего состояния кожи
— можно отметить, что текущий уход выглядит сбалансированным

Правила:
— Не ставь медицинских диагнозов.
— Не придумывай детали, которые нельзя увидеть.
— Используй осторожные формулировки: «может выглядеть», «возможно заметно», «может указывать на».
— Если признаки на фото не очевидны, скажи об этом.
— Ответ должен быть коротким и понятным.

Формат ответа:
Наблюдения:
— …
Связь с метриками:
— …
Связь с текущим уходом:
— …
Что это может означать:
— …
Рекомендация:
— …${userText.isNotEmpty ? '\n\nДополнительный комментарий пользователя: $userText' : ''}''';

    return _callMultimodal(imageUrl: imageUrl, promptText: prompt);
  }

  // ── Product photo analysis (qwen3, one-shot) ──────────────────────────────

  static Future<String> sendProductPhotoAnalysis({
    required String imageUrl,
    required String userText,
    required UserContext ctx,
  }) async {
    final prompt = '''Сначала определи тип ингредиентов:
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

  // ── Routine pick (gemma3, one-shot) ──────────────────────────────────────

  static Future<String> sendRoutinePick({
    required String userText,
    required UserContext ctx,
  }) async {
    final String prompt;

    if (userText.trim().isEmpty) {
      prompt = '''Пользователь хочет подобрать уход за кожей.

Тебе передается контекст пользователя:
— тип кожи: ${ctx.skinType}
— цель ухода: ${ctx.goal}
— текущие метрики кожи:
  ${ctx.recentMetrics}
— текущие средства пользователя (его полка):
  ${ctx.shelfBlock}

На основе этих данных составь персонализированную рутину ухода за кожей.
Предложи последовательность шагов для утреннего и вечернего ухода.
Учитывай текущие средства — не повторяй то, что уже есть в уходе без необходимости.
Если в текущем уходе чего-то не хватает для достижения цели — предложи добавить.
Объясни коротко, зачем каждый шаг или средство.
Отвечай на русском языке, кратко и понятно.
Не ставь медицинских диагнозов.''';
    } else {
      prompt = '''Пользователь задает вопрос о подборе средства или шага ухода.

Текст запроса пользователя: ${userText.trim()}

Тебе передается контекст пользователя:
— тип кожи: ${ctx.skinType}
— цель ухода: ${ctx.goal}
— последние оценки метрик кожи (если они есть):
  ${ctx.recentMetrics}
— текущие средства пользователя (его полка):
  ${ctx.shelfBlock}

Ответь на вопрос пользователя о подборе ухода, учитывая его контекст.
Отвечай на русском языке, кратко и понятно.
Не ставь медицинских диагнозов.''';
    }

    return _callApi(
      model: _kGemma3Model,
      key: _kGemma3Key,
      messages: [
        {'role': 'user', 'content': prompt},
      ],
    );
  }

  // ── Private API helpers ───────────────────────────────────────────────────

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

  static Future<String> _callApi({
    required String model,
    required String key,
    required List<Map<String, String>> messages,
  }) async {
    final body = jsonEncode({'model': model, 'messages': messages});

    final response = await http
        .post(
          Uri.parse(_kBaseUrl),
          headers: {
            'Authorization': 'Bearer $key',
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
