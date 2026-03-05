import 'package:fero_sync/core/models/sync_checkpoint.dart';

/// Sync metadata repository
///
/// Responsible for storing feature-specific sync metadata such as the
/// last sync checkpoint. Implements single checkpoint store for both
/// initial snapshot and incremental/background sync.
///
abstract class SyncMetaDataRepo {
  /// Returns the last checkpoint for [featureKey], which may be
  /// from the initial snapshot or incremental sync.
  Future<SyncCheckpoint?> getCheckpoint(String featureKey);

  /// Updates the checkpoint for [featureKey].
  /// Use `snapshotDone` in [checkpoint] to indicate if initial sync is complete.
  Future<void> updateCheckpoint(String featureKey, SyncCheckpoint checkpoint);

  /// Returns whether the initial (critical) sync has been completed for [featureKey].
  /// Internally checks `snapshotDone` in the checkpoint.
  Future<bool> isInitialSyncCompleted(String featureKey);

  /// Checks if all specified features have completed initial sync.
  /// Returns `true` only if all features in [featureKeys] are completed.
  Future<bool> areAllInitialSyncsCompleted(List<String> featureKeys);

  /// Sets the initial sync completed flag for [featureKey].
  /// Internally updates the `snapshotDone` field in the checkpoint.
  Future<void> setInitialSyncCompleted(String featureKey, bool completed);
}
