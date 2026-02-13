import 'dart:async';

import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/exceptions.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/core/sync_item.dart';
import 'package:fero_sync/initial_sync/initial_sync_service.dart';
import 'package:fero_sync/initial_sync/initial_sync_status.dart';
import 'package:fero_sync/queue/sync_queue_repository.dart';

class InitialSyncManager implements InitialSyncService {
  final SyncQueueRepository _metadataRepo;
  final Map<String, SyncHandler> _handlers;
  final BackoffStrategy _backoff;
  final int _maxRetries;

  final StreamController<InitialSyncStatus> _statusController =
      StreamController.broadcast();
  InitialSyncStatus _status = InitialSyncStatus.notStarted;

  bool _isRunning = false;
  bool _isCancelled = false;

  InitialSyncManager({
    required Map<String, SyncHandler> handlers,
    BackoffStrategy? backoffStrategy,
    int maxRetries = 5,
    required SyncQueueRepository metadataRepo,
  })  : _metadataRepo = metadataRepo,
        _handlers = Map.unmodifiable(handlers),
        _backoff = backoffStrategy ??
            ExponentialBackoffStrategy(baseMillis: 1, maxMillis: 30),
        _maxRetries = maxRetries;

  @override
  InitialSyncStatus get status => _status;

  @override
  Stream<InitialSyncStatus> get statusStream => _statusController.stream;

  @override
  Future<Map<String, bool>> areSyncRequired(
    Map<String, int> featureVersions,
  ) async {
    final results = <String, bool>{};
    for (final entry in featureVersions.entries) {
      final tasks = await _metadataRepo.getTasksByFeature(entry.key);
      results[entry.key] = tasks.isNotEmpty;
    }
    return results;
  }

  @override
  Future<void> runInitialSync(Map<String, int> featureVersions) async {
    if (_isRunning) {
      throw SyncAlreadyRunningException('Initial sync already running');
    }
    _isRunning = true;
    _isCancelled = false;
    _setStatus(InitialSyncStatus.running);

    try {
      final needsSync = await areSyncRequired(featureVersions);

      // skip if no features need syncing
      if (featureVersions.keys.every((key) => !needsSync[key]!)) {
        _setStatus(InitialSyncStatus.completed);
        return;
      }

      for (final key in featureVersions.keys) {
        if (_isCancelled) {
          _setStatus(InitialSyncStatus.cancelled);
          return;
        }

        final handler = _handlers[key];
        if (handler == null) {
          _setStatus(InitialSyncStatus.failed);
          throw HandlerNotFoundException(
            'No sync handler registered for feature: $key',
          );
        }

        final ok = await _attemptWithPolicy(() async {
          final item = SyncItem(featureKey: key);
          final result = await handler.handle(item);
          if (!result.success) {
            throw result.error ??
                InitialSyncFailedException(
                  'Handler reported failure for feature: $key',
                );
          }
        });

        if (!ok) {
          _setStatus(InitialSyncStatus.failed);
          throw MaxRetriesExceededException(
            'Initial sync failed for feature: $key',
          );
        }

        try {
          await _metadataRepo.removeTasksByFeature(key);
        } catch (_) {
          // best-effort persistence
        }
      }

      _setStatus(InitialSyncStatus.completed);
    } catch (e) {
      final st = StackTrace.current;
      if (_status != InitialSyncStatus.cancelled) {
        _setStatus(InitialSyncStatus.failed);
        if (!_statusController.isClosed) _statusController.addError(e, st);
      }
      rethrow;
    } finally {
      _isRunning = false;
    }
  }

  @override
  void cancel() {
    _isCancelled = true;
  }

  @override
  void dispose() {
    _statusController.close();
  }

  Future<bool> _attemptWithPolicy(Future<void> Function() operation) async {
    int attempt = 0;

    while (!_isCancelled) {
      try {
        await operation();
        return true;
      } catch (_) {
        attempt++;
        if (attempt > _maxRetries) return false;

        final d = _backoff.nextDelay(attempt);
        if (d > Duration.zero) await Future.delayed(d);
      }
    }

    return false;
  }

  void _setStatus(InitialSyncStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }
}
