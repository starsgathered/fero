import 'dart:async';

import 'package:fero_sync/background_sync/feature_sync_status.dart';
import 'package:fero_sync/initial_sync/enum/initial_sync_status.dart';
import 'package:fero_sync/policies/backoff.dart';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';
import 'package:fero_sync/background_sync/background_sync.dart';
import 'package:fero_sync/background_sync/feature_sync_config.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';
import 'package:flutter/foundation.dart';

/// --- FeroSync ---
/// Main orchestrator for syncing multiple features using handlers.
/// Handles:
/// - Initial sync
/// - Background/incremental sync (auto-starts after initial sync)
/// - Conflict resolution
/// - Retry/backoff strategies
/// - Event broadcasting for UI or logging
class FeroSync {
  /// Manager for performing the initial sync of all features
  final InitialSyncManager _initialManager;

  /// Manager for performing background/incremental sync
  final BackgroundSyncManager? _backgroundManager;

  /// Repository for storing sync metadata (e.g. last cursors)
  final SyncMetaDataRepo metadataRepo;

  /// Map of feature keys to their respective configs
  final Map<String, FeatureInitialSyncConfig> initialSyncConfigs;

  /// Map of feature keys to their background sync configs
  final Map<String, FeatureSyncConfig>? backgroundSyncConfigs;

  /// Strategy to handle retries/backoff for failed sync attempts
  final RetryPolicy retryPolicy;

  /// Strategy to resolve conflicts between local and remote data
  final ConflictResolutionStrategy conflictStrategy;

  /// Number of items to fetch per remote batch during initial sync
  final int batchSize;

  /// Maximum allowed batch size in production (cap)
  final int maxBatchSize;

  ValueNotifier<InitialSyncStatus> get initialSyncNotifier =>
      _initialManager.statusNotifier;

  /// Stream to observe background sync events
  ValueNotifier<SyncProcessStatus>? backgroundSyncNotifier(String featureKey) {
    return _backgroundManager?.getFeatureStatus(featureKey).statusNotifier;
  }

  /// Optional subscription to listen to events internally
  bool _autoBackgroundSyncSetup = false; // Track if listener is already set up
  VoidCallback? _statusListener;

  /// Private constructor to enforce usage of the async factory `create`
  FeroSync._({
    required this.initialSyncConfigs,
    required this.backgroundSyncConfigs,
    required this.retryPolicy,
    required this.conflictStrategy,
    required this.batchSize,
    required this.maxBatchSize,
    required this.metadataRepo,
    required InitialSyncManager initialManager,
    BackgroundSyncManager? backgroundManager,
  })  : _initialManager = initialManager,
        _backgroundManager = backgroundManager;

  /// Factory method to create an instance of FeroSync asynchronously
  /// Sets default backoff and conflict resolution strategies if none are provided
  /// Automatically starts background sync after initial sync completes
  static Future<FeroSync> create({
    required Map<String, FeatureInitialSyncConfig> initialSyncConfigs,
    Map<String, FeatureSyncConfig>? backgroundSyncConfigs,
    required SyncMetaDataRepo metadataRepo,
    RetryPolicy? retryPolicy,
    int? batchSize,
    int? maxBatchSize,
    int? maxConcurrent,
  }) async {
    final retryPolicyValue = retryPolicy ??
        RetryPolicy(
            backoff:
                ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000));

    final strategy = ConflictResolutionStrategy.highestVersionWins;

    final int bs = batchSize ?? 50;
    final int mbs = maxBatchSize ?? 500;

    // If caller provided an InitialSyncManager, use it; otherwise create a default one
    final InitialSyncManager initManager = InitialSyncManager(
      featureConfigs: initialSyncConfigs,
      retryPolicy: retryPolicyValue,
      batchSize: bs,
      maxBatchSize: mbs,
      metaRepo: metadataRepo,
    );

    // Create BackgroundSyncManager if configs are provided
    BackgroundSyncManager? bgManager;
    if (backgroundSyncConfigs != null) {
      bgManager = BackgroundSyncManager(
        featureConfigs: backgroundSyncConfigs,
        metaRepo: metadataRepo,
        maxConcurrent: maxConcurrent ?? 2,
        batchSize: bs,
      );
    }

    final instance = FeroSync._(
      initialSyncConfigs: initialSyncConfigs,
      backgroundSyncConfigs: backgroundSyncConfigs,
      retryPolicy: retryPolicyValue,
      conflictStrategy: strategy,
      batchSize: bs,
      maxBatchSize: mbs,
      metadataRepo: metadataRepo,
      initialManager: initManager,
      backgroundManager: bgManager,
    );

    // Auto-start background sync when initial sync completes (set up once)
    if (bgManager != null) {
      instance._setupAutoBackgroundSync();
    }

    return instance;
  }

  /// Setup automatic background sync trigger after initial sync completes
  void _setupAutoBackgroundSync() {
    // Only set up listener once to avoid multiple triggers
    if (_autoBackgroundSyncSetup) return;

    _autoBackgroundSyncSetup = true;
    _statusListener = () {
      if (_initialManager.statusNotifier.value == InitialSyncStatus.completed) {
        _backgroundManager?.syncAll();
      }
    };

    _initialManager.statusNotifier.addListener(_statusListener!);
  }

  /// Start listening to sync events
  Future<void> startSync() async {
    await _initialManager.run();
  }

  /// Manually trigger background sync for all features
  void syncAll() {
    _backgroundManager?.syncAll();
  }

  /// Cancel ongoing operations safely
  void cancel() {
    _initialManager.cancel();
  }

  /// Dispose resources when the FeroSync instance is no longer needed
  void dispose() {
    if (_statusListener != null) {
      _initialManager.statusNotifier.removeListener(_statusListener!);
      _statusListener = null;
    }

    _initialManager.dispose();
    _backgroundManager?.dispose();
  }
}
