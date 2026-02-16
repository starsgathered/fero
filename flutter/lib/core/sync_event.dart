/// Base class for sync-related events.
abstract class SyncEvent {
  final String featureKey;
  final DateTime timestamp;

  SyncEvent({
    required this.featureKey,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Event emitted when a feature requires initial synchronization.
class InitialSyncRequiredEvent extends SyncEvent {
  InitialSyncRequiredEvent({required super.featureKey, super.timestamp});
}

/// Event emitted when initial sync starts for a feature.
class InitialSyncStartedEvent extends SyncEvent {
  InitialSyncStartedEvent({required super.featureKey, super.timestamp});
}

/// Event emitted when initial sync completes successfully for a feature.
class InitialSyncCompletedEvent extends SyncEvent {
  InitialSyncCompletedEvent({required super.featureKey, super.timestamp});
}

/// Event emitted when initial sync fails for a feature.
class InitialSyncFailedEvent extends SyncEvent {
  final Exception error;

  InitialSyncFailedEvent({
    required super.featureKey,
    required this.error,
    super.timestamp,
  });
}

/// Event for when incremental sync starts for a feature
class IncrementalSyncStartedEvent extends SyncEvent {
  IncrementalSyncStartedEvent({required super.featureKey});
}

/// Event for when incremental sync completes for a feature
class IncrementalSyncCompletedEvent extends SyncEvent {
  IncrementalSyncCompletedEvent({required super.featureKey});
}

/// Event for when incremental sync fails for a feature
class IncrementalSyncFailedEvent extends SyncEvent {
  final String error;

  IncrementalSyncFailedEvent({
    required super.featureKey,
    required this.error,
  });
}
