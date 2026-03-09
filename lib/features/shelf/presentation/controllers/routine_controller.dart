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

  /// Reads both the stored routine and the current shelf from Firestore, then
  /// syncs them:
  ///
  /// • **New day** — builds a fresh routine from the shelf and saves it.
  /// • **Same day** — merges the saved routine with the current shelf so that
  ///   newly added products are added to `planned` and removed products are
  ///   dropped, while `used`/`skipped` state is preserved.
  ///
  /// Always hits Firestore (no early return) so the routine stays accurate
  /// after shelf edits even within the same session.
  Future<void> loadAndSync() async {
    state = const AsyncLoading();
    try {
      final uid = _uid;
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};

      // Parse the stored routine (may be absent on first run).
      final rawRoutine = data['routine'];
      final savedRoutine = rawRoutine != null
          ? DailyRoutineModel.fromJson(rawRoutine as Map<String, dynamic>)
          : null;

      // Parse the shelf so we know which products exist and are scheduled.
      final rawShelf = data['shelf'];
      final shelf = rawShelf != null
          ? ShelfModel.fromJson(rawShelf as Map<String, dynamic>)
          : ShelfModel.empty();

      final today = _todayKey();
      DailyRoutineModel routine;

      if (savedRoutine == null || savedRoutine.date != today) {
        // New day or first run — start fresh.
        routine = _buildForToday(today, shelf);
      } else {
        // Same day — merge saved state with current shelf so new products
        // appear and removed products disappear.
        routine = _syncWithShelf(savedRoutine, shelf);
      }

      // Persist only if something changed (avoids needless writes).
      if (routine != savedRoutine) {
        await _save(routine);
      }

      state = AsyncData(routine);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Merges the in-memory routine with [shelf] without hitting Firestore.
  ///
  /// Called when the shelf changes in-session so newly added products appear
  /// in the home screen cards immediately without waiting for an app restart.
  Future<void> syncWithShelf(ShelfModel shelf) async {
    final current = state.valueOrNull;
    if (current == null) return; // loadAndSync hasn't run yet — nothing to merge.

    final synced = _syncWithShelf(current, shelf);
    if (synced == current) return; // nothing changed

    state = AsyncData(synced);
    await _save(synced);
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

    // Optimistic update — UI reflects change immediately.
    state = AsyncData(updated);
    await Future.wait([
      _save(updated),
      _updateDailyAssessment(updated),
    ]);
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

  /// Builds a fresh routine for [today] from [shelf], resetting all state.
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

  /// Syncs [routine] against the current [shelf]:
  ///
  /// • Products still in the shelf keep their used/skipped/planned state.
  /// • Products added to the shelf since the routine was built are added to
  ///   `planned`.
  /// • Products removed from the shelf are dropped from all lists.
  static DailyRoutineModel _syncWithShelf(
    DailyRoutineModel routine,
    ShelfModel shelf,
  ) {
    return routine.copyWith(
      morningRoutine: _syncSlot(routine.morningRoutine, shelf.my.morning),
      eveningRoutine: _syncSlot(routine.eveningRoutine, shelf.my.evening),
    );
  }

  /// Syncs a single slot against [shelfProducts].
  static RoutineSlotModel _syncSlot(
    RoutineSlotModel slot,
    List<ProductModel> shelfProducts,
  ) {
    // Products scheduled for today based on the current shelf.
    final todayIds = shelfProducts
        .where(_isScheduledToday)
        .map((p) => p.id)
        .toSet();

    // Preserve used/skipped state for products still in the shelf.
    final usedIds =
        slot.used.where((id) => todayIds.contains(id)).toList();
    final skippedIds =
        slot.skipped.where((id) => todayIds.contains(id)).toList();
    final actedOn = {...usedIds, ...skippedIds};

    // Keep planned products still in the shelf.
    final existingPlanned =
        slot.planned.where((id) => todayIds.contains(id)).toList();

    // Add any newly scheduled products (not yet in any list).
    final alreadyTracked = {...actedOn, ...existingPlanned};
    final newPlanned = todayIds
        .where((id) => !alreadyTracked.contains(id))
        .toList();

    return slot.copyWith(
      planned: [...existingPlanned, ...newPlanned],
      used: usedIds,
      skipped: skippedIds,
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

  /// Persists the full routine to the user document using merge so other
  /// fields (shelf, metrics, etc.) are never overwritten.
  Future<void> _save(DailyRoutineModel routine) async {
    try {
      await _db.collection('users').doc(_uid).set(
        {
          'routine': routine.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Silently ignore — local state remains correct; Firestore will resync
      // on the next loadAndSync() call.
    }
  }

  /// Records the product IDs used today into the daily_assessments sub-collection.
  ///
  /// Uses [mergeFields] so only `usedProductIds` and `updatedAt` are touched —
  /// the `isAssessed` flag written by the metrics assessment flow is never
  /// overwritten by routine tracking.
  Future<void> _updateDailyAssessment(DailyRoutineModel routine) async {
    try {
      final uid = _uid;
      final allUsed = [
        ...routine.morningRoutine.used,
        ...routine.eveningRoutine.used,
      ];
      await _db
          .collection('users')
          .doc(uid)
          .collection('daily_assessments')
          .doc(routine.date)
          .set(
            {
              'usedProductIds': allUsed,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(mergeFields: ['usedProductIds', 'updatedAt']),
          );
    } catch (_) {
      // Best-effort — routine state is already saved; the assessment record
      // will be backfilled on the next successful write.
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final routineProvider =
    StateNotifierProvider<RoutineNotifier, RoutineState>(
  (_) => RoutineNotifier(),
);
