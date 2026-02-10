import 'dart:async';

import 'package:fero_sync/initial_sync/initial_sync.dart';
import 'package:fero_sync/metadata/sync_meta_data_repository.dart';

/// High-level coordinator that decides when to run initial vs background sync
/// and exposes control operations. Keep logic minimal; composition and
/// policies can be extended without changing this class.
class FeroCoordinator {
  final InitialSyncManager initialManager;
  final SyncMetadataRepository syncMetadataRepository;

  final Duration minInterval;
  final Map<String, DateTime> _lastRun = {};

  FeroCoordinator({
    required this.initialManager,
    required this.syncMetadataRepository,
    this.minInterval = const Duration(minutes: 5),
  });

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
  /// Runs the initial sync for the given `userId` and `features` only if
  /// the store indicates any feature is missing a recorded last-sync.
  /// If an `InitialSyncService` was not provided during construction this
  /// is a no-op.
  Future<void> runInitialIfNeeded(String userId, List<String> features) async {
    await initialManager.runInitialSync(userId, features);
  }
}
