import 'dart:async';

import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/core/exceptions.dart';
import 'package:fero_sync/core/sync_event.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';

/// Incremental sync manager for background/continuous syncing.
/// Handles priority-based and concurrent sync operations with backoff.
class BackgroundSyncManager {
  final Map<String, SyncHandler> _handlers;
  final Map<String, int> _handlerPriorities; // Higher = syncs first
  final SyncMetaDataRepo metaRepo;
  final RetryPolicy _retryPolicy;
  final int _maxConcurrent;
  final int batchSize;
  final ConflictResolutionStrategy conflictStrategy;

  final StreamController<SyncEvent> _eventController =
      StreamController.broadcast();

  int _activeSync = 0;
  bool _disposed = false;
  final List<String> _pendingQueue = []; // Ordered by priority

  BackgroundSyncManager({
    required Map<String, SyncHandler> handlers,
    Map<String, int>? handlerPriorities,
    required this.metaRepo,
    BackoffStrategy? backoffStrategy,
    int maxRetries = 3,
    int maxConcurrent = 2,
    this.batchSize = 50,
    this.conflictStrategy = ConflictResolutionStrategy.highestVersionWins,
  })  : _handlers = Map.unmodifiable(handlers),
        _handlerPriorities = handlerPriorities ?? {},
        _retryPolicy = RetryPolicy(
          backoff: backoffStrategy ??
              ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000),
          maxRetries: maxRetries,
        ),
        _maxConcurrent = maxConcurrent;

  Stream<SyncEvent> get eventStream => _eventController.stream;

  /// Start background sync for a specific feature.
  /// Respects concurrency limits and priority ordering.
  void syncFeature(String featureKey) {
    if (_disposed) return;
    if (!_handlers.containsKey(featureKey)) return;

    // Add to queue and process
    if (!_pendingQueue.contains(featureKey)) {
      _pendingQueue.add(featureKey);
      _sortByPriority();
    }

    _processPending();
  }

  /// Start sync for all features, respecting priority and concurrency.
  void syncAll() {
    if (_disposed) return;

    for (final featureKey in _handlers.keys) {
      if (!_pendingQueue.contains(featureKey)) {
        _pendingQueue.add(featureKey);
      }
    }

    _sortByPriority();
    _processPending();
  }

  /// Process pending syncs up to the concurrency limit.
  void _processPending() {
    if (_disposed) return;

    while (_activeSync < _maxConcurrent && _pendingQueue.isNotEmpty) {
      final featureKey = _pendingQueue.removeAt(0);
      _activeSync++;
      _performIncrementalSync(featureKey);
    }
  }

  /// Perform incremental sync for a feature.
  Future<void> _performIncrementalSync(String featureKey) async {
    _emitEvent(IncrementalSyncStartedEvent(featureKey: featureKey));

    try {
      final handler = _handlers[featureKey];
      if (handler == null) {
        throw HandlerNotFoundException(
          'No sync handler registered for feature: $featureKey',
        );
      }

      // Get last synced cursor
      String? cursor = await metaRepo.getLastBackgroundSyncedCursor(featureKey);

      // Fetch and apply updates in pages
      while (true) {
        final batchResult = await _retryPolicy.attempt(() async {
          return await handler.getRemote(cursor: cursor, batchSize: batchSize);
        });

        if (batchResult == null) {
          throw MaxRetriesExceededException(
            'Failed to fetch updates for feature: $featureKey',
          );
        }

        // Apply updates to local with conflict resolution
        if (batchResult.items.isNotEmpty) {
          final itemsToApply = <SyncPayload<Syncable>>[];

          for (final remoteItem in batchResult.items) {
            // Get local version for conflict check
            final localItems = await handler.getLocal();
            final localMatch = localItems
                .where((l) => l.data.syncId == remoteItem.data.syncId)
                .toList();

            if (localMatch.isEmpty) {
              // No local item, apply remote
              itemsToApply.add(remoteItem);
            } else {
              // Resolve conflict
              final resolution = ConflictResolver.resolve(
                local: localMatch.first.data,
                remote: remoteItem.data,
                strategy: conflictStrategy,
              );

              if (resolution.applyRemote) {
                itemsToApply.add(remoteItem);
              }
            }
          }

          if (itemsToApply.isNotEmpty) {
            final applyResult = await handler.applyToLocal(itemsToApply);
            if (!applyResult.success) {
              throw SyncFailedException(
                'Failed to apply batch for feature: $featureKey. '
                'Errors: ${applyResult.errors.map((e) => e.message).join(', ')}',
              );
            }
          }
        }

        // Update cursor
        if (batchResult.nextCursor != null) {
          await metaRepo.updateLastBackgroundSyncedCursor(
              featureKey, batchResult.nextCursor!);
          cursor = batchResult.nextCursor!;
        }

        // Check if more pages exist
        if (batchResult.nextCursor == null) {
          break;
        }
      }

      _emitEvent(IncrementalSyncCompletedEvent(featureKey: featureKey));
    } catch (e) {
      _emitEvent(
        IncrementalSyncFailedEvent(featureKey: featureKey, error: e.toString()),
      );
    } finally {
      _activeSync--;
      _processPending();
    }
  }

  /// Sort pending queue by priority (highest first)
  void _sortByPriority() {
    _pendingQueue.sort((a, b) {
      final priorityA = _handlerPriorities[a] ?? 0;
      final priorityB = _handlerPriorities[b] ?? 0;
      return priorityB.compareTo(priorityA); // Higher priority first
    });
  }

  void _emitEvent(SyncEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void dispose() {
    _disposed = true;
    _eventController.close();
  }
}
