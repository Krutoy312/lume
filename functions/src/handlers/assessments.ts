/**
 * FIRESTORE TRIGGER: users/{uid}/assessments/{dateKey}
 * HTTPS CALLABLE:    saveDailyAssessment
 *
 * Both functions are pinned to europe-west1 (inherited from setGlobalOptions
 * in config/firebase.ts, and also set explicitly per-function for clarity).
 *
 * onAssessmentWritten requires Eventarc IAM setup — see deployment notes in
 * the original index.ts header or the project README.
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { DateTime, IANAZone } from "luxon";

import { db } from "../config/firebase.js";
import type { UserData } from "../models/user.js";
import { ALL_METRIC_KEYS, computeStreak } from "../utils/date_utils.js";

// ─── Firestore trigger ────────────────────────────────────────────────────────

/**
 * Fires on create/update of an assessment document.
 * Updates the user's streak atomically via a Firestore transaction.
 * Skips delete events (streak is historical, not tied to current data).
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

// ─── HTTPS callable ───────────────────────────────────────────────────────────

/**
 * Save the current user's daily skin assessment.
 *
 * Request payload:
 *   timezone  {string}  — IANA timezone (e.g. "Europe/Moscow").
 *   metrics   {object}  — 1–4 keys from ALL_METRIC_KEYS; values: integer
 *                         1–10 or null.
 *
 * Behaviour:
 *   • dateKey is computed server-side from the current UTC instant + timezone.
 *   • All 12 metric keys are stored; unset ones default to null.
 *   • Uses set + merge:true so subsequent calls on the same day overwrite only
 *     the provided metric values; other top-level fields (e.g. photoUrl, note)
 *     written by the client are preserved.
 *
 * Returns: { dateKey: string }  (YYYY-MM-DD in the user's local timezone)
 *
 * Writes to: users/{uid}/daily_assessments/{dateKey}
 *   Admin SDK bypasses Firestore security rules — direct client writes to this
 *   collection are blocked in firestore.rules.
 */
export const saveDailyAssessment = onCall(
  { region: "europe-west1" },
  async (request) => {
    // ── Auth ──────────────────────────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }
    const uid = request.auth.uid;

    // ── Input validation ──────────────────────────────────────────────────────
    const payload = request.data as Record<string, unknown>;
    const { timezone, metrics } = payload;

    if (typeof timezone !== "string" || !IANAZone.isValidZone(timezone)) {
      throw new HttpsError(
        "invalid-argument",
        "'timezone' must be a valid IANA timezone string (e.g. \"Europe/Moscow\")."
      );
    }

    if (
      typeof metrics !== "object" ||
      metrics === null ||
      Array.isArray(metrics)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "'metrics' must be a non-null key/value object."
      );
    }

    const metricsMap = metrics as Record<string, unknown>;
    const requestedKeys = Object.keys(metricsMap);

    if (requestedKeys.length === 0 || requestedKeys.length > 4) {
      throw new HttpsError(
        "invalid-argument",
        `'metrics' must contain 1–4 keys; received ${requestedKeys.length}.`
      );
    }

    const unknownKeys = requestedKeys.filter(
      (k) => !(ALL_METRIC_KEYS as readonly string[]).includes(k)
    );
    if (unknownKeys.length > 0) {
      throw new HttpsError(
        "invalid-argument",
        `Unknown metric key(s): ${unknownKeys.join(", ")}.`
      );
    }

    for (const [key, value] of Object.entries(metricsMap)) {
      if (
        value !== null &&
        (typeof value !== "number" || value < 1 || value > 10)
      ) {
        throw new HttpsError(
          "invalid-argument",
          `Metric '${key}' must be a number in [1, 10] or null; received ${JSON.stringify(value)}.`
        );
      }
    }

    // ── dateKey ───────────────────────────────────────────────────────────────
    const dateKey = DateTime.now().setZone(timezone).toISODate();
    if (!dateKey) {
      throw new HttpsError("internal", "Failed to compute date key from timezone.");
    }

    // ── Build document ────────────────────────────────────────────────────────
    // Start with null defaults for all metrics, then apply provided values.
    const fullMetrics: Record<string, number | null> = {};
    for (const k of ALL_METRIC_KEYS) fullMetrics[k] = null;
    Object.assign(fullMetrics, metricsMap as Record<string, number | null>);

    const now = admin.firestore.FieldValue.serverTimestamp();
    const docData = {
      dateKey,
      metrics: fullMetrics,
      updatedAt: now,
    };

    // ── Write ─────────────────────────────────────────────────────────────────
    const ref = db
      .collection("users")
      .doc(uid)
      .collection("daily_assessments")
      .doc(dateKey);

    // merge:true preserves top-level fields not present in docData
    // (e.g. photoUrl, note, createdAt set by the client directly).
    await ref.set(docData, { merge: true });

    logger.info(
      `Daily assessment saved. uid=${uid} dateKey=${dateKey} ` +
      `keys=[${requestedKeys.join(",")}]`
    );

    return { dateKey };
  }
);
