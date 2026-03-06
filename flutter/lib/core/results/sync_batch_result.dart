import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';

/// --- SyncBatchResult ---
/// Result of fetching a batch of items from the server or local storage.
/// Supports checkpoint-based pagination.
///
/// Termination of pagination is signalled by the presence (or absence)
/// of a checkpoint (cursor) returned by the server, or by an
/// empty `items` list. This follows cursor/next-id style APIs.
class SyncBatchResult {
  /// True if the operation succeeded
  final bool success;

  /// List of items in this batch
  final List<SyncPayload<ServerItem>> items;

  bool stopIfNoNextPage = false;

  /// Error message if the operation failed
  final String? errorMessage;

  SyncBatchResult({
    required this.success,
    this.items = const [],
    this.stopIfNoNextPage = false,
    this.errorMessage,
  });

  /// Success factory
  factory SyncBatchResult.success({
    required List<SyncPayload<ServerItem>> items,
    bool? stopIfNoNextPage,
  }) {
    return SyncBatchResult(
      success: true,
      items: items,
      stopIfNoNextPage: stopIfNoNextPage ?? false,
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
