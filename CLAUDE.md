# CLAUDE.md

## Проект
Мобильное приложение для ухода за кожей на Flutter/Dart. iOS + Android.

## Стек
- Flutter 3.x, Dart, Riverpod, GoRouter, Hive
- Firebase (auth, firestore, analytics, crashlytics, messaging)
- AI: OpenAI API (ассистент, анализ INCI, рекомендации)
- UI: fl_chart, lottie (маскот Бубылька), phosphor_icons
- Камера: camera + image_picker
- HTTP: dio, Модели: freezed + json_serializable

## Структура
Feature-first Clean Architecture. Подробности → docs/ARCHITECTURE.md
```
lib/
├── core/theme/              # app_colors, app_theme, app_text_styles
├── core/widgets/            # переиспользуемые виджеты
├── core/router/             # GoRouter
├── features/home/           # Главный экран (метрики)
├── features/metrics/        # Оценка метрик (слайдеры 1-10)
├── features/skin_analysis/  # AI-анализ кожи по фото
├── features/shelf/          # Полка средств + AM/PM рутина
├── features/product_analysis/  # Анализ INCI состава
├── features/progress/       # Графики + календарь
├── features/ai_assistant/   # Сквозной AI-чат
├── features/settings/       # Профиль, настройки, premium
└── data/services/           # AI, camera, notifications
```

## Дизайн


## Навигация (5 табов)
Полка | Прогресс | Home | AI-чат | Настройки

## Метрики кожи (оценка 1-10)
Основные ощущения: matte_finish, richness, elasticity, hydration, comfort
Состояние кожи: calmness, smoothness, skin_clarity, pore_cleanliness
Внешние признаки: even_skin_tone, radiance, uv_protection

## Правила кода
- UI текст: русский/английский. Код/комментарии: английский
- Каждый виджет — отдельный файл
- Все цвета → app_colors.dart, стили → app_text_styles.dart
- Без magic numbers, const конструкторы, null safety
- Адаптивный UI: макет на 645px ширины, масштабировать через MediaQuery и LayoutBuilder
- Размеры, отступы, шрифты — в относительных величинах (% от ширины экрана или коэффициент)
- Min: iOS 13, Android API 24

## Команды
```bash
flutter run
dart run build_runner build --delete-conflicting-outputs
flutter test
```
