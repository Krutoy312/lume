// Shared domain interfaces used across Cloud Functions and exported for tests.

export interface ShelfData {
  my: { morning: string[]; evening: string[] };
  favorites: string[];
  toTry: string[];
}

export interface UserData {
  name: string;
  birthDate: string | null;
  gender: "male" | "female" | "other" | null;
  skinType: "normal" | "dry" | "oily" | "combo" | null;
  skinFeatures: string[];
  goal: string;
  shelf: ShelfData;
  // Streak — managed exclusively server-side
  daysCounter: number;
  streakCurrent: number;
  streakLongest: number;
  lastActiveDateKey: string | null;
  // Settings
  timezone: string;
  trackedMetrics: string[];
  hasSubscription: boolean;
  notificationsEnabled: boolean;
  morningMinutes: number;
  eveningMinutes: number;
}

export interface StreakUpdate {
  streakCurrent: number;
  streakLongest: number;
  lastActiveDateKey: string;
  daysCounter: number;
}
