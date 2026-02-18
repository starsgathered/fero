import 'package:fero_sync/core/events/sync_event.dart';

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

/// Event emitted when initial sync completes successfully for a feature.
class InitialSyncAlreadyCompletedEvent extends SyncEvent {
  InitialSyncAlreadyCompletedEvent(
      {required super.featureKey, super.timestamp});
}

/// Event emitted when ALL features have completed initial sync.
class FullInitialSyncCompletedEvent extends SyncEvent {
  final int totalFeatures;

  FullInitialSyncCompletedEvent({
    required this.totalFeatures,
    super.timestamp,
  }) : super(featureKey: '__all__');
}

/// Event emitted when initial sync run is called but all features were already completed.
/// Use this to differentiate from first-time completion.
class FullInitialSyncAlreadyCompletedEvent extends SyncEvent {
  final int totalFeatures;

  FullInitialSyncAlreadyCompletedEvent({
    required this.totalFeatures,
    super.timestamp,
  }) : super(featureKey: '__all__');
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

/// Event emitted when initial sync status changes to running.
class InitialSyncRunningEvent extends SyncEvent {
  InitialSyncRunningEvent({super.timestamp}) : super(featureKey: '__all__');
}

/// Event emitted when initial sync status changes to cancelled.
class InitialSyncCancelledEvent extends SyncEvent {
  InitialSyncCancelledEvent({super.timestamp}) : super(featureKey: '__all__');
}

/// Event emitted when initial sync status changes to not started.
class InitialSyncNotStartedEvent extends SyncEvent {
  InitialSyncNotStartedEvent({super.timestamp}) : super(featureKey: '__all__');
}
