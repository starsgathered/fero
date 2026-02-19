import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/models/sync_checkpoint.dart';

/// --- SyncBatchResult ---
/// Result of fetching a batch of items from the server or local storage.
/// Supports checkpoint-based pagination.
///
/// Termination of pagination is signalled by the presence (or absence)
/// of a checkpoint (cursor/afterId) returned by the server, or by an
/// empty `items` list. This follows cursor/next-id style APIs.
class SyncBatchResult {
  /// True if the operation succeeded
  final bool success;

  /// List of items in this batch
  final List<SyncPayload<ServerItem>> items;

  /// Checkpoint for the next page (typically last item's syncId).
  /// Used for resumable pagination: WHERE syncId > checkpoint.afterId
  final SyncCheckpoint? checkpoint;

  /// Error message if the operation failed
  final String? errorMessage;

  SyncBatchResult({
    required this.success,
    this.items = const [],
    this.checkpoint,
    this.errorMessage,
  });

  /// Success factory
  factory SyncBatchResult.success({
    required List<SyncPayload<ServerItem>> items,
    SyncCheckpoint? checkpoint,
  }) {
    return SyncBatchResult(
      success: true,
      items: items,
      checkpoint: checkpoint,
    );
  }

  /// Failure factory
  factory SyncBatchResult.failure(String errorMessage) {
    return SyncBatchResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}
