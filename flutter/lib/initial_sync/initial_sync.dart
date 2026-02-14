import 'dart:async';

import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/core/exceptions.dart';
import 'package:fero_sync/core/sync_event.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/core/sync_log_repository.dart';
import 'package:fero_sync/initial_sync/initial_sync_service.dart';
import 'package:fero_sync/initial_sync/initial_sync_status.dart';

/// Event-driven initial sync manager.
/// Listens to [InitialSyncRequiredEvent] from Fero server and orchestrates sync.
/// Automatically handles log storage and conflict tracking.
class InitialSyncManager implements InitialSyncService {
  final Map<String, SyncHandler> _handlers;
  final SyncLogRepository _logRepository;
  final BackoffStrategy _backoff;
  final int _maxRetries;
  final ConflictResolutionStrategy _conflictStrategy;

  final StreamController<InitialSyncStatus> _statusController =
      StreamController.broadcast();
  final StreamController<SyncEvent> _eventController =
      StreamController.broadcast();

  InitialSyncStatus _status = InitialSyncStatus.notStarted;

  bool _isRunning = false;
  bool _isCancelled = false;
  final Set<String> _registeredFeatures = {};

  InitialSyncManager({
    required Map<String, SyncHandler> handlers,
    SyncLogRepository? logRepository,
    BackoffStrategy? backoffStrategy,
    ConflictResolutionStrategy conflictStrategy = ConflictResolutionStrategy.highestVersionWins,
    int maxRetries = 5,
  })  : _handlers = Map.unmodifiable(handlers),
        _logRepository = logRepository ?? InMemorySyncLogRepository(),
        _backoff = backoffStrategy ??
            ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000),
        _conflictStrategy = conflictStrategy,
        _maxRetries = maxRetries;

  @override
  InitialSyncStatus get status => _status;

  @override
  Stream<InitialSyncStatus> get statusStream => _statusController.stream;

  @override
  Stream<SyncEvent> get eventStream => _eventController.stream;

  @override
  void registerFeature(String featureKey) {
    _registeredFeatures.add(featureKey);
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
      if (!_registeredFeatures.contains(event.featureKey)) {
        return; // Feature not registered, skip
      }

      try {
        await _performSync(event.featureKey);
      } catch (e) {
        // Error logged via status stream
      }
    }
  }

  /// Perform initial sync for a single feature.
  Future<void> _performSync(String featureKey) async {
    if (_isRunning) {
      throw SyncAlreadyRunningException('Initial sync already running');
    }

    _isRunning = true;
    _isCancelled = false;
    _setStatus(InitialSyncStatus.running);
    _emitEvent(InitialSyncStartedEvent(featureKey: featureKey));

    try {
      final handler = _handlers[featureKey];
      if (handler == null) {
        _setStatus(InitialSyncStatus.failed);
        throw HandlerNotFoundException(
          'No sync handler registered for feature: $featureKey',
        );
      }

      final synced = await _attemptWithPolicy(() async {
        // Step 1: Get version information from both sides
        final localVersion = await handler.getLocalVersion();
        final remoteVersion = await handler.getRemoteVersion();

        // Step 2: Check if sync is actually needed
        if (!localVersion.isNewerThan(remoteVersion) &&
            !remoteVersion.isNewerThan(localVersion)) {
          // Versions are equal, no sync needed
          return;
        }

        // Step 3: Get log events from SDK's internal repository
        final localEvents =
            await _logRepository.getLocalLogsSince(featureKey, localVersion.version);
        final remoteEvents = await _logRepository.getRemoteLogsSince(
            featureKey, localVersion.version);

        // Step 4: Apply conflict resolution strategy automatically
        final mergeResult = ConflictResolver.resolve(
          localEvents: localEvents,
          remoteEvents: remoteEvents,
          strategy: _conflictStrategy,
        );

        // Step 5: Emit conflict event if conflicts detected
        if (mergeResult.hasConflicts && 
            (mergeResult.toApplyLocally.isNotEmpty || 
             mergeResult.toApplyRemotely.isNotEmpty)) {
          final conflictingIds = <String>{};
          for (final event in mergeResult.toApplyLocally) {
            conflictingIds.add(event.id);
          }
          for (final event in mergeResult.toApplyRemotely) {
            conflictingIds.add(event.id);
          }

          final conflict = SyncConflict(
            featureKey: featureKey,
            conflictingIds: conflictingIds.toList(),
            resolutionStrategy: _getResolutionStrategy(mergeResult),
            localChangeCount: localEvents.length,
            remoteChangeCount: remoteEvents.length,
          );

          // Record conflict for analytics
          await _logRepository.recordConflict(featureKey, conflict);

          // Emit conflict event
          _emitEvent(SyncConflictDetectedEvent(
            featureKey: featureKey,
            conflictingIds: conflictingIds.toList(),
            localChangesCount: localEvents.length,
            remoteChangesCount: remoteEvents.length,
            resolutionStrategy: _getResolutionStrategy(mergeResult),
          ));
        }

        // Step 6: Apply remote changes to local database
        if (mergeResult.toApplyLocally.isNotEmpty) {
          await handler.applyToLocalDatabase(mergeResult.toApplyLocally);
          // Log the applied changes
          for (final event in mergeResult.toApplyLocally) {
            await _logRepository.addLocalLog(featureKey, event);
          }
        }

        // Step 7: Apply local changes to remote database
        if (mergeResult.toApplyRemotely.isNotEmpty) {
          await handler.applyToRemoteDatabase(mergeResult.toApplyRemotely);
          // Log the applied changes
          for (final event in mergeResult.toApplyRemotely) {
            await _logRepository.addRemoteLog(featureKey, event);
          }
        }

        // Step 8: Update local version marker to match remote
        await handler.updateLocalSyncVersion(remoteVersion.version);

        // Step 9: Clear old logs (after version update)
        await _logRepository.clearLogsBefore(featureKey, remoteVersion.version);
      });

      if (!synced) {
        _setStatus(InitialSyncStatus.failed);
        final error = MaxRetriesExceededException(
          'Initial sync failed for feature: $featureKey',
        );
        _emitEvent(InitialSyncFailedEvent(
          featureKey: featureKey,
          error: error,
        ));
        throw error;
      }

      _setStatus(InitialSyncStatus.completed);
      _emitEvent(InitialSyncCompletedEvent(featureKey: featureKey));
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

  /// Determine resolution strategy for logging purposes.
  String _getResolutionStrategy(MergeResult result) {
    if (result.toApplyLocally.isEmpty && result.toApplyRemotely.isNotEmpty) {
      return 'local-wins';
    } else if (result.toApplyLocally.isNotEmpty && 
               result.toApplyRemotely.isEmpty) {
      return 'remote-wins';
    } else if (result.toApplyLocally.isNotEmpty && 
               result.toApplyRemotely.isNotEmpty) {
      return 'merge-both';
    }
    return 'no-change';
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

  void _emitEvent(SyncEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }
}
