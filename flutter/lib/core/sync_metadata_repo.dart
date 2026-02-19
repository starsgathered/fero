import 'package:fero_sync/core/models/sync_checkpoint.dart';

/// Sync metadata repository
///
/// Responsible for storing feature-specific sync metadata such as the
/// last sync checkpoint. Implementations may use an on-disk store, database,
/// or an in-memory map (useful for tests).
///
/// Follows Dependency Inversion Principle (DIP) - high-level sync logic
/// depends on this abstraction, not concrete storage implementations.
abstract class SyncMetaDataRepo {
  /// Returns the last checkpoint from the initial sync process for [featureKey].
  Future<SyncCheckpoint?> getInitialSyncCheckpoint(String featureKey);

  /// Updates the last checkpoint used by the initial sync process for [featureKey].
  /// This is kept separate from the background sync checkpoint to avoid conflicts.
  Future<void> updateInitialSyncCheckpoint(
    String featureKey,
    SyncCheckpoint? checkpoint,
  );

  /// Returns whether the initial (critical) sync has been completed for [featureKey].
  /// If `true`, initial sync may be skipped for that feature.
  Future<bool> isInitialSyncCompleted(String featureKey);

  /// Checks if all specified features have completed initial sync.
  /// More efficient than checking each feature individually.
  /// Returns `true` only if all features in [featureKeys] are completed.
  Future<bool> areAllInitialSyncsCompleted(List<String> featureKeys);

  /// Sets the initial sync completed flag for [featureKey].
  Future<void> setInitialSyncCompleted(String featureKey, bool completed);

  /// Returns the last checkpoint from a successful background sync for [featureKey].
  /// Used for resumable, incremental syncing.
  Future<SyncCheckpoint?> getBackgroundSyncCheckpoint(String featureKey);

  /// Updates the last checkpoint from a successful background sync for [featureKey].
  /// Stores (lastUpdatedAt, lastItemId) for deterministic pagination.
  Future<void> updateBackgroundSyncCheckpoint(
    String featureKey,
    SyncCheckpoint? checkpoint,
  );
}

/// Simple in-memory implementation useful for tests and examples.
/// Demonstrates the Repository pattern with clean separation of concerns.
class InMemorySyncMetaDataRepo implements SyncMetaDataRepo {
  final Map<String, SyncCheckpoint?> _initialCheckpoints = {};
  final Map<String, bool> _initialCompleted = {};
  final Map<String, SyncCheckpoint?> _backgroundCheckpoints = {};

  @override
  Future<SyncCheckpoint?> getInitialSyncCheckpoint(String featureKey) async {
    return _initialCheckpoints[featureKey];
  }

  @override
  Future<void> updateInitialSyncCheckpoint(
    String featureKey,
    SyncCheckpoint? checkpoint,
  ) async {
    _initialCheckpoints[featureKey] = checkpoint;
  }

  @override
  Future<bool> isInitialSyncCompleted(String featureKey) async {
    return _initialCompleted[featureKey] ?? false;
  }

  @override
  Future<bool> areAllInitialSyncsCompleted(List<String> featureKeys) async {
    if (featureKeys.isEmpty) return true;

    for (final key in featureKeys) {
      if (!(_initialCompleted[key] ?? false)) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> setInitialSyncCompleted(
      String featureKey, bool completed) async {
    _initialCompleted[featureKey] = completed;
  }

  @override
  Future<SyncCheckpoint?> getBackgroundSyncCheckpoint(String featureKey) async {
    return _backgroundCheckpoints[featureKey];
  }

  @override
  Future<void> updateBackgroundSyncCheckpoint(
    String featureKey,
    SyncCheckpoint? checkpoint,
  ) async {
    _backgroundCheckpoints[featureKey] = checkpoint;
  }
}
