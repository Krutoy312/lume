import 'package:flutter/foundation.dart';

import 'product_model.dart';

/// The AM/PM routine sub-object inside [ShelfModel].
@immutable
class ShelfRoutineModel {
  final List<ProductModel> morning;
  final List<ProductModel> evening;

  const ShelfRoutineModel({
    this.morning = const [],
    this.evening = const [],
  });

  factory ShelfRoutineModel.fromJson(Map<String, dynamic> json) {
    return ShelfRoutineModel(
      morning: _parseList(json['morning']),
      evening: _parseList(json['evening']),
    );
  }

  Map<String, dynamic> toJson() => {
        'morning': morning.map((p) => p.toJson()).toList(),
        'evening': evening.map((p) => p.toJson()).toList(),
      };

  ShelfRoutineModel copyWith({
    List<ProductModel>? morning,
    List<ProductModel>? evening,
  }) {
    return ShelfRoutineModel(
      morning: morning ?? this.morning,
      evening: evening ?? this.evening,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShelfRoutineModel &&
          runtimeType == other.runtimeType &&
          listEquals(morning, other.morning) &&
          listEquals(evening, other.evening);

  @override
  int get hashCode => Object.hash(morning, evening);
}

/// The full shelf for a user, mirroring the Firestore `shelf` field.
@immutable
class ShelfModel {
  /// Products in the user's personal AM/PM routines.
  final ShelfRoutineModel my;

  /// Products the user has marked as favourites.
  final List<ProductModel> favorites;

  /// Products the user wants to try.
  final List<ProductModel> toTry;

  const ShelfModel({
    required this.my,
    this.favorites = const [],
    this.toTry = const [],
  });

  /// Empty shelf — matches the DEFAULT_USER initialised by the Cloud Function.
  factory ShelfModel.empty() => ShelfModel(
        my: const ShelfRoutineModel(),
      );

  factory ShelfModel.fromJson(Map<String, dynamic> json) {
    return ShelfModel(
      my: ShelfRoutineModel.fromJson(
        (json['my'] as Map<String, dynamic>?) ?? {},
      ),
      favorites: _parseList(json['favorites']),
      toTry: _parseList(json['toTry']),
    );
  }

  Map<String, dynamic> toJson() => {
        'my': my.toJson(),
        'favorites': favorites.map((p) => p.toJson()).toList(),
        'toTry': toTry.map((p) => p.toJson()).toList(),
      };

  ShelfModel copyWith({
    ShelfRoutineModel? my,
    List<ProductModel>? favorites,
    List<ProductModel>? toTry,
  }) {
    return ShelfModel(
      my: my ?? this.my,
      favorites: favorites ?? this.favorites,
      toTry: toTry ?? this.toTry,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShelfModel &&
          runtimeType == other.runtimeType &&
          my == other.my &&
          listEquals(favorites, other.favorites) &&
          listEquals(toTry, other.toTry);

  @override
  int get hashCode => Object.hash(my, favorites, toTry);
}

List<ProductModel> _parseList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList();
  }
  return const [];
}
