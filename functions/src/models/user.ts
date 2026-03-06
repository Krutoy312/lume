// Shared domain interfaces used across Cloud Functions and exported for tests.

/** A single skincare product stored on the user's shelf. */
export interface Product {
  /** Unique identifier (UUID or Firestore doc ID). */
  id: string;
  /** Display name of the product. */
  name: string;
  /** Category, e.g. "Cleanser", "Moisturizer", "Serum". */
  category: string;
  /** Optional URL to a product photo. */
  photoUrl?: string | null;
  /**
   * Optional weekly schedule — ISO weekday numbers (1 = Monday … 7 = Sunday).
   * Null/absent means the product has no specific schedule (apply every day).
   */
  schedule?: number[] | null;
}

export interface ShelfData {
  my: { morning: Product[]; evening: Product[] };
  favorites: Product[];
  toTry: Product[];
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
