/// Result of handling push results from the server.
///
/// Keeps the minimal set of data consumers need right now:
/// - ids that were marked synced (should clear local "locallyModified")
/// - ids that had conflicts
/// - ids that failed to push
///
/// Designed to be small and extensible without over-engineering.
class HandlePushResults {
  final bool success;

  const HandlePushResults({
    this.success = false,
  });
}
