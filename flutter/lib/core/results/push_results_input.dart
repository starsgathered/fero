/// Minimal summary of push results passed to handlers.
///
/// Intentionally excludes conflict ids — handlers should not receive
/// conflicts as input to `handlePushResults`.
class HandlePushResultsInput {
  final List<String> successIds;
  final List<String> failedIds;

  const HandlePushResultsInput({
    this.successIds = const [],
    this.failedIds = const [],
  });

  bool get hasSuccess => successIds.isNotEmpty;
  bool get hasFailures => failedIds.isNotEmpty;
}
