enum PushStatus { success, conflict, failed }

class PushResultItem<T> {
  final String id;
  final PushStatus status;
  final DateTime timestamp;
  final String? conflictReason;

  const PushResultItem({
    required this.id,
    required this.status,
    required this.timestamp,
    this.conflictReason,
  });
}

class PushLocalChangesResult<T> {
  final List<PushResultItem<T>> items;

  const PushLocalChangesResult({this.items = const []});

  List<String> get successIds => items
      .where((i) => i.status == PushStatus.success)
      .map((i) => i.id)
      .toList();

  List<String> get conflictIds => items
      .where((i) => i.status == PushStatus.conflict)
      .map((i) => i.id)
      .toList();

  List<String> get failedIds => items
      .where((i) => i.status == PushStatus.failed)
      .map((i) => i.id)
      .toList();

  bool get hasSuccess => successIds.isNotEmpty;
  bool get hasConflicts => conflictIds.isNotEmpty;
  bool get hasFailures => failedIds.isNotEmpty;
}
