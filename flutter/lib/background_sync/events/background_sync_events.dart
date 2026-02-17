import 'package:fero_sync/core/events/sync_event.dart';

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
