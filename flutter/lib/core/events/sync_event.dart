/// Base class for sync-related events.
abstract class SyncEvent {
  final String featureKey;
  final DateTime timestamp;

  SyncEvent({
    required this.featureKey,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
