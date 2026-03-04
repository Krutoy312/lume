/**
 * Firebase bootstrap — imported by every handler module.
 *
 * Placing initializeApp() and setGlobalOptions() here guarantees that both
 * calls complete before any handler module body runs, which is required by
 * the ESM evaluation order in "module": "NodeNext" builds:
 *   1. This module is evaluated first (all handlers depend on it).
 *   2. v2 function registrations in the handler modules read global options
 *      at registration time, so setGlobalOptions() must precede them.
 */

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions";

admin.initializeApp();

// Applies to all v2 functions declared in handler modules.
setGlobalOptions({ maxInstances: 10, region: "europe-west1" });

export const db = admin.firestore();
