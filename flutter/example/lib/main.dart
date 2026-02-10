import 'package:fero_sync/coordinator/sync_coordinator.dart';
import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/core/sync_item.dart';
import 'package:fero_sync/core/sync_result.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';
import 'package:fero_sync/metadata/sync_meta_data_repository.dart';

/// Example feature handlers
class ContactsSyncHandler implements SyncHandler {
  @override
  Future<SyncResult> handle(SyncItem item) async {
    print('Syncing contacts for ${item.userId}...');
    await Future.delayed(Duration(seconds: 1)); // simulate network call
    return SyncResult.success();
  }
}

class MessagesSyncHandler implements SyncHandler {
  @override
  Future<SyncResult> handle(SyncItem item) async {
    print('Syncing messages for ${item.userId}...');
    await Future.delayed(Duration(seconds: 1));
    return SyncResult.success();
  }
}

Future<void> main() async {
  // --- Metadata Repository ---
  final metadataRepo = InMemorySyncMetadataRepository();

  // --- Handlers ---
  final handlers = <String, SyncHandler>{
    'contacts': ContactsSyncHandler(),
    'messages': MessagesSyncHandler(),
  };

  // --- Backoff Strategy ---
  final backoffStrategy = FixedBackoffStrategy(baseMillis: 500);

  // --- Initial Sync Manager ---
  final initialSync = InitialSyncManager(
    metadataRepo: metadataRepo,
    handlers: handlers,
    backoffStrategy: backoffStrategy,
  );

  // --- Sync Coordinator Manager ---
  final coordinator = FeroCoordinator(
    initialManager: initialSync,
    syncMetadataRepository: metadataRepo,
  );

  // --- Run full sync flow ---
  await coordinator.runInitialIfNeeded('user_123', ['contacts', 'messages']);

  // Listen to initial sync status
  initialSync.statusStream.listen((status) {
    print('Initial Sync Status: $status');
  });
}
