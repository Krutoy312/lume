/**
 * Skin Care App — Cloud Functions entry point.
 *
 * This file is intentionally thin: it only re-exports the named functions and
 * the public utility symbols that were exported from the original monolith.
 * All initialisation (admin.initializeApp, setGlobalOptions) happens in
 * src/config/firebase.ts, which is transitively imported by both handler
 * modules before any function registration code runs.
 *
 * Module layout
 * ─────────────
 * src/
 * ├── config/firebase.ts       admin init · setGlobalOptions · db
 * ├── models/user.ts           ShelfData · UserData · StreakUpdate
 * ├── utils/date_utils.ts      ALL_METRIC_KEYS · DEFAULT_USER · helpers
 * ├── handlers/auth.ts         initUserDocument  (Gen 1 Auth trigger)
 * └── handlers/assessments.ts  onAssessmentWritten · saveDailyAssessment
 *
 * Deployment notes
 * ────────────────
 * Both v2 functions are pinned to europe-west1.  The onAssessmentWritten
 * trigger requires Eventarc IAM setup — run the gcloud commands documented
 * in handlers/assessments.ts after the first deploy if the trigger does not fire.
 */

// ── Cloud Functions ───────────────────────────────────────────────────────────

export { initUserDocument } from "./handlers/auth.js";
export { onAssessmentWritten, saveDailyAssessment } from "./handlers/assessments.js";

// ── Public utilities (preserved from original exports) ────────────────────────

export { computeStreak, defaultAssessment, ALL_METRIC_KEYS, DEFAULT_USER } from "./utils/date_utils.js";
