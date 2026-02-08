import 'package:fero/backoff.dart';
import 'package:fero/initial_sync.dart';
import 'package:fero/sync_meta_data_repository.dart';

import 'sync_handler.dart';
import 'sync_item.dart';
import 'sync_result.dart';

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

void main() async {
  final repo = InMemorySyncMetadataRepository();
  final BackoffStrategy backoffStrategy = FixedBackoffStrategy(1);
  final handlers = <String, SyncHandler>{
    'contacts': ContactsSyncHandler(),
    'messages': MessagesSyncHandler(),
  };

  final manager = InitialSyncManager(
    syncMetadataRepository: repo,
    handlers: handlers,
    backoffStrategy: backoffStrategy,
  );

  await manager.runSync('user_123');
}
