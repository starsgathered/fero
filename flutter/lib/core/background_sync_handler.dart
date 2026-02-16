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
import 'package:fero_sync/core/apply_result.dart';
import 'package:fero_sync/core/sync_batch_result.dart';
import 'package:fero_sync/core/sync_payload.dart';
import 'package:fero_sync/core/syncable.dart';

/// --- SyncHandler ---
/// Contract for a feature-specific sync implementation.
/// Handles fetching local/remote data and applying changes.
abstract class BackgroundSyncHandler {
  /// Fetch local items for sync
  /// Default: return all items as a list of SyncPayload
  Future<List<SyncPayload<Syncable>>> getLocal();

  /// Fetch remote items for sync with optional pagination
  /// `batchSize` controls how many items to fetch per page (required).
  /// Returns a batch and a nextCursor if more pages are available
  Future<SyncBatchResult> getRemote({String? cursor, required int batchSize});

  /// Apply a batch of remote items to local storage
  /// Returns success/failure with detailed errors
  Future<ApplyResult> applyToLocal(List<SyncPayload<Syncable>> remoteStates);

  /// Apply a batch of local items to remote storage
  /// Returns success/failure with detailed errors
  Future<ApplyResult> applyToRemote(List<SyncPayload<Syncable>> localStates);
}
