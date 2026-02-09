import 'package:fero/initial_sync/initial_sync_status.dart';

/// Public interface for the initial sync service.
abstract class InitialSyncService {
  InitialSyncStatus get status;
  Stream<InitialSyncStatus> get statusStream;

  Future<Map<String, bool>> areSyncRequired(
    String userId,
    List<String> featureKeys,
  );

  Future<void> runInitialSync(String userId, List<String> featureKeys);

  void cancel();
  void dispose();
}
