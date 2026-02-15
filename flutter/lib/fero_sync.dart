import 'dart:async';

import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/core/sync_event.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';

/// --- FeroSync ---
/// Main orchestrator for syncing multiple features using handlers.
/// Handles:
/// - Initial sync
/// - Conflict resolution
/// - Retry/backoff strategies
/// - Event broadcasting for UI or logging
class FeroSync {
  /// Manager for performing the initial sync of all features
  late final InitialSyncManager initialManager;

  /// Map of feature keys to their respective handlers
  final Map<String, SyncHandler> handlers;

  /// Strategy to handle retries/backoff for failed sync attempts
  final BackoffStrategy backoffStrategy;

  /// Strategy to resolve conflicts between local and remote data
  final ConflictResolutionStrategy conflictStrategy;

  /// Optional subscription to listen to events internally
  StreamSubscription? _eventSubscription;

  /// Private constructor to enforce usage of the async factory `create`
  FeroSync._({
    required this.handlers,
    required this.backoffStrategy,
    required this.conflictStrategy,
  }) {
    initialManager = InitialSyncManager(
      handlers: handlers,
      backoffStrategy: backoffStrategy,
      maxRetries: 5, // Retry initial sync up to 5 times
    );
  }

  /// Factory method to create an instance of FeroSync asynchronously
  /// Sets default backoff and conflict resolution strategies if none are provided
  static Future<FeroSync> create({
    required Map<String, SyncHandler> handlers,
    BackoffStrategy? backoffStrategy,
    ConflictResolutionStrategy? conflictStrategy,
  }) async {
    final backoff = backoffStrategy ??
        ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000);

    final strategy =
        conflictStrategy ?? ConflictResolutionStrategy.highestVersionWins;

    return FeroSync._(
      handlers: handlers,
      backoffStrategy: backoff,
      conflictStrategy: strategy,
    );
  }

  /// Start listening to sync events
  Future<void> startSync() async {
    await initialManager.startListeningToEvents();
  }

  /// Run the initial sync for all registered features
  Future<void> run() async {
    await initialManager.run();
  }

  /// Get current status of a specific feature
  dynamic getFeatureStatus(String featureKey) {
    return initialManager.getFeatureStatus(featureKey);
  }

  /// Emit a sync event manually
  void emitSyncEvent(SyncEvent event) {
    initialManager.emitEvent(event);
  }

  /// Trigger an initial sync for a specific feature
  void triggerInitialSync(String featureKey) {
    emitSyncEvent(InitialSyncRequiredEvent(featureKey: featureKey));
  }

  /// Stream to observe status updates (e.g., syncing, completed, failed)
  Stream<dynamic> get statusStream => initialManager.statusStream;

  /// Stream to observe raw sync events for logging or UI updates
  Stream<SyncEvent> get eventStream => initialManager.eventStream;

  /// Cancel ongoing operations safely
  void cancel() {
    initialManager.cancel();
  }

  /// Dispose resources when the FeroSync instance is no longer needed
  void dispose() {
    _eventSubscription?.cancel();
    initialManager.dispose();
  }
}
