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
 * Note: setGlobalOptions() does NOT affect Gen 1 functions.
 * Region and runtime options must be set explicitly via region() / runWith().
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import * as v1 from "firebase-functions/v1";

import { db } from "../config/firebase.js";
import { DEFAULT_USER } from "../utils/date_utils.js";

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
