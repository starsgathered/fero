import 'package:fero_sync/initial_sync/initial_sync_status.dart';

/// Public interface for the initial sync service.
abstract class InitialSyncService {
  InitialSyncStatus get status;
  Stream<InitialSyncStatus> get statusStream;

  Future<Map<String, bool>> areSyncRequired(
    Map<String, int> featureVersions,
  );

  Future<void> runInitialSync(Map<String, int> featureVersions);

  void cancel();
  void dispose();
}
