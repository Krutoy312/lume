import * as admin from "firebase-admin";

import type { UserData, StreakUpdate } from "../models/user.js";

// ─── Metric registry ──────────────────────────────────────────────────────────

/** All 12 skin metrics supported by the app. */
export const ALL_METRIC_KEYS = [
  "matte", "richness", "elasticity", "hydration", "comfort",
  "calmness", "smoothness", "skin_clarity", "pore_cleanliness",
  "even_skin_tone", "radiance", "uv_protection",
] as const;

// ─── Default document templates ───────────────────────────────────────────────

/** Default user document written on signup. */
export const DEFAULT_USER: Omit<UserData, "name"> & { lastNameChangeDate: null } = {
  birthDate: null,
  gender: null,
  skinType: null,
  skinFeatures: [],
  goal: "",
  shelf: { my: { morning: [], evening: [] }, favorites: [], toTry: [] },
  daysCounter: 0,
  streakCurrent: 0,
  streakLongest: 0,
  lastActiveDateKey: null,
  // null means the user has never changed their name → first change is always
  // allowed immediately (no 14-day cooldown on brand-new accounts).
  lastNameChangeDate: null,
  timezone: "UTC",
  trackedMetrics: ["matte", "richness", "hydration", "comfort"],
  hasSubscription: false,
  notificationsEnabled: false,
  morningMinutes: 480,
  eveningMinutes: 1320,
};

/** Build an empty assessment document for a given dateKey. */
export function defaultAssessment(dateKey: string): object {
  const metrics: Record<string, null> = {};
  for (const key of ALL_METRIC_KEYS) {
    metrics[key] = null;
  }
  const now = admin.firestore.FieldValue.serverTimestamp();
  return { dateKey, metrics, photoUrl: null, note: "", createdAt: now, updatedAt: now };
}

// ─── Date helpers ─────────────────────────────────────────────────────────────

/** Returns YYYY-MM-DD for the given timezone at the current moment. */
export function todayKey(timezone: string): string {
  return new Date().toLocaleDateString("en-CA", { timeZone: timezone });
}

/** Shifts a YYYY-MM-DD string by `days` calendar days (UTC arithmetic). */
export function shiftDateKey(dateKey: string, days: number): string {
  const d = new Date(dateKey + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

// ─── Streak logic ─────────────────────────────────────────────────────────────

/**
 * Pure function: computes new streak state when an assessment is written.
 * Returns null when no update is needed.
 */
export function computeStreak(
  dateKey: string,
  user: Pick<UserData,
    | "lastActiveDateKey" | "streakCurrent"
    | "streakLongest" | "daysCounter" | "timezone">
): StreakUpdate | null {
  const tz = user.timezone || "UTC";
  const today = todayKey(tz);

  if (dateKey > today) return null;
  if (user.lastActiveDateKey !== null && dateKey <= user.lastActiveDateKey) {
    return null;
  }

  let newStreak: number;
  if (user.lastActiveDateKey === null) {
    newStreak = 1;
  } else {
    const expectedNext = shiftDateKey(user.lastActiveDateKey, 1);
    newStreak = dateKey === expectedNext ? user.streakCurrent + 1 : 1;
  }

  return {
    streakCurrent: newStreak,
    streakLongest: Math.max(user.streakLongest, newStreak),
    lastActiveDateKey: dateKey,
    daysCounter: user.daysCounter + 1,
  };
}
