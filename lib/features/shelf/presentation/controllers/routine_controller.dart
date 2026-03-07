import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daily_routine_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/shelf_model.dart';

// ─── State ────────────────────────────────────────────────────────────────────

/// Thin wrapper so widgets can distinguish loading / error / data.
typedef RoutineState = AsyncValue<DailyRoutineModel?>;

// ─── Notifier ─────────────────────────────────────────────────────────────────

class RoutineNotifier extends StateNotifier<RoutineState> {
  RoutineNotifier() : super(const AsyncData(null));

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Reads the user document once, syncs routine to today if stale, and
  /// updates local state. Safe to call multiple times — no-ops if today's
  /// routine is already loaded.
  Future<void> loadAndSync() async {
    // Skip if we already have today's routine in memory.
    final current = state.valueOrNull;
    if (current != null && current.date == _todayKey()) return;

    state = const AsyncLoading();
    try {
      final uid = _uid;
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};

      // Parse the stored routine (may be absent on first run).
      final rawRoutine = data['routine'];
      DailyRoutineModel? routine = rawRoutine != null
          ? DailyRoutineModel.fromJson(rawRoutine as Map<String, dynamic>)
          : null;

      // Parse the shelf to build today's planned lists.
      final rawShelf = data['shelf'];
      final shelf = rawShelf != null
          ? ShelfModel.fromJson(rawShelf as Map<String, dynamic>)
          : ShelfModel.empty();

      final today = _todayKey();
      if (routine == null || routine.date != today) {
        routine = _buildForToday(today, shelf);
        await _save(routine);
      }

      state = AsyncData(routine);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Toggles the used state for [productId] in the morning or evening slot.
  ///
  /// If the product is already in `used` it moves back to `planned`.
  /// Otherwise it is moved to `used` (removed from `planned`/`skipped`).
  Future<void> markUsed(String productId, {required bool isEvening}) async {
    final routine = state.valueOrNull;
    if (routine == null) return;

    final updated = routine.copyWith(
      morningRoutine: isEvening
          ? routine.morningRoutine
          : _toggle(routine.morningRoutine, productId, targetList: 'used'),
      eveningRoutine: isEvening
          ? _toggle(routine.eveningRoutine, productId, targetList: 'used')
          : routine.eveningRoutine,
    );

    state = AsyncData(updated);
    await _save(updated);
  }

  /// Toggles the skipped state for [productId] in the morning or evening slot.
  ///
  /// If the product is already in `skipped` it moves back to `planned`.
  /// Otherwise it is moved to `skipped` (removed from `planned`/`used`).
  Future<void> markSkipped(String productId, {required bool isEvening}) async {
    final routine = state.valueOrNull;
    if (routine == null) return;

    final updated = routine.copyWith(
      morningRoutine: isEvening
          ? routine.morningRoutine
          : _toggle(routine.morningRoutine, productId, targetList: 'skipped'),
      eveningRoutine: isEvening
          ? _toggle(routine.eveningRoutine, productId, targetList: 'skipped')
          : routine.eveningRoutine,
    );

    state = AsyncData(updated);
    await _save(updated);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');
    return uid;
  }

  /// Returns today's date as "yyyy-MM-dd" in local timezone.
  static String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// Builds a fresh routine for [today] from [shelf], resetting skipped/used.
  static DailyRoutineModel _buildForToday(String today, ShelfModel shelf) {
    return DailyRoutineModel(
      date: today,
      morningRoutine: RoutineSlotModel(
        planned: shelf.my.morning
            .where(_isScheduledToday)
            .map((p) => p.id)
            .toList(),
      ),
      eveningRoutine: RoutineSlotModel(
        planned: shelf.my.evening
            .where(_isScheduledToday)
            .map((p) => p.id)
            .toList(),
      ),
    );
  }

  /// True if [product] is scheduled for today (null/empty schedule = every day).
  static bool _isScheduledToday(ProductModel product) {
    final schedule = product.schedule;
    if (schedule == null || schedule.isEmpty) return true;
    return schedule.contains(DateTime.now().weekday);
  }

  /// Moves [productId] to [targetList] within [slot], or back to `planned`
  /// if it is already there (toggle).
  RoutineSlotModel _toggle(
    RoutineSlotModel slot,
    String productId, {
    required String targetList,
  }) {
    final alreadyInTarget = targetList == 'used'
        ? slot.used.contains(productId)
        : slot.skipped.contains(productId);

    if (alreadyInTarget) {
      // Un-mark: move back to planned.
      return slot.copyWith(
        planned: [...slot.planned, productId],
        used: slot.used.where((id) => id != productId).toList(),
        skipped: slot.skipped.where((id) => id != productId).toList(),
      );
    }

    // Mark: remove from all three lists, then add to target.
    final newPlanned = slot.planned.where((id) => id != productId).toList();
    final newUsed = slot.used.where((id) => id != productId).toList();
    final newSkipped = slot.skipped.where((id) => id != productId).toList();

    return targetList == 'used'
        ? slot.copyWith(
            planned: newPlanned,
            used: [...newUsed, productId],
            skipped: newSkipped,
          )
        : slot.copyWith(
            planned: newPlanned,
            used: newUsed,
            skipped: [...newSkipped, productId],
          );
  }

  Future<void> _save(DailyRoutineModel routine) async {
    try {
      await _db.collection('users').doc(_uid).update({
        'routine': routine.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silently ignore — local state remains correct; Firestore will resync
      // on the next loadAndSync() call.
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final routineProvider =
    StateNotifierProvider<RoutineNotifier, RoutineState>(
  (_) => RoutineNotifier(),
);
