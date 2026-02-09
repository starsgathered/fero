/// Result of a sync handler operation.
class SyncResult {
  final bool success;
  final Exception? error;

  SyncResult.success() : success = true, error = null;
  SyncResult.failure(this.error) : success = false;
}
