import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/models/sync_checkpoint.dart';

/// --- SyncBatchResult ---
/// Result of fetching a batch of items from the server or local storage.
/// Supports optional pagination with a checkpoint.
class SyncBatchResult {
  /// List of items in this batch
  final List<SyncPayload<ServerItem>> items;

  /// Checkpoint for the next page. Null means no more pages.
  final SyncCheckpoint? checkpoint;

  SyncBatchResult({
    required this.items,
    this.checkpoint,
  });
}
