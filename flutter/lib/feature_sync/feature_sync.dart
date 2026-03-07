import 'dart:async';

import 'package:fero_sync/feature_sync/feature_sync_status.dart';
import 'package:fero_sync/policies/backoff.dart';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/core/exceptions.dart';
import 'package:fero_sync/core/results/apply_result.dart';
import 'package:fero_sync/core/sync_executor.dart';
import 'package:fero_sync/feature_sync/feature_sync_config.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';
import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';

/// Incremental sync manager for background/continuous syncing.
/// Handles priority-based, dependency-aware, and concurrent sync operations.
///
/// Follows:
/// - Single Responsibility: Orchestrates feature sync workflows
/// - Open/Closed: Extensible via FeatureSyncConfig without modification
/// - Liskov Substitution: Works with any FeatureSyncHandler implementation
/// - Interface Segregation: Depends only on specific interfaces it needs
/// - Dependency Inversion: Depends on abstractions (interfaces), not concrete classes
class FeatureSyncManager {
  final Map<String, FeatureSyncConfig> _featureConfigs;
  final SyncMetaDataRepo metaRepo;
  final SyncExecutor _executor;
  final int batchSize;
  final ConflictResolutionStrategy conflictStrategy;

  final Map<String, FeatureSyncStatus> _featureStatuses = {};

  int _activeSync = 0;
  bool _disposed = false;
  final Set<String> _pendingQueue = {}; // Features waiting to sync
  final Set<String> _runningSync = {}; // Features currently syncing
  final Set<String> _completedSync =
      {}; // Features that completed in this cycle
  final int _maxConcurrent;

  FeatureSyncManager({
    required Map<String, FeatureSyncConfig> featureConfigs,
    required this.metaRepo,
    BackoffStrategy? backoffStrategy,
    int maxRetries = 3,
    int maxConcurrent = 2,
    this.batchSize = 50,
    this.conflictStrategy = ConflictResolutionStrategy.highestVersionWins,
  })  : _featureConfigs = Map.unmodifiable(featureConfigs),
        _maxConcurrent = maxConcurrent,
        _executor = SyncExecutor(
          retryPolicy: RetryPolicy(
            backoff: backoffStrategy ??
                ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000),
            maxRetries: maxRetries,
          ),
        ) {
    _validateDependencies();
  }

  /// Get or create feature-level status
  FeatureSyncStatus getFeatureStatus(String featureKey) {
    return _featureStatuses.putIfAbsent(
      featureKey,
      () => FeatureSyncStatus(featureKey: featureKey),
    );
  }

  /// Validate that all dependencies reference registered features
  void _validateDependencies() {
    for (final entry in _featureConfigs.entries) {
      final feature = entry.key;
      final config = entry.value;

      for (final dep in config.dependencies) {
        if (!_featureConfigs.containsKey(dep)) {
          throw ArgumentError(
            'Dependency "$dep" for feature "$feature" is not registered',
          );
        }
      }
    }
  }

  /// Start background sync for a specific feature.
  /// Respects concurrency limits, priority ordering, and dependencies.
  void syncFeature(String featureKey, {bool force = false}) {
    if (_disposed) return;
    if (!_featureConfigs.containsKey(featureKey)) return;

    // Force push even if running or completed
    if (force ||
        (!_runningSync.contains(featureKey) &&
            !_completedSync.contains(featureKey))) {
      _pendingQueue.add(featureKey);
    }

    _processPending();
  }

  /// Start sync for all features, respecting priority, concurrency, and dependencies.
  void syncAll() {
    if (_disposed) return;

    _completedSync.clear(); // Reset for new sync cycle

    for (final featureKey in _featureConfigs.keys) {
      if (!_runningSync.contains(featureKey)) {
        _pendingQueue.add(featureKey);
      }
    }

    _processPending();
  }

  /// Process pending syncs up to the concurrency limit.
  /// Only runs features whose dependencies are satisfied.
  void _processPending() {
    if (_disposed) return;

    while (_activeSync < _maxConcurrent && _pendingQueue.isNotEmpty) {
      // Get next runnable feature (dependencies satisfied, highest priority)
      final nextFeature = _getNextRunnableFeature();

      if (nextFeature == null) {
        // No runnable features, wait for current syncs to complete
        break;
      }

      _pendingQueue.remove(nextFeature);
      _runningSync.add(nextFeature);
      _activeSync++;
      _performIncrementalSync(nextFeature);
    }
  }

  /// Get the next feature that can run based on:
  /// 1. Dependencies are satisfied
  /// 2. Highest priority among eligible features
  String? _getNextRunnableFeature() {
    // Keeps track of features already considered to avoid cycles
    final considered = <String>{};

    String? findNext(String feature) {
      if (considered.contains(feature)) return null;
      considered.add(feature);

      final config = _featureConfigs[feature];
      if (config == null) return null;

      // Check dependencies first
      for (final dep in config.dependencies) {
        if (!_completedSync.contains(dep)) {
          // If dependency is in pending queue, try running it first
          if (_pendingQueue.contains(dep)) {
            return findNext(dep);
          }
        }
      }

      // All dependencies are either completed or not pending, this feature is runnable
      return feature;
    }

    // Among pending, find the highest-priority runnable dependency chain
    final sortedPending = _pendingQueue.toList()
      ..sort((a, b) {
        final priorityA = _featureConfigs[a]?.priority ?? 0;
        final priorityB = _featureConfigs[b]?.priority ?? 0;
        return priorityB.compareTo(priorityA);
      });

    for (final feature in sortedPending) {
      final next = findNext(feature);
      if (next != null) return next;
    }

    return null;
  }

  /// Perform incremental sync for a feature.
  Future<void> _performIncrementalSync(String featureKey) async {
    final featureStatus = getFeatureStatus(featureKey);
    featureStatus.start();

    try {
      final config = _featureConfigs[featureKey];
      if (config == null) {
        throw HandlerNotFoundException(
          'No sync config registered for feature: $featureKey',
        );
      }
      final handler = config.handler;
      while (true) {
        final localBatch = await handler.getLocallyModified(
          batchSize: batchSize,
        );

        if (localBatch.isEmpty) break;

        final pushResult = await handler.pushLocalChanges(localBatch);
        if (!pushResult.success) {
          throw SyncFailedException(
              'Failed to push local changes: ${pushResult.errors}');
        }
      }
      // Get last synced checkpoint
      final initialCheckpoint = await metaRepo.getCheckpoint(featureKey);

      // Execute paginated sync with conflict resolution
      await _executor.executePaginatedSync(
        fetchBatch: (checkpoint) => handler.fetchRemoteChanges(
          checkpoint: checkpoint,
          batchSize: batchSize,
        ),
        applyBatch: (items) async {
          // Apply conflict resolution before applying to local
          final itemsToApply = <SyncPayload<ServerItem>>[];

          final localItems = await handler.getLocallyModifiedByIds(
              ids: items.map((e) => e.data.id).toList());

          // Build O(1) lookup map — scalable for large batches
          final Map<String, SyncPayload<LocalItem>> localMap = {
            for (final item in localItems) item.data.id: item,
          };

          for (final remoteItem in items) {
            final localMatch = localMap[remoteItem.data.id];

            if (localMatch == null) {
              // No conflict
              itemsToApply.add(remoteItem);
              continue;
            }

            final resolution = ConflictResolver.resolve(
              local: localMatch.data,
              remote: remoteItem.data,
              strategy: conflictStrategy,
            );

            if (resolution.applyRemote) {
              itemsToApply.add(remoteItem);
            }
          }

          if (itemsToApply.isEmpty) {
            return ApplyResult.success();
          }

          return await handler.applyRemoteChanges(itemsToApply);
        },
        featureKey: featureKey,
        onBatchComplete: (checkpoint) async {
          if (checkpoint != null && checkpoint != initialCheckpoint) {
            await metaRepo.updateCheckpoint(featureKey, checkpoint);
          }
        },
        initialCheckpoint: initialCheckpoint,
      );

      featureStatus.complete();
      _completedSync.add(featureKey);
    } catch (e) {
      featureStatus.fail(e.toString());
    } finally {
      _runningSync.remove(featureKey);
      _activeSync--;
      _processPending();
    }
  }

  void dispose() {
    _disposed = true;
  }
}
