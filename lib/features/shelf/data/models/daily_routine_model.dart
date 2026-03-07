import 'package:flutter/foundation.dart';

/// One AM or PM slot: three disjoint lists of product IDs.
///
/// A product starts in [planned] when the routine is built for the day.
/// User actions move it to [used] or [skipped] (toggling moves it back).
@immutable
class RoutineSlotModel {
  final List<String> planned;
  final List<String> skipped;
  final List<String> used;

  const RoutineSlotModel({
    this.planned = const [],
    this.skipped = const [],
    this.used = const [],
  });

  factory RoutineSlotModel.fromJson(Map<String, dynamic> json) =>
      RoutineSlotModel(
        planned: _strings(json['planned']),
        skipped: _strings(json['skipped']),
        used: _strings(json['used']),
      );

  Map<String, dynamic> toJson() => {
        'planned': planned,
        'skipped': skipped,
        'used': used,
      };

  RoutineSlotModel copyWith({
    List<String>? planned,
    List<String>? skipped,
    List<String>? used,
  }) =>
      RoutineSlotModel(
        planned: planned ?? this.planned,
        skipped: skipped ?? this.skipped,
        used: used ?? this.used,
      );

  /// Total products in this slot.
  int get totalCount => planned.length + skipped.length + used.length;

  /// Products marked as done (used or skipped).
  int get doneCount => used.length + skipped.length;

  /// True when every planned product has been acted on.
  bool get isComplete => totalCount > 0 && doneCount == totalCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineSlotModel &&
          listEquals(planned, other.planned) &&
          listEquals(skipped, other.skipped) &&
          listEquals(used, other.used);

  @override
  int get hashCode => Object.hash(planned, skipped, used);
}

/// The full daily routine stored under `users/{uid}.routine`.
@immutable
class DailyRoutineModel {
  /// Local date string "yyyy-MM-dd" — used to detect a new day.
  final String date;
  final RoutineSlotModel morningRoutine;
  final RoutineSlotModel eveningRoutine;

  const DailyRoutineModel({
    required this.date,
    this.morningRoutine = const RoutineSlotModel(),
    this.eveningRoutine = const RoutineSlotModel(),
  });

  factory DailyRoutineModel.fromJson(Map<String, dynamic> json) =>
      DailyRoutineModel(
        date: json['date'] as String? ?? '',
        morningRoutine: RoutineSlotModel.fromJson(
          (json['morningRoutine'] as Map<String, dynamic>?) ?? {},
        ),
        eveningRoutine: RoutineSlotModel.fromJson(
          (json['eveningRoutine'] as Map<String, dynamic>?) ?? {},
        ),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'morningRoutine': morningRoutine.toJson(),
        'eveningRoutine': eveningRoutine.toJson(),
      };

  DailyRoutineModel copyWith({
    String? date,
    RoutineSlotModel? morningRoutine,
    RoutineSlotModel? eveningRoutine,
  }) =>
      DailyRoutineModel(
        date: date ?? this.date,
        morningRoutine: morningRoutine ?? this.morningRoutine,
        eveningRoutine: eveningRoutine ?? this.eveningRoutine,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRoutineModel &&
          date == other.date &&
          morningRoutine == other.morningRoutine &&
          eveningRoutine == other.eveningRoutine;

  @override
  int get hashCode => Object.hash(date, morningRoutine, eveningRoutine);
}

List<String> _strings(dynamic raw) {
  if (raw is List) return raw.whereType<String>().toList();
  return const [];
}
