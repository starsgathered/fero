import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/core/sync_item.dart';
import 'package:fero_sync/core/sync_result.dart';
import 'package:fero_sync/fero_sync.dart';
import 'package:fero_sync/queue/sync_queue_repository.dart';

/// Example feature handlers
class ContactsSyncHandler implements SyncHandler {
  @override
  Future<SyncResult> handle(SyncItem item) async {
    print('Syncing contacts for ${item.featureKey}...');
    await Future.delayed(Duration(seconds: 1)); // simulate network call
    return SyncResult.success();
  }
}

class MessagesSyncHandler implements SyncHandler {
  @override
  Future<SyncResult> handle(SyncItem item) async {
    print('Syncing messages for ${item.featureKey}...');
    await Future.delayed(Duration(seconds: 1));
    return SyncResult.success();
  }
}

Future<void> main() async {
  // --- Metadata Repository ---
  final metadataRepo = InMemorySyncQueueRepository();

  // --- Handlers ---
  final handlers = <String, SyncHandler>{
    'contacts': ContactsSyncHandler(),
    'messages': MessagesSyncHandler(),
  };

  // --- Backoff Strategy ---
  final backoffStrategy = FixedBackoffStrategy(baseMillis: 500);

  // --- Sync Coordinator (creates InitialSyncManager internally) ---
  final coordinator = FeroSync(
    handlers: handlers,
    syncMetadataRepository: metadataRepo,
    backoffStrategy: backoffStrategy,
    minInterval: Duration(seconds: 5),
  );

  // --- Listen to Initial Sync Status ---
  coordinator.initialManager.statusStream.listen((status) {
    print('Initial Sync Status: $status');
  });

  // --- Run full sync flow ---
  await coordinator.runInitialIfNeeded(['contacts', 'messages']);
}
