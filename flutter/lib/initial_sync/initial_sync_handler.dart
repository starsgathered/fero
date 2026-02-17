/* 
--- Versioning Overview ---
Every item in Fero is tracked using a `version` number.
Versions are server-assigned and used for ordering, not timestamps.

Why versions instead of timestamps?
1. Server is the source of truth, so clients don’t rely on local clocks.
2. Deterministic: version X always comes before version X+1.
3. Works in offline-first, distributed setups.
4. Timestamps are kept only for analytics/UI, not for ordering.

Versions are simple integers stored inside the payload.
They are the main authority for ordering and conflict resolution.
*/

import 'package:fero_sync/core/results/apply_result.dart';
import 'package:fero_sync/core/results/sync_batch_result.dart';
import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/models/sync_checkpoint.dart';

/// --- InitialSyncHandler ---
/// Contract for a feature-specific initial sync implementation.
/// Handles downloading remote data for the first time and saving it locally.
abstract class InitialSyncHandler {
  /// Download remote data with checkpoint-based pagination
  /// `batchSize` controls how many items to fetch per page (required).
  /// Returns a batch and a nextCheckpoint if more pages are available
  Future<SyncBatchResult> fetchRemoteData({
    SyncCheckpoint? checkpoint,
    required int batchSize,
  });

  /// Save downloaded remote data to local storage
  /// Returns success/failure with detailed errors
  Future<ApplyResult> saveToLocal(List<SyncPayload<ServerItem>> remoteData);
}
