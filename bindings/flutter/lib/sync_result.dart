/// Result of a sync handler operation.
class SyncResult {
  final bool success;

  SyncResult.success() : success = true;
  SyncResult.failure() : success = false;
}
