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
  InitialSyncRequiredEvent({required String featureKey, DateTime? timestamp})
      : super(featureKey: featureKey, timestamp: timestamp);
}

/// Event emitted when initial sync starts for a feature.
class InitialSyncStartedEvent extends SyncEvent {
  InitialSyncStartedEvent({required String featureKey, DateTime? timestamp})
      : super(featureKey: featureKey, timestamp: timestamp);
}

/// Event emitted when initial sync completes successfully for a feature.
class InitialSyncCompletedEvent extends SyncEvent {
  InitialSyncCompletedEvent({required String featureKey, DateTime? timestamp})
      : super(featureKey: featureKey, timestamp: timestamp);
}

/// Event emitted when initial sync fails for a feature.
class InitialSyncFailedEvent extends SyncEvent {
  final Exception error;

  InitialSyncFailedEvent({
    required String featureKey,
    required this.error,
    DateTime? timestamp,
  }) : super(featureKey: featureKey, timestamp: timestamp);
}

/// Event emitted when sync conflicts are detected during merge.
/// This allows apps to track and analyze conflicting changes.
class SyncConflictDetectedEvent extends SyncEvent {
  final List<String> conflictingIds; // IDs of entities with conflicts
  final int localChangesCount;       // Number of local changes
  final int remoteChangesCount;      // Number of remote changes
  final String resolutionStrategy;   // How conflicts were resolved

  SyncConflictDetectedEvent({
    required String featureKey,
    required this.conflictingIds,
    required this.localChangesCount,
    required this.remoteChangesCount,
    required this.resolutionStrategy,
    DateTime? timestamp,
  }) : super(featureKey: featureKey, timestamp: timestamp);
}
