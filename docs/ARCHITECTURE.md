# ARCHITECTURE.md — Detailed Architecture

## Modules and Relations

### Home (Main Screen)
- Goal block with progress bar
- "Skin analysis by photo" button
- "Rate your skin today" button → opens metrics/
- Skin metrics grid with /10 ratings
- Morning/evening care routine
- Tip from Bubylka mascot

### Metrics (Skin Rating)
- Sliders 1-10 for each metric
- Saved with date and optional photo attachment
- Data source for progress/

### Skin Analysis (AI Photo Analysis)
- Take/upload face photo
- CV analysis → skin type, issues, texture, pores, sebum
- AI report with recommendations
- Updates metrics and profile

### Shelf (Product Shelf)
- User's product list
- Add: manual input / photo
- After adding: INCI parsing, active detection, conflict check
- Auto-build AM/PM routine via AI
- Drag & drop routine editing

### Progress
- Line chart of metrics (fl_chart)
- Calendar below the chart
- Tap on date → show daily ratings
- Compare two dates

### AI Assistant (cross-feature)
- Composition explanation
- Q&A
- Recommendations
- Conflict interpretation
- Routine building assistance

### Settings
- Profile: name, skin type, goal, specifics
- Metrics settings: select/hide
- App: reminders, push, animations, dark theme
- Premium: extended progress, deep analytics, unlimited AI
- Feedback

## Module Relations
- Metrics → Progress (charts)
- Shelf → Recommendations (current care)
- INCI database → Composition analysis
- Composition analysis → Recommendations
- AI skin analysis → Metrics + Recommendations
- Profile → System-wide personalization

## Each feature contains
```
feature_name/
├── data/
│   ├── models/          # freezed models
│   ├── repositories/    # implementation
│   └── datasources/     # API, DB
├── domain/
│   ├── entities/
│   ├── repositories/    # abstractions
│   └── usecases/
└── presentation/
    ├── screens/
    ├── widgets/
    └── providers/       # Riverpod
```