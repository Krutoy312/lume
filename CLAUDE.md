# CLAUDE.md

## Project
Mobile skincare app built with Flutter/Dart. iOS + Android.

## Stack
- Flutter 3.x, Dart, Riverpod, GoRouter, Hive
- Firebase (auth, firestore, analytics, crashlytics, messaging)
- AI: OpenAI API (assistant, INCI analysis, recommendations)
- UI: fl_chart, lottie (mascot Bubylka), phosphor_icons
- Camera: camera + image_picker
- HTTP: dio, Models: freezed + json_serializable

## Structure
Feature-first Clean Architecture. Details → docs/ARCHITECTURE.md
```
lib/
├── core/theme/              # app_colors, app_theme, app_text_styles
├── core/widgets/            # reusable widgets
├── core/router/             # GoRouter
├── features/home/           # Home screen (metrics)
├── features/metrics/        # Metrics rating (sliders 1-10)
├── features/skin_analysis/  # AI skin analysis by photo
├── features/shelf/          # Product shelf + AM/PM routine
├── features/product_analysis/  # INCI composition analysis
├── features/progress/       # Charts + calendar
├── features/ai_assistant/   # Cross-feature AI chat
├── features/settings/       # Profile, settings, premium
└── data/services/           # AI, camera, notifications
```

## Design
All colors, text styles, and theme are described in:
- core/theme/app_colors.dart
- core/theme/app_text_style.dart
- core/theme/app_theme.dart

## Assets
```
assets/
├── icons/          # ic_name.svg — UI icons
├── images/         # img_name.svg — illustrations, mascot
```
Icon prefix: ic_, Image prefix: img_, Animation prefix: anim_

## Navigation (5 tabs)
Shelf | Progress | Home | AI Chat | Settings

## Skin metrics (rated 1-10)
Core sensations: matte_finish, richness, elasticity, hydration, comfort
Skin condition: calmness, smoothness, skin_clarity, pore_cleanliness
Visible signs: even_skin_tone, radiance, uv_protection

## Code rules
- UI text: Russian/English. Code/comments: English
- Each widget — separate file
- All colors → app_colors.dart, styles → app_text_styles.dart
- No magic numbers, const constructors, null safety
- Adaptive UI: base layout 645px width, scale via MediaQuery and LayoutBuilder
- Sizes, paddings, fonts — relative values (% of screen width or scale factor)
- Min: iOS 13, Android API 24

## Commands
```bash
flutter run
dart run build_runner build --delete-conflicting-outputs
flutter test
```