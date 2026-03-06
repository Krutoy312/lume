import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product_model.dart';
import '../../data/models/shelf_model.dart';

// ─── Section identifiers (match Firestore structure) ──────────────────────────

const kShelfSectionAdded = 'toTry';
const kShelfSectionMorning = 'my.morning';
const kShelfSectionEvening = 'my.evening';

// ─── State ────────────────────────────────────────────────────────────────────

class ShelfState {
  const ShelfState({this.shelf = const AsyncData(null)});

  final AsyncValue<ShelfModel?> shelf;

  bool get isLoading => shelf is AsyncLoading;
  bool get hasError => shelf is AsyncError;
  ShelfModel? get data => shelf.valueOrNull;

  ShelfState copyWith({AsyncValue<ShelfModel?>? shelf}) =>
      ShelfState(shelf: shelf ?? this.shelf);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ShelfNotifier extends StateNotifier<ShelfState> {
  ShelfNotifier() : super(const ShelfState());

  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  Timer? _debounce;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(shelf: const AsyncLoading());
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not signed in');

      final doc = await _firestore.collection('users').doc(uid).get();
      final raw = doc.data()?['shelf'];
      final shelf = raw != null
          ? ShelfModel.fromJson(raw as Map<String, dynamic>)
          : ShelfModel.empty();

      state = state.copyWith(shelf: AsyncData(shelf));
    } catch (e) {
      state = state.copyWith(shelf: AsyncError(e, StackTrace.current));
    }
  }

  // ── Move ──────────────────────────────────────────────────────────────────

  /// Moves [product] to [targetSection], removing it from all other sections.
  ///
  /// [targetSection] must be one of [kShelfSectionAdded], [kShelfSectionMorning],
  /// or [kShelfSectionEvening].
  void moveProduct(ProductModel product, String targetSection) {
    final current = state.data;
    if (current == null) return;

    var updated = _removeFromAll(current, product.id);

    updated = switch (targetSection) {
      kShelfSectionAdded => updated.copyWith(
          toTry: [...updated.toTry, product],
        ),
      kShelfSectionMorning => updated.copyWith(
          my: updated.my.copyWith(
            morning: [...updated.my.morning, product],
          ),
        ),
      kShelfSectionEvening => updated.copyWith(
          my: updated.my.copyWith(
            evening: [...updated.my.evening, product],
          ),
        ),
      _ => updated,
    };

    state = state.copyWith(shelf: AsyncData(updated));
    _scheduleSave(updated);
  }

  // ── Schedule helper ───────────────────────────────────────────────────────

  /// Returns true if [product] should be used today.
  ///
  /// A null or empty schedule means every day.
  /// Non-null schedule uses ISO weekday numbers: 1 = Monday … 7 = Sunday.
  bool isScheduledForToday(ProductModel product) {
    final schedule = product.schedule;
    if (schedule == null || schedule.isEmpty) return true;
    return schedule.contains(DateTime.now().weekday);
  }

  // ── Add to toTry ──────────────────────────────────────────────────────────

  /// Adds a new product to the [toTry] list.
  ///
  /// If [photoLocalPath] is provided, uploads the image to Firebase Storage
  /// first and stores the download URL. The product is added to the local
  /// state immediately (optimistic) and synced to Firestore via debounce.
  Future<void> addProductToTry({
    required String name,
    required String category,
    String? photoLocalPath,
    List<int>? schedule,
  }) async {
    final current = state.data;
    if (current == null) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    // Optimistic insert — no photo URL yet.
    var product = ProductModel(
      id: id,
      name: name,
      category: category,
      schedule: schedule,
    );
    var updated = current.copyWith(toTry: [...current.toTry, product]);
    state = state.copyWith(shelf: AsyncData(updated));

    // Upload photo in background; update state + Firestore when done.
    if (photoLocalPath != null) {
      try {
        final ref = FirebaseStorage.instance
            .ref('users/$uid/products/$id.jpg');
        await ref.putFile(File(photoLocalPath));
        final url = await ref.getDownloadURL();

        product = product.copyWith(photoUrl: url);
        final s = state.data;
        if (s != null) {
          final newToTry = s.toTry.map((p) => p.id == id ? product : p).toList();
          updated = s.copyWith(toTry: newToTry);
          state = state.copyWith(shelf: AsyncData(updated));
        }
      } catch (_) {
        // Ignore upload failure — product is saved without photo.
      }
    }

    _scheduleSave(updated);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  ShelfModel _removeFromAll(ShelfModel shelf, String productId) {
    return ShelfModel(
      my: ShelfRoutineModel(
        morning: shelf.my.morning.where((p) => p.id != productId).toList(),
        evening: shelf.my.evening.where((p) => p.id != productId).toList(),
      ),
      favorites: shelf.favorites.where((p) => p.id != productId).toList(),
      toTry: shelf.toTry.where((p) => p.id != productId).toList(),
    );
  }

  void _scheduleSave(ShelfModel shelf) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 800),
      () => _save(shelf),
    );
  }

  Future<void> _save(ShelfModel shelf) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'shelf': shelf.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silently ignore — local state is authoritative; next load will re-sync.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final shelfProvider =
    StateNotifierProvider.autoDispose<ShelfNotifier, ShelfState>(
  (_) => ShelfNotifier(),
);
