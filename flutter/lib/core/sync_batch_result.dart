import 'package:fero_sync/core/sync_payload.dart';
import 'package:fero_sync/core/syncable.dart';

/// --- SyncBatchResult ---
/// Result of fetching a batch of items from the server or local storage.
/// Supports optional pagination with a cursor.
class SyncBatchResult {
  /// List of items in this batch
  final List<SyncPayload<Syncable>> items;

  /// Cursor for the next page. Null means no more pages.
  final String? nextCursor;

  SyncBatchResult({
    required this.items,
    this.nextCursor,
  });
}
