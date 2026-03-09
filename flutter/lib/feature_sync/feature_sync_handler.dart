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
import 'package:fero_sync/core/results/push_local_changes.dart';
import 'package:fero_sync/core/results/sync_batch_result.dart';
import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/models/sync_checkpoint.dart';

/// --- FeatureSyncHandler ---
/// Contract for a feature-specific background sync implementation.
/// Handles fetching local/remote data and applying bidirectional changes.
///
///  clients only depend on methods they use.
/// - focused solely on data transfer operations.
abstract class FeatureSyncHandler {
  /// Fetch remote changes for sync with checkpoint-based pagination
  ///
  /// `checkpoint` indicates where to resume (null for first page)
  /// `batchSize` controls how many items to fetch per page (required)
  ///
  /// Returns a batch and a nextCheckpoint if more pages are available.
  /// Items should be ordered by syncId ASC for deterministic pagination.
  Future<SyncBatchResult> fetchRemoteChanges({
    SyncCheckpoint? checkpoint,
    required int batchSize,
  });

  /// Fetch locally modified items that need to be synced
  /// Returns items that have changed locally and need to be pushed to server
  Future<List<SyncPayload<LocalItem>>> getLocallyModifiedByIds({
    required List<String> ids,
  });

  /// Fetch locally modified items that need to be synced
  /// Returns items that have changed locally and need to be pushed to server
  Future<List<SyncPayload<LocalItem>>> getLocallyModified({
    int batchSize = 50,
  });

  /// Apply remote changes to local storage
  /// Returns success/failure with detailed errors
  Future<ApplyResult> applyRemoteChanges(
      List<SyncPayload<ServerItem>> remoteStates);

  /// Push local changes to remote server
  /// Returns success/failure with detailed errors
  Future<PushLocalChangesResult> pushLocalChanges(
      List<SyncPayload<LocalItem>> localStates);
}
