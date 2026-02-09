import 'dart:async';

/// Abstract repository for metadata synchronization
abstract class SyncMetadataRepository {
  /// Fetch the last sync timestamp for a given user and featureKey
  Future<DateTime?> getLastSyncTime({
    required String userId,
    required String featureKey,
  });

  /// Update the sync timestamp for a given user and featureKey
  Future<void> updateSyncTime({
    required String userId,
    required String featureKey,
    required DateTime syncTime,
  });

  /// Check if sync is required for a given user and featureKey
  Future<bool> isSyncRequired({
    required String userId,
    required String featureKey,
  });

  /// Optional: batch check for multiple featureKeys
  Future<Map<String, bool>> areSyncRequired({
    required String userId,
    required List<String> featureKeys,
  }) async {
    final results = <String, bool>{};
    for (var key in featureKeys) {
      results[key] = await isSyncRequired(userId: userId, featureKey: key);
    }
    return results;
  }
}

/// In-memory implementation of SyncMetadataRepository
class InMemorySyncMetadataRepository implements SyncMetadataRepository {
  final Map<String, Map<String, DateTime>> _store = {};

  @override
  Future<DateTime?> getLastSyncTime({
    required String userId,
    required String featureKey,
  }) async {
    return _store[userId]?[featureKey];
  }

  @override
  Future<void> updateSyncTime({
    required String userId,
    required String featureKey,
    required DateTime syncTime,
  }) async {
    _store.putIfAbsent(userId, () => {});
    _store[userId]![featureKey] = syncTime;
  }

  @override
  Future<bool> isSyncRequired({
    required String userId,
    required String featureKey,
  }) async {
    final lastSync = await getLastSyncTime(
      userId: userId,
      featureKey: featureKey,
    );
    if (lastSync == null) return true; // never synced
    final now = DateTime.now();
    return now.difference(lastSync) >
        Duration(hours: 1); // example: 1 hour threshold
  }

  @override
  Future<Map<String, bool>> areSyncRequired({
    required String userId,
    required List<String> featureKeys,
  }) async {
    final results = <String, bool>{};
    for (var key in featureKeys) {
      results[key] = await isSyncRequired(userId: userId, featureKey: key);
    }
    return results;
  }
}
