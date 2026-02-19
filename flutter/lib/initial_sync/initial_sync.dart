import 'dart:async';

import 'package:fero_sync/policies/backoff.dart';
import 'package:fero_sync/core/exceptions.dart';
import 'package:fero_sync/core/events/sync_event.dart';
import 'package:fero_sync/core/sync_executor.dart';
import 'package:fero_sync/initial_sync/events/initial_sync_events.dart';
import 'package:fero_sync/initial_sync/initial_sync_handler.dart';
import 'package:fero_sync/initial_sync/initial_sync_service.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';
import 'package:flutter/cupertino.dart';

/// Configuration for a feature's initial sync behavior.
class FeatureInitialSyncConfig {
  final InitialSyncHandler handler;
  final int priority; // Higher = syncs first (optional)

  const FeatureInitialSyncConfig({
    required this.handler,
    this.priority = 0,
  });
}

/// Event-driven initial sync manager.
/// Listens to [InitialSyncRequiredEvent] from Fero server and orchestrates sync.
/// Automatically handles log storage and conflict tracking.
class InitialSyncManager implements InitialSyncService {
  final Map<String, FeatureInitialSyncConfig> _featureConfigs;
  final SyncExecutor _executor;
  final int batchSize;
  final int maxBatchSize;
  final SyncMetaDataRepo metaRepo;

  final StreamController<SyncEvent> _eventController =
      StreamController.broadcast();

  bool _isRunning = false;
  bool _isCancelled = false;
  bool _hasEverCompleted = false; // Track if full sync ever completed

  InitialSyncManager({
    required Map<String, FeatureInitialSyncConfig> featureConfigs,
    RetryPolicy? retryPolicy,
    int maxRetries = 5,
    required this.batchSize,
    required this.maxBatchSize,
    required this.metaRepo,
  })  : _featureConfigs = Map.unmodifiable(featureConfigs),
        _executor = SyncExecutor(
          retryPolicy: retryPolicy ??
              RetryPolicy(
                backoff: ExponentialBackoffStrategy(
                    baseMillis: 100, maxMillis: 30000),
                maxRetries: maxRetries,
              ),
        ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emitEvent(InitialSyncNotStartedEvent());
    });
  }

  @override
  Stream<SyncEvent> get eventStream => _eventController.stream;

  /// Run initial sync for all handlers.
  @override
  Future<void> run() async {
    if (_isRunning) {
      throw SyncAlreadyRunningException('Initial sync already running');
    }

    _isRunning = true;
    _isCancelled = false;

    try {
      final featuresToSync = _featureConfigs.keys.toList();

      // Check if all features are already completed (optimized batch check)
      final allCompleted =
          await metaRepo.areAllInitialSyncsCompleted(featuresToSync);

      // If all features already synced, emit events for consistency and skip sync
      if (allCompleted) {
        // Emit individual feature events for consistency without modifying the list
        final totalFeatures = featuresToSync.length;
        for (final featureKey in featuresToSync) {
          _emitEvent(InitialSyncAlreadyCompletedEvent(featureKey: featureKey));
        }
        // Already completed before, emit different event
        _emitEvent(
            FullInitialSyncAlreadyCompletedEvent(totalFeatures: totalFeatures));
        _isRunning = false;
        return;
      }
      _emitEvent(InitialSyncRunningEvent());

      for (final featureKey in featuresToSync) {
        if (_isCancelled) {
          _emitEvent(InitialSyncCancelledEvent());
          throw OperationCancelledException('Initial sync cancelled');
        }

        await _performSync(featureKey);
      }

      // Only emit FullInitialSyncCompletedEvent if this is the first time completing
      if (!_hasEverCompleted) {
        _hasEverCompleted = true;
        _emitEvent(FullInitialSyncCompletedEvent(
            totalFeatures: featuresToSync.length));
      }
    } catch (e) {
      if (!_isCancelled) {
        // Failed event handled by _performSync for specific features
      }
      rethrow;
    } finally {
      _isRunning = false;
    }
  }

  /// Perform initial sync for a feature using batch operations.
  /// Fetches and applies multiple items in bulk for performance.
  Future<void> _performSync(String featureKey) async {
    _emitEvent(InitialSyncStartedEvent(featureKey: featureKey));

    try {
      final config = _featureConfigs[featureKey];
      if (config == null) {
        throw HandlerNotFoundException(
          'No sync config registered for feature: $featureKey',
        );
      }
      final handler = config.handler;

      // If initial sync was already completed for this feature, skip it.
      final alreadyInitial = await metaRepo.isInitialSyncCompleted(featureKey);
      if (alreadyInitial) {
        _emitEvent(InitialSyncCompletedEvent(featureKey: featureKey));
        return;
      }

      if (_isCancelled) {
        throw OperationCancelledException('Sync cancelled before trying');
      }

      // Get last checkpoint for initial sync (separate from background sync)
      final initialCheckpoint =
          await metaRepo.getInitialSyncCheckpoint(featureKey);

      // Execute paginated sync using common executor
      await _executor.executePaginatedSync(
        fetchBatch: (checkpoint) => handler.fetchRemoteData(
          checkpoint: checkpoint,
          batchSize: batchSize,
        ),
        applyBatch: (items) => handler.saveToLocal(items),
        featureKey: featureKey,
        onBatchComplete: (checkpoint) {
          metaRepo.updateInitialSyncCheckpoint(featureKey, checkpoint);
        },
        isCancelled: () => _isCancelled,
        initialCheckpoint: initialCheckpoint,
      );

      await metaRepo.setInitialSyncCompleted(featureKey, true);
      _emitEvent(InitialSyncCompletedEvent(featureKey: featureKey));
    } catch (e) {
      if (!_isCancelled) {
        final exception = e is Exception ? e : Exception(e.toString());
        _emitEvent(
            InitialSyncFailedEvent(featureKey: featureKey, error: exception));
      }
      rethrow;
    }
  }

  @override
  void emitEvent(SyncEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  @override
  void cancel() {
    _isCancelled = true;
  }

  @override
  void dispose() {
    _eventController.close();
    _isRunning = false;
    _isCancelled = false;
    _hasEverCompleted = false;
  }

  void _emitEvent(SyncEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }
}
