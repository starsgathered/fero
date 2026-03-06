import 'dart:async';

import 'package:fero_sync/initial_sync/enum/initial_sync_status.dart';
import 'package:fero_sync/policies/backoff.dart';
import 'package:fero_sync/core/exceptions.dart';
import 'package:fero_sync/core/sync_executor.dart';
import 'package:fero_sync/initial_sync/initial_sync_handler.dart';
import 'package:fero_sync/initial_sync/initial_sync_service.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';
import 'package:flutter/foundation.dart';

/// Configuration for a feature's initial sync behavior.
class InitialSyncConfig {
  final InitialSyncHandler handler;
  final int priority; // Higher = syncs first (optional)

  const InitialSyncConfig({
    required this.handler,
    this.priority = 0,
  });
}

/// Event-driven initial sync manager.
/// Listens to [InitialSyncRequiredEvent] from Fero server and orchestrates sync.
/// Automatically handles log storage and conflict tracking.
class InitialSyncManager implements InitialSyncService {
  final Map<String, InitialSyncConfig> _featureConfigs;
  final SyncExecutor _executor;
  final int batchSize;
  final int maxBatchSize;
  final SyncMetaDataRepo metaRepo;

  bool _isRunning = false;
  bool _isCancelled = false;
  bool? _hasEverCompleted; // Track if full sync ever completed

  final ValueNotifier<InitialSyncStatus> statusNotifier =
      ValueNotifier(InitialSyncStatus.notStarted);

  InitialSyncManager({
    required Map<String, InitialSyncConfig> featureConfigs,
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

  /// Run initial sync for all handlers.
  @override
  Future<void> run() async {
    if (_isRunning) {
      throw SyncAlreadyRunningException('Initial sync already running');
    }
    final featuresToSync = _featureConfigs.keys.toList();
    final allCompleted = _hasEverCompleted ??=
        await metaRepo.areAllInitialSyncsCompleted(featuresToSync);
    if (allCompleted) {
      _hasEverCompleted = true;
      _setStatus(InitialSyncStatus.completed);
      return;
    }
    _isRunning = true;
    _isCancelled = false;
    _setStatus(InitialSyncStatus.running);

    try {
      for (final featureKey in featuresToSync) {
        if (_isCancelled) {
          _setStatus(InitialSyncStatus.cancelled);
          throw OperationCancelledException('Initial sync cancelled');
        }

        await _performSync(featureKey);
      }

      // Only emit FullInitialSyncCompletedEvent if this is the first time completing
      _hasEverCompleted = true;
      _setStatus(InitialSyncStatus.completed);
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
    try {
      final config = _featureConfigs[featureKey];
      if (config == null) {
        throw HandlerNotFoundException(
          'No sync config registered for feature: $featureKey',
        );
      }
      final handler = config.handler;
      if (_hasEverCompleted == true) {
        // If full sync already completed before, skip to avoid redundant work
        _setStatus(InitialSyncStatus.completed);
        return;
      }
      // If initial sync was already completed for this feature, skip it.
      final alreadyInitial = await metaRepo.isInitialSyncCompleted(featureKey);
      if (alreadyInitial) {
        return;
      }

      if (_isCancelled) {
        throw OperationCancelledException('Sync cancelled before trying');
      }

      // Get last checkpoint for initial sync (separate from background sync)
      final initialCheckpoint = await metaRepo.getCheckpoint(featureKey);

      // Execute paginated sync using common executor
      await _executor.executePaginatedSync(
        fetchBatch: (checkpoint) => handler.fetchRemoteData(
          checkpoint: checkpoint,
          batchSize: batchSize,
        ),
        applyBatch: (items) => handler.saveToLocal(items),
        featureKey: featureKey,
        onBatchComplete: (checkpoint) async {
          if (checkpoint != null && checkpoint != initialCheckpoint) {
            await metaRepo.updateCheckpoint(featureKey, checkpoint);
          }
        },
        isCancelled: () => _isCancelled,
        initialCheckpoint: initialCheckpoint,
      );

      await metaRepo.setInitialSyncCompleted(featureKey, true);
      _setStatus(InitialSyncStatus.completed);
    } catch (e) {
      if (!_isCancelled) {
        _setStatus(InitialSyncStatus.failed);
      }
      rethrow;
    }
  }

  @override
  void cancel() {
    _isCancelled = true;
  }

  @override
  void dispose() {
    statusNotifier.dispose();
    _isRunning = false;
    _isCancelled = false;
    _hasEverCompleted = null;
  }

  void _setStatus(InitialSyncStatus status) {
    statusNotifier.value = status;
  }
}
