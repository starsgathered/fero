import 'dart:async';

import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/exceptions.dart';
import 'package:fero_sync/core/sync_event.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/initial_sync/initial_sync_service.dart';
import 'package:fero_sync/initial_sync/initial_sync_status.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';

/// Event-driven initial sync manager.
/// Listens to [InitialSyncRequiredEvent] from Fero server and orchestrates sync.
/// Automatically handles log storage and conflict tracking.
class InitialSyncManager implements InitialSyncService {
  final Map<String, SyncHandler> _handlers;
  final BackoffStrategy _backoff;
  final int _maxRetries;
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
  final Map<String, InitialSyncStatus> _featureStatuses = {};

  InitialSyncManager({
    required Map<String, SyncHandler> handlers,
    BackoffStrategy? backoffStrategy,
    int maxRetries = 5,
    required this.batchSize,
    required this.maxBatchSize,
    required this.metaRepo,
  })  : _handlers = Map.unmodifiable(handlers),
        _backoff = backoffStrategy ??
            ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000),
        _maxRetries = maxRetries;

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
      final featuresToSync = _handlers.keys.toList();

      for (final featureKey in featuresToSync) {
        if (_isCancelled) {
          _setStatus(InitialSyncStatus.cancelled);
          throw OperationCancelledException('Initial sync cancelled');
        }

        await _performSync(featureKey);
      }

      _setStatus(InitialSyncStatus.completed);
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
      if (!_handlers.containsKey(event.featureKey)) {
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
      final handler = _handlers[featureKey];
      if (handler == null) {
        _featureStatuses[featureKey] = InitialSyncStatus.failed;
        throw HandlerNotFoundException(
          'No sync handler registered for feature: $featureKey',
        );
      }

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

      // Step 1: Get last cursor for initial sync (separate from incremental)
      String? cursor = await metaRepo.getLastInitialSyncCursor(featureKey);
      // Step 2: Fetch all pages from remote (efficient paginated fetch)
      while (true) {
        if (_isCancelled) {
          throw OperationCancelledException('Sync cancelled during pagination');
        }
        final batchResult = await _attemptWithPolicy(() async {
          if (_isCancelled) {
            throw OperationCancelledException(
                "Operation was cancelled before fetch");
          }
          return await handler.getRemote(cursor: cursor, batchSize: batchSize);
        });
        if (batchResult == null) {
          throw MaxRetriesExceededException(
            'Failed to fetch page for feature: $featureKey',
          );
        }
        if (_isCancelled) {
          throw OperationCancelledException('Sync cancelled after fetch');
        }

        // Step 3: Apply changes in bulk (efficient batch write)
        if (batchResult.items.isNotEmpty) {
          final applyResult = await handler.applyToLocal(batchResult.items);
          if (!applyResult.success) {
            throw SyncFailedException(
              'Failed to apply batch to local for feature: $featureKey. '
              'Errors: ${applyResult.errors.map((e) => e.message).join(', ')}',
            );
          }
        }

        // Step 4: Update cursor to continue from this batch
        if (batchResult.nextCursor != null) {
          await metaRepo.updateLastInitialSyncCursor(
              featureKey, batchResult.nextCursor!);
        }

        // Step 5: Check if there are more pages
        if (batchResult.nextCursor == null) {
          break; // No more pages, sync complete
        }
        cursor = batchResult.nextCursor;
      }

      _featureStatuses[featureKey] = InitialSyncStatus.completed;
      // Mark initial sync as completed and record last synced cursor.
      await metaRepo.setInitialSyncCompleted(featureKey, true);
      await metaRepo.updateLastInitialSyncCursor(featureKey, cursor);
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

  Future<T?> _attemptWithPolicy<T>(Future<T> Function() operation) async {
    int attempt = 0;

    while (!_isCancelled) {
      try {
        return await operation();
      } catch (_) {
        attempt++;
        if (attempt > _maxRetries) return null;
        final d = _backoff.nextDelay(attempt);
        if (d > Duration.zero) {
          await Future.any([
            Future.delayed(d),
            Future(() => _isCancelled
                ? throw OperationCancelledException("Operation was cancelled")
                : null)
          ]);
        }
      }
    }

    return null;
  }

  void _setStatus(InitialSyncStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  void _emitEvent(SyncEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }
}
