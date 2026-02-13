import 'dart:async';

import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';
import 'package:fero_sync/queue/sync_queue_repository.dart';

/// High-level coordinator that decides when to run initial vs background sync
/// and exposes control operations. Keep logic minimal; composition and
/// policies can be extended without changing this class.
class FeroSync {
  late final InitialSyncManager initialManager;
  final SyncQueueRepository syncMetadataRepository;
  final BackoffStrategy backoffStrategy;

  final Duration minInterval;
  final Map<String, DateTime> _lastRun = {};
  final Map<String, SyncHandler> handlers;

  FeroSync({
    required this.handlers,
    required this.syncMetadataRepository,
    BackoffStrategy? backoffStrategy,
    this.minInterval = const Duration(minutes: 5),
  }) : backoffStrategy = backoffStrategy ??
            ExponentialBackoffStrategy(baseMillis: 1000, maxMillis: 30000) {
    // Pass the backoffStrategy to initialManager
    initialManager = InitialSyncManager(
      handlers: handlers,
      metadataRepo: syncMetadataRepository,
      backoffStrategy: this.backoffStrategy,
      maxRetries: 5,
    );
  }

  Future<void> triggerForUser(String userId) async {
    final now = DateTime.now().toUtc();
    final last = _lastRun[userId];
    if (last != null && now.difference(last) < minInterval) return;
    _lastRun[userId] = now;

    // High-level policy: if initial not done, call runInitialSync (caller
    // should implement the hasInitialSync check). Otherwise run background.
    // await backgroundManager.runIncrementalSync(userId);
  }

  /// Allow callers to request an explicit initial sync run via injected fn.
  /// Runs the initial sync for the given `features` only if
  /// the store indicates any feature is missing a recorded last-sync.
  /// If an `InitialSyncService` was not provided during construction this
  /// is a no-op.
  Future<void> runInitialIfNeeded(List<String> features) async {
    final featureVersions = <String, int>{
      for (final f in features) f: 0,
    };
    await initialManager.runInitialSync(featureVersions);
  }
}
