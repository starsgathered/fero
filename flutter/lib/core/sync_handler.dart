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

--- Syncable Interface ---
Any object that can be synced should implement this interface.
It ensures every syncable object has:
- `syncId`: unique identifier for the item
- `version`: current version of the item */
abstract class Syncable {
  String get syncId;
  int get version;
}

/// --- SyncPayload ---
/// Generic container for a feature's data and its version.
/// - `T` is the actual business data type, which must implement Syncable.
/// - Keeps metadata separate from your business data.
class SyncPayload<T extends Syncable> {
  final T data;

  SyncPayload({required this.data});
}

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

/// --- ApplyResult ---
/// Result of trying to apply a batch of items (to local or remote storage)
/// Provides success flag and optional error details.
class ApplyResult {
  /// True if the operation succeeded
  final bool success;

  /// List of errors for failed items
  final List<ApplyError> errors;

  ApplyResult({
    required this.success,
    this.errors = const [],
  });

  /// Success factory
  factory ApplyResult.success() {
    return ApplyResult(success: true);
  }

  /// Failure factory
  factory ApplyResult.failure(List<ApplyError> errors) {
    return ApplyResult(success: false, errors: errors);
  }
}

/// --- ApplyError ---
/// Detailed info about why applying an item failed
class ApplyError {
  /// Error message or exception details
  final String message;

  /// Optional code for categorization
  final String? code;

  ApplyError({
    required this.message,
    this.code,
  });
}

/// --- SyncHandler ---
/// Contract for a feature-specific sync implementation.
/// Handles fetching local/remote data and applying changes.
abstract class SyncHandler {
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
