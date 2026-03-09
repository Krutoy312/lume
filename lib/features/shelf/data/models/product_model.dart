import 'package:flutter/foundation.dart';

/// A single skincare product stored on the user's shelf.
@immutable
class ProductModel {
  /// Unique identifier (Firestore doc ID or client-generated UUID).
  final String id;

  /// Display name of the product.
  final String name;

  /// Product category, e.g. "Cleanser", "Moisturizer", "Serum".
  final String category;

  /// Optional URL to a product photo in Firebase Storage.
  final String? photoUrl;

  /// Optional weekly schedule — ISO weekday numbers (1 = Monday … 7 = Sunday).
  /// Null means the product has no specific schedule (apply every applicable day).
  final List<int>? schedule;

  const ProductModel({
    required this.id,
    required this.name,
    required this.category,
    this.photoUrl,
    this.schedule,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<int>? schedule;
    final rawSchedule = json['schedule'];
    if (rawSchedule is List) {
      schedule = rawSchedule.map((e) => (e as num).toInt()).toList();
    }

    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      photoUrl: json['photoUrl'] as String?,
      schedule: schedule,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'photoUrl': photoUrl,
        'schedule': schedule,
      };

  ProductModel copyWith({
    String? id,
    String? name,
    String? category,
    Object? photoUrl = _sentinel,
    Object? schedule = _sentinel,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      photoUrl: photoUrl == _sentinel ? this.photoUrl : photoUrl as String?,
      schedule: schedule == _sentinel ? this.schedule : schedule as List<int>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          category == other.category &&
          photoUrl == other.photoUrl &&
          listEquals(schedule, other.schedule);

  @override
  int get hashCode => Object.hash(id, name, category, photoUrl, schedule);

  @override
  String toString() =>
      'ProductModel(id: $id, name: $name, category: $category, '
      'photoUrl: $photoUrl, schedule: $schedule)';
}

// Sentinel for copyWith nullable fields.
const Object _sentinel = Object();
