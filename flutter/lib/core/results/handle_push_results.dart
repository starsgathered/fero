/// Result of handling push results from the server.
///
/// Keeps the minimal set of data consumers need right now:
/// - ids that were marked synced (should clear local "locallyModified")
/// - ids that had conflicts
/// - ids that failed to push
///
/// Designed to be small and extensible without over-engineering.
class HandlePushResults {
  final List<String> markedSyncedIds;
  final List<String> conflictIds;
  final List<String> failedIds;
  final Map<String, dynamic> metadata;

  const HandlePushResults({
    this.markedSyncedIds = const [],
    this.conflictIds = const [],
    this.failedIds = const [],
    this.metadata = const {},
  });

  bool get hasMarkedSynced => markedSyncedIds.isNotEmpty;
  bool get hasConflicts => conflictIds.isNotEmpty;
  bool get hasFailures => failedIds.isNotEmpty;
}
