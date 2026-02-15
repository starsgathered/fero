/// Sync metadata repository
///
/// Responsible for storing feature-specific sync metadata such as the
/// last sync cursor. Implementations may use an on-disk store, database,
/// or an in-memory map (useful for tests).
abstract class SyncMetaDataRepo {
  /// Returns the last saved cursor specifically used by the initial sync
  /// process for [featureKey], or `null` if none.
  Future<String?> getLastInitialSyncCursor(String featureKey);

  /// Updates the last saved cursor used by the initial sync process for
  /// [featureKey]. This is kept separate from the incremental/background
  /// sync cursor to avoid conflicts between initial one-time downloads and
  /// ongoing incremental syncing.
  Future<void> updateLastInitialSyncCursor(String featureKey, String? cursor);

  /// Returns whether the initial (critical) sync has been completed for [featureKey].
  /// If `true`, initial sync may be skipped for that feature.
  Future<bool> isInitialSyncCompleted(String featureKey);

  /// Sets the initial sync completed flag for [featureKey].
  Future<void> setInitialSyncCompleted(String featureKey, bool completed);

  /// Returns the last time a successful sync (initial or incremental) ran for [featureKey].
  /// Returns the last saved cursor representing the state of the last
  /// successful sync (initial or incremental) for [featureKey], or `null`.
  Future<String?> getLastBackgroundSyncedCursor(String featureKey);

  /// Updates the last saved cursor representing the state of the last
  /// successful sync (initial or incremental) for [featureKey].
  /// `cursor` may be `null` if there is no cursor to record.
  Future<void> updateLastBackgroundSyncedCursor(
      String featureKey, String? cursor);
}

/// Simple in-memory implementation useful for tests and examples.
class InMemorySyncMetaDataRepo implements SyncMetaDataRepo {
  final Map<String, String?> _initialStore = {};
  final Map<String, bool> _initialCompleted = {};
  final Map<String, String?> _backgroundSyncedCursor = {};

  @override
  Future<String?> getLastInitialSyncCursor(String featureKey) async {
    return _initialStore[featureKey];
  }

  @override
  Future<void> updateLastInitialSyncCursor(
      String featureKey, String? cursor) async {
    _initialStore[featureKey] = cursor;
  }

  @override
  Future<bool> isInitialSyncCompleted(String featureKey) async {
    return _initialCompleted[featureKey] ?? false;
  }

  @override
  Future<void> setInitialSyncCompleted(
      String featureKey, bool completed) async {
    _initialCompleted[featureKey] = completed;
  }

  @override
  Future<String?> getLastBackgroundSyncedCursor(String featureKey) async {
    return _backgroundSyncedCursor[featureKey];
  }

  @override
  Future<void> updateLastBackgroundSyncedCursor(
      String featureKey, String? cursor) async {
    _backgroundSyncedCursor[featureKey] = cursor;
  }
}
