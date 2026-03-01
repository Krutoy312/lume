/**
 * Skin Care App — Cloud Functions
 *
 * Functions:
 *   initUserDocument    — Auth onCreate: creates default Firestore user doc.
 *   onAssessmentWritten — Firestore trigger: updates streak atomically.
 *
 * Deployment notes
 * ────────────────
 * Both functions are pinned to europe-west1 for consistency with the
 * Firestore database location and to avoid cross-region latency.
 *
 * v2 Firestore trigger (onAssessmentWritten) requires Eventarc.
 * Run once after first deploy if the trigger does not fire:
 *
 *   PROJECT_NUMBER=$(gcloud projects describe skin-care-60bdc \
 *     --format="value(projectNumber)")
 *
 *   # Allow Firestore to publish Eventarc events
 *   gcloud projects add-iam-policy-binding skin-care-60bdc \
 *     --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-firestore.iam.gserviceaccount.com" \
 *     --role="roles/eventarc.eventReceiver"
 *
 *   # Allow Pub/Sub to create auth tokens for the Cloud Run service
 *   gcloud projects add-iam-policy-binding skin-care-60bdc \
 *     --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
 *     --role="roles/iam.serviceAccountTokenCreator"
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import * as v1 from "firebase-functions/v1";
import { setGlobalOptions } from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

admin.initializeApp();

const db = admin.firestore();

// Applies to all v2 functions declared below.
setGlobalOptions({ maxInstances: 10, region: "europe-west1" });

// ─── Types ────────────────────────────────────────────────────────────────────

interface ShelfData {
  my: { morning: string[]; evening: string[] };
  favorites: string[];
  toTry: string[];
}

interface UserData {
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

// ─── Default document templates ───────────────────────────────────────────────

/** All 12 skin metrics supported by the app. */
const ALL_METRIC_KEYS = [
  "matte_finish", "richness", "elasticity", "hydration", "comfort",
  "calmness", "smoothness", "skin_clarity", "pore_cleanliness",
  "even_skin_tone", "radiance", "uv_protection",
] as const;

/** Default user document written on signup. */
const DEFAULT_USER: Omit<UserData, "name"> = {
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
  timezone: "UTC",
  trackedMetrics: [...ALL_METRIC_KEYS],
  hasSubscription: false,
  notificationsEnabled: false,
  morningMinutes: 480,
  eveningMinutes: 1320,
};

/** Build an empty assessment document for a given dateKey. */
function defaultAssessment(dateKey: string): object {
  const metrics: Record<string, null> = {};
  for (const key of ALL_METRIC_KEYS) {
    metrics[key] = null;
  }
  const now = admin.firestore.FieldValue.serverTimestamp();
  return { dateKey, metrics, photoUrl: null, note: "", createdAt: now, updatedAt: now };
}

// ─── Date helpers ─────────────────────────────────────────────────────────────

/** Returns YYYY-MM-DD for the given timezone at the current moment. */
function todayKey(timezone: string): string {
  return new Date().toLocaleDateString("en-CA", { timeZone: timezone });
}

/** Shifts a YYYY-MM-DD string by `days` calendar days (UTC arithmetic). */
function shiftDateKey(dateKey: string, days: number): string {
  const d = new Date(dateKey + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

// ─── Streak logic ─────────────────────────────────────────────────────────────

interface StreakUpdate {
  streakCurrent: number;
  streakLongest: number;
  lastActiveDateKey: string;
  daysCounter: number;
}

/**
 * Pure function: computes new streak state when an assessment is written.
 * Returns null when no update is needed.
 */
function computeStreak(
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

// ─── Cloud Functions ──────────────────────────────────────────────────────────

/**
 * AUTH TRIGGER (Gen 1 — no Gen 2 non-blocking auth trigger exists yet).
 *
 * BUG FIXES applied vs original:
 *   1. Added `failurePolicy: { retry: {} }` — without this, any transient error
 *      (cold-start timeout, Firestore unavailability) silently drops the event
 *      and the user document is NEVER created.  The idempotency check below
 *      makes retries safe.
 *   2. Pinned region to "europe-west1" — matches the v2 functions and the
 *      Firestore database location, avoiding cross-region round-trips.
 *
 * Note: setGlobalOptions() above does NOT affect Gen 1 functions.
 * Region and runtime options must be set explicitly via region() / runWith().
 */
export const initUserDocument = v1
  .region("europe-west1")
  .runWith({ failurePolicy: { retry: {} } })
  .auth.user()
  .onCreate(async (user) => {
    const userRef = db.collection("users").doc(user.uid);

    // Idempotency guard — safe to retry because we check existence first.
    // If a previous attempt created the doc, we skip silently.
    const snap = await userRef.get();
    if (snap.exists) {
      logger.info(`User doc already exists, skipping. uid=${user.uid}`);
      return;
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    await userRef.set({
      ...DEFAULT_USER,
      name: user.displayName ?? "",
      createdAt: now,
      updatedAt: now,
    });

    logger.info(`Created user document. uid=${user.uid}`);
  });

/**
 * FIRESTORE TRIGGER: users/{uid}/assessments/{dateKey}
 *
 * Fires on create/update of an assessment document.
 * Updates the user's streak atomically via a Firestore transaction.
 * Skips delete events (streak is historical, not tied to current data).
 *
 * Requires Eventarc IAM setup — see deployment notes at the top of this file.
 */
export const onAssessmentWritten = onDocumentWritten(
  { document: "users/{uid}/assessments/{dateKey}", region: "europe-west1" },
  async (event) => {
    if (!event.data?.after.exists) return;

    const { uid, dateKey } = event.params;

    try {
      await db.runTransaction(async (tx) => {
        const userRef = db.collection("users").doc(uid);
        const userSnap = await tx.get(userRef);

        if (!userSnap.exists) {
          logger.warn(`User doc missing, cannot update streak. uid=${uid}`);
          return;
        }

        const userData = userSnap.data() as UserData;
        const update = computeStreak(dateKey, userData);

        if (!update) {
          logger.debug(`No streak update needed. uid=${uid} dateKey=${dateKey}`);
          return;
        }

        tx.update(userRef, {
          ...update,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info(
          `Streak updated. uid=${uid} dateKey=${dateKey} ` +
          `streak=${update.streakCurrent} longest=${update.streakLongest} ` +
          `days=${update.daysCounter}`
        );
      });
    } catch (err) {
      logger.error(`Streak transaction failed. uid=${uid} dateKey=${dateKey}`, err);
      throw err;
    }
  }
);

// ─── Exports ──────────────────────────────────────────────────────────────────

export { computeStreak, defaultAssessment, ALL_METRIC_KEYS, DEFAULT_USER };
