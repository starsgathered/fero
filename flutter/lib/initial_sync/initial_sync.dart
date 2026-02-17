import 'dart:async';

import 'package:fero_sync/policies/backoff.dart';
import 'package:fero_sync/core/exceptions.dart';
import 'package:fero_sync/core/events/sync_event.dart';
import 'package:fero_sync/core/sync_executor.dart';
import 'package:fero_sync/initial_sync/events/initial_sync_events.dart';
import 'package:fero_sync/initial_sync/initial_sync_handler.dart';
import 'package:fero_sync/initial_sync/initial_sync_service.dart';
import 'package:fero_sync/initial_sync/initial_sync_status.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';

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

  final StreamController<InitialSyncStatus> _statusController =
      StreamController.broadcast();
  final StreamController<SyncEvent> _eventController =
      StreamController.broadcast();

  InitialSyncStatus _status = InitialSyncStatus.notStarted;

  bool _isRunning = false;
  bool _isCancelled = false;
  bool _hasEverCompleted = false; // Track if full sync ever completed
  final Map<String, InitialSyncStatus> _featureStatuses = {};

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
        );

  @override
  InitialSyncStatus get status => _status;

  @override
  Stream<InitialSyncStatus> get statusStream => _statusController.stream;

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
    _setStatus(InitialSyncStatus.running);

    try {
      final featuresToSync = _featureConfigs.keys.toList();

      // Check if all features are already completed (optimized batch check)
      final allCompleted =
          await metaRepo.areAllInitialSyncsCompleted(featuresToSync);

      // If all features already synced, emit events for consistency and skip sync
      if (allCompleted) {
        _setStatus(InitialSyncStatus.completed);

        // Emit individual feature events for consistency
        for (final featureKey in featuresToSync) {
          _featureStatuses[featureKey] = InitialSyncStatus.completed;
          _emitEvent(InitialSyncAlreadyCompletedEvent(featureKey: featureKey));
        }
        // Already completed before, emit different event
        _emitEvent(FullInitialSyncAlreadyCompletedEvent(
            totalFeatures: featuresToSync.length));
        return;
      }

      for (final featureKey in featuresToSync) {
        if (_isCancelled) {
          _setStatus(InitialSyncStatus.cancelled);
          throw OperationCancelledException('Initial sync cancelled');
        }

        await _performSync(featureKey);
      }

      _setStatus(InitialSyncStatus.completed);

      // Only emit FullInitialSyncCompletedEvent if this is the first time completing
      if (!_hasEverCompleted) {
        _hasEverCompleted = true;
        _emitEvent(FullInitialSyncCompletedEvent(
            totalFeatures: featuresToSync.length));
      }
    } catch (e) {
      if (_status != InitialSyncStatus.cancelled) {
        _setStatus(InitialSyncStatus.failed);
      }
      rethrow;
    } finally {
      _isRunning = false;
    }
  }

  /// Get the sync status for a specific feature.
  @override
  InitialSyncStatus? getFeatureStatus(String featureKey) {
    return _featureStatuses[featureKey];
  }

  @override
  Future<void> startListeningToEvents() async {
    // Listen to events and process them
    _eventController.stream.listen(
      _handleSyncEvent,
      onError: (error) {
        if (!_statusController.isClosed) {
          _statusController.addError(error);
        }
      },
    );
  }

  /// Handle incoming sync events from the stream.
  void _handleSyncEvent(SyncEvent event) async {
    if (event is InitialSyncRequiredEvent) {
      if (!_featureConfigs.containsKey(event.featureKey)) {
        return; // Handler not available, skip
      }

      try {
        await _performSync(event.featureKey);
      } catch (e) {
        // Error logged via status stream
      }
    }
  }

  /// Perform initial sync for a feature using batch operations.
  /// Fetches and applies multiple items in bulk for performance.
  Future<void> _performSync(String featureKey) async {
    _featureStatuses[featureKey] = InitialSyncStatus.running;
    _emitEvent(InitialSyncStartedEvent(featureKey: featureKey));

    try {
      final config = _featureConfigs[featureKey];
      if (config == null) {
        _featureStatuses[featureKey] = InitialSyncStatus.failed;
        throw HandlerNotFoundException(
          'No sync config registered for feature: $featureKey',
        );
      }
      final handler = config.handler;

      // If initial sync was already completed for this feature, skip it.
      final alreadyInitial = await metaRepo.isInitialSyncCompleted(featureKey);
      if (alreadyInitial) {
        _featureStatuses[featureKey] = InitialSyncStatus.completed;
        _emitEvent(InitialSyncCompletedEvent(featureKey: featureKey));
        return;
      }

      if (_isCancelled) {
        throw OperationCancelledException('Sync cancelled before trying');
      }

      // Get last checkpoint for initial sync (separate from background sync)
      final initialCheckpoint =
          await metaRepo.getLastInitialSyncCheckpoint(featureKey);

      // Execute paginated sync using common executor
      await _executor.executePaginatedSync(
        fetchBatch: (checkpoint) => handler.fetchRemoteData(
          checkpoint: checkpoint,
          batchSize: batchSize,
        ),
        applyBatch: (items) => handler.saveToLocal(items),
        featureKey: featureKey,
        onBatchComplete: (checkpoint) {
          metaRepo.updateLastInitialSyncCheckpoint(featureKey, checkpoint);
        },
        isCancelled: () => _isCancelled,
        initialCheckpoint: initialCheckpoint,
      );

      _featureStatuses[featureKey] = InitialSyncStatus.completed;
      await metaRepo.setInitialSyncCompleted(featureKey, true);
      _emitEvent(InitialSyncCompletedEvent(featureKey: featureKey));
    } catch (e) {
      final st = StackTrace.current;
      if (_status != InitialSyncStatus.cancelled) {
        _featureStatuses[featureKey] = InitialSyncStatus.failed;
        if (!_statusController.isClosed) _statusController.addError(e, st);
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
    _statusController.close();
    _eventController.close();
  }

  void _setStatus(InitialSyncStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  void _emitEvent(SyncEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }
}
