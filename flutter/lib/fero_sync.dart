import 'dart:async';

import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/core/sync_event.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/core/sync_log_repository.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';

/// High-level SDK that manages initial sync as an event-driven process.
/// The Fero server emits events when sync is needed; this class listens
/// and orchestrates the sync for registered features.
/// 
/// Automatically handles:
/// - Log storage and retrieval (persisted to SQLite by default)
/// - Conflict detection and resolution (default: highest-version-wins)
/// - Version tracking
/// - Retry logic with backoff
class FeroSync {
  late final InitialSyncManager initialManager;
  final Map<String, SyncHandler> handlers;
  final SyncLogRepository logRepository;
  final BackoffStrategy backoffStrategy;
  final ConflictResolutionStrategy conflictStrategy;
  final Set<String> _registeredFeatures = {};
  StreamSubscription? _eventSubscription;

  FeroSync._({
    required this.handlers,
    required this.logRepository,
    required this.backoffStrategy,
    required this.conflictStrategy,
  }) {
    initialManager = InitialSyncManager(
      handlers: handlers,
      logRepository: logRepository,
      backoffStrategy: backoffStrategy,
      conflictStrategy: conflictStrategy,
      maxRetries: 5,
    );
  }

  /// Create a new FeroSync instance with SQLite-backed log storage.
  /// The logRepository defaults to DbSyncLogRepository for persistent storage.
  /// Use this factory method for production apps.
  static Future<FeroSync> create({
    required Map<String, SyncHandler> handlers,
    SyncLogRepository? logRepository,
    BackoffStrategy? backoffStrategy,
    ConflictResolutionStrategy? conflictStrategy,
  }) async {
    final repo = logRepository ?? await DbSyncLogRepository.open();
    final backoff = backoffStrategy ?? 
        ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000);
    final strategy = conflictStrategy ?? ConflictResolutionStrategy.highestVersionWins;

    return FeroSync._(
      handlers: handlers,
      logRepository: repo,
      backoffStrategy: backoff,
      conflictStrategy: strategy,
    );
  }

  /// Create a new FeroSync instance with in-memory log storage (for testing).
  /// Use this constructor for tests or when you don't need persistence.
  FeroSync.forTesting({
    required Map<String, SyncHandler> handlers,
    SyncLogRepository? logRepository,
    BackoffStrategy? backoffStrategy,
    ConflictResolutionStrategy? conflictStrategy,
  }) : this._(
    handlers: handlers,
    logRepository: logRepository ?? InMemorySyncLogRepository(),
    backoffStrategy: backoffStrategy ?? 
        ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000),
    conflictStrategy: conflictStrategy ?? ConflictResolutionStrategy.highestVersionWins,
  );

  /// Register a feature for automatic sync when events are received.
  void registerFeature(String featureKey) {
    _registeredFeatures.add(featureKey);
    initialManager.registerFeature(featureKey);
  }

  /// Start listening to sync events from Fero's central server.
  /// Call this once during app initialization.
  Future<void> startSync() async {
    await initialManager.startListeningToEvents();
  }

  /// Emit a sync event (useful for testing or manual triggering).
  void emitSyncEvent(SyncEvent event) {
    initialManager.emitEvent(event);
  }

  /// Convenience method to trigger initial sync for a feature.
  void triggerInitialSync(String featureKey) {
    emitSyncEvent(InitialSyncRequiredEvent(featureKey: featureKey));
  }

  /// Get the status stream to listen for sync status changes.
  Stream<dynamic> get statusStream => initialManager.statusStream;

  /// Get the event stream to listen for sync events.
  Stream<SyncEvent> get eventStream => initialManager.eventStream;

  /// Get conflict history for a feature (for analytics).
  Future<List<SyncConflict>> getConflictHistory(String featureKey) async {
    return logRepository.getConflictHistory(featureKey);
  }

  /// Cancel ongoing sync operation.
  void cancel() {
    initialManager.cancel();
  }

  /// Cleanup resources.
  void dispose() {
    _eventSubscription?.cancel();
    initialManager.dispose();
  }
}
