import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String calendarFmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const kCalendarMonthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

// ─── State ────────────────────────────────────────────────────────────────────

class CalendarState {
  const CalendarState({
    required this.displayMonth,
    this.comparisonMode = false,
    this.startDate,
    this.endDate,
    this.allDateKeys = const {},
    this.cachedData = const {},
    this.indexLoadState = const AsyncData(null),
    this.detailLoadState = const AsyncData(null),
  });

  factory CalendarState.initial() => CalendarState(
        displayMonth: DateTime(DateTime.now().year, DateTime.now().month),
      );

  final DateTime displayMonth;
  final bool comparisonMode;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String> allDateKeys;
  final Map<String, Map<String, dynamic>> cachedData;
  final AsyncValue<void> indexLoadState;
  final AsyncValue<void> detailLoadState;

  bool hasData(DateTime day) => allDateKeys.contains(calendarFmtDate(day));
  bool isStart(DateTime day) => startDate != null && _sameDay(day, startDate!);
  bool isEnd(DateTime day) => endDate != null && _sameDay(day, endDate!);
  bool isSelected(DateTime day) => isStart(day) || isEnd(day);

  bool isInRange(DateTime day) {
    if (startDate == null || endDate == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final e = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return d.isAfter(s) && d.isBefore(e);
  }

  Set<String> get availableMonths =>
      allDateKeys.map((k) => k.substring(0, 7)).toSet();

  Map<String, dynamic>? dataFor(DateTime? day) {
    if (day == null) return null;
    return cachedData[calendarFmtDate(day)];
  }

  CalendarState copyWith({
    DateTime? displayMonth,
    bool? comparisonMode,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    Set<String>? allDateKeys,
    Map<String, Map<String, dynamic>>? cachedData,
    AsyncValue<void>? indexLoadState,
    AsyncValue<void>? detailLoadState,
  }) =>
      CalendarState(
        displayMonth: displayMonth ?? this.displayMonth,
        comparisonMode: comparisonMode ?? this.comparisonMode,
        startDate: clearStartDate ? null : (startDate ?? this.startDate),
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        allDateKeys: allDateKeys ?? this.allDateKeys,
        cachedData: cachedData ?? this.cachedData,
        indexLoadState: indexLoadState ?? this.indexLoadState,
        detailLoadState: detailLoadState ?? this.detailLoadState,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier() : super(CalendarState.initial()) {
    _loadIndex();
  }

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Load all date keys ────────────────────────────────────────────────────

  Future<void> _loadIndex() async {
    final uid = _uid;
    if (uid == null) return;
    state = state.copyWith(indexLoadState: const AsyncLoading());
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('daily_assessments')
          .get();
      final keys = snap.docs.map((d) => d.id).toSet();
      state = state.copyWith(
        allDateKeys: keys,
        indexLoadState: const AsyncData(null),
      );
    } catch (e) {
      state = state.copyWith(
        indexLoadState: AsyncError(e, StackTrace.current),
      );
    }
  }

  Future<void> refresh() => _loadIndex();

  // ── Load a specific day's data ────────────────────────────────────────────

  Future<Map<String, dynamic>?> _loadDetail(String dateKey) async {
    if (state.cachedData.containsKey(dateKey)) {
      return state.cachedData[dateKey];
    }
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('daily_assessments')
        .doc(dateKey)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    state = state.copyWith(
      cachedData: {...state.cachedData, dateKey: data},
    );
    return data;
  }

  // ── Toggle comparison mode ────────────────────────────────────────────────

  void toggleComparison() {
    state = state.copyWith(
      comparisonMode: !state.comparisonMode,
      clearStartDate: true,
      clearEndDate: true,
    );
  }

  // ── Select a calendar day ─────────────────────────────────────────────────

  Future<void> selectDay(DateTime day) async {
    if (!state.hasData(day)) return;
    final dateKey = calendarFmtDate(day);

    if (!state.comparisonMode) {
      state = state.copyWith(
        startDate: day,
        clearEndDate: true,
        detailLoadState: const AsyncLoading(),
      );
      await _loadDetail(dateKey);
      state = state.copyWith(detailLoadState: const AsyncData(null));
    } else {
      // First pick or reset after both already selected
      if (state.startDate == null || state.endDate != null) {
        state = state.copyWith(
          startDate: day,
          clearEndDate: true,
        );
        await _loadDetail(dateKey);
      } else {
        // Second pick — sort chronologically
        final s = state.startDate!;
        final DateTime finalStart, finalEnd;
        if (day.isBefore(s)) {
          finalStart = day;
          finalEnd = s;
        } else {
          finalStart = s;
          finalEnd = day;
        }
        state = state.copyWith(
          startDate: finalStart,
          endDate: finalEnd,
          detailLoadState: const AsyncLoading(),
        );
        await Future.wait([
          _loadDetail(calendarFmtDate(finalStart)),
          _loadDetail(calendarFmtDate(finalEnd)),
        ]);
        state = state.copyWith(detailLoadState: const AsyncData(null));
      }
    }
  }

  // ── Change displayed month ────────────────────────────────────────────────

  void changeMonth(DateTime month) {
    state = state.copyWith(displayMonth: month);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final calendarProvider =
    StateNotifierProvider.autoDispose<CalendarNotifier, CalendarState>(
  (_) => CalendarNotifier(),
);
