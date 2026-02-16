import 'dart:async';

import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/core/sync_event.dart';
import 'package:fero_sync/core/initial_sync_handler.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';

/// --- FeroSync ---
/// Main orchestrator for syncing multiple features using handlers.
/// Handles:
/// - Initial sync
/// - Conflict resolution
/// - Retry/backoff strategies
/// - Event broadcasting for UI or logging
class FeroSync {
  /// Manager for performing the initial sync of all features
  final InitialSyncManager initialManager;

  /// Repository for storing sync metadata (e.g. last cursors)
  final SyncMetaDataRepo metadataRepo;

  /// Map of feature keys to their respective handlers
  final Map<String, InitialSyncHandler> initialSyncHandlers;

  /// Strategy to handle retries/backoff for failed sync attempts
  final RetryPolicy retryPolicy;

  /// Strategy to resolve conflicts between local and remote data
  final ConflictResolutionStrategy conflictStrategy;

  /// Number of items to fetch per remote batch during initial sync
  final int batchSize;

  /// Maximum allowed batch size in production (cap)
  final int maxBatchSize;

  /// Optional subscription to listen to events internally
  StreamSubscription? _eventSubscription;

  /// Private constructor to enforce usage of the async factory `create`
  FeroSync._({
    required this.initialSyncHandlers,
    required this.retryPolicy,
    required this.conflictStrategy,
    required this.batchSize,
    required this.maxBatchSize,
    required this.metadataRepo,
    required this.initialManager,
  });

  /// Factory method to create an instance of FeroSync asynchronously
  /// Sets default backoff and conflict resolution strategies if none are provided
  static Future<FeroSync> create({
    required Map<String, InitialSyncHandler> initialSyncHandlers,
    required SyncMetaDataRepo metadataRepo,
    RetryPolicy? retryPolicy,
    ConflictResolutionStrategy? conflictStrategy,
    int? batchSize,
    int? maxBatchSize,
    InitialSyncManager? initialManager,
  }) async {
    final retryPolicyValue = retryPolicy ??
        RetryPolicy(
            backoff:
                ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000));

    final strategy =
        conflictStrategy ?? ConflictResolutionStrategy.highestVersionWins;

    final int bs = batchSize ?? 50;
    final int mbs = maxBatchSize ?? 500;

    // If caller provided an InitialSyncManager, use it; otherwise create a default one
    final InitialSyncManager initManager = initialManager ??
        InitialSyncManager(
          handlers: initialSyncHandlers,
          retryPolicy: retryPolicyValue,
          maxRetries: 5,
          batchSize: bs,
          maxBatchSize: mbs,
          metaRepo: metadataRepo,
        );

    return FeroSync._(
      initialSyncHandlers: initialSyncHandlers,
      retryPolicy: retryPolicyValue,
      conflictStrategy: strategy,
      batchSize: bs,
      maxBatchSize: mbs,
      metadataRepo: metadataRepo,
      initialManager: initManager,
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
