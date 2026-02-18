import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/models/sync_checkpoint.dart';

/// --- SyncBatchResult ---
/// Result of fetching a batch of items from the server or local storage.
/// Supports optional pagination with a checkpoint.
class SyncBatchResult {
  /// True if the operation succeeded
  final bool success;

  /// List of items in this batch
  final List<SyncPayload<ServerItem>> items;

  /// Checkpoint for the next page. Null means no more pages.
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
