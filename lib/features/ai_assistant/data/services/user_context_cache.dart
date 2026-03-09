import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_chat_service.dart';

// ─── Cached entry ─────────────────────────────────────────────────────────────

/// Wraps a [UserContext] together with the moment it was fetched so the cache
/// can decide whether the entry is still fresh.
class _CachedEntry {
  const _CachedEntry({required this.context, required this.fetchedAt});

  final UserContext context;
  final DateTime fetchedAt;

  /// How long a cached entry is considered valid before a re-fetch is needed.
  static const _ttl = Duration(minutes: 5);

  bool get isValid => DateTime.now().difference(fetchedAt) < _ttl;
}

// ─── Cache notifier ───────────────────────────────────────────────────────────

/// In-memory, session-scoped cache for [UserContext].
///
/// Logic flow on every [getContext] call:
///   Step 1 — Check notes: is there a valid (non-expired) entry?
///   Step 2 — Cache hit  : return it immediately, no Firestore call.
///   Step 3 — Cache miss : fetch from Firestore via [AiChatService].
///   Step 4 — Save       : store the fresh entry so the next call hits the cache.
class UserContextCacheNotifier extends StateNotifier<_CachedEntry?> {
  UserContextCacheNotifier() : super(null);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns a [UserContext], reading from the in-memory cache when possible
  /// and falling back to Firestore only when the cache is empty or stale.
  Future<UserContext> getContext() async {
    // ── Step 1: check notes ──────────────────────────────────────────────────
    final cached = state;

    // ── Step 2: cache hit — return immediately, no database call ────────────
    if (cached != null && cached.isValid) {
      return cached.context;
    }

    // ── Step 3: cache miss — fetch from database ─────────────────────────────
    final freshContext = await AiChatService.buildUserContext();

    // ── Step 4: save to notes for future calls ────────────────────────────────
    state = _CachedEntry(context: freshContext, fetchedAt: DateTime.now());

    return freshContext;
  }

  /// Forces the next [getContext] call to re-fetch from Firestore.
  /// Call this after the user updates their profile, shelf, or skin metrics.
  void invalidate() => state = null;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Single instance for the whole app session.
/// Not auto-disposed so the cached data persists across screen navigations.
final userContextCacheProvider =
    StateNotifierProvider<UserContextCacheNotifier, _CachedEntry?>(
  (_) => UserContextCacheNotifier(),
);
