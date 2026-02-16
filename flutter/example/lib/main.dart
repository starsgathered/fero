import 'dart:async';
import 'package:fero_sync/core/apply_result.dart';
import 'package:fero_sync/core/initial_sync_handler.dart';
import 'package:fero_sync/core/sync_batch_result.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';
import 'package:fero_sync/core/sync_payload.dart';
import 'package:fero_sync/core/syncable.dart';
import 'package:fero_sync/fero_sync.dart';

/// ----------------------------
/// 1. Models (Your Data)
/// ----------------------------

class Contact implements Syncable {
  final String id;
  final String name;

  @override
  final int version;

  @override
  String get syncId => id;

  Contact({required this.id, required this.name, required this.version});
}

class Task implements Syncable {
  final String id;
  final String title;

  @override
  final int version;

  @override
  String get syncId => id;

  Task({required this.id, required this.title, required this.version});
}

/// ----------------------------
/// 2. Sync Handlers
/// ----------------------------

class ContactsSyncHandler extends InitialSyncHandler {
  final List<Contact> _localContacts = [
    Contact(id: '1', name: 'Alice', version: 1),
  ];

  @override
  Future<SyncBatchResult> getRemote({String? cursor, int? batchSize}) async {
    // Simulating remote API
    final remoteContacts = [
      Contact(id: '1', name: 'Alice Johnson', version: 2),
      Contact(id: '2', name: 'Bob', version: 1),
    ];
    return SyncBatchResult(
      items: remoteContacts.map((c) => SyncPayload<Syncable>(data: c)).toList(),
      nextCursor: null,
    );
  }

  @override
  Future<ApplyResult> applyToLocal(
      List<SyncPayload<Syncable>> remoteStates) async {
    for (final payload in remoteStates) {
      final contact = payload.data as Contact;
      final index = _localContacts.indexWhere((c) => c.id == contact.id);
      if (index >= 0) {
        _localContacts[index] = contact;
      } else {
        _localContacts.add(contact);
      }
    }
    return ApplyResult.success();
  }
}

/// ----------------------------
/// 3. Main - Putting it all together
/// ----------------------------

Future<void> main() async {
  print('🚀 Setting up FeroSync...');

  final feroSync = await FeroSync.create(
    initialSyncHandlers: {
      'contacts': ContactsSyncHandler(),
    },
    metadataRepo: InMemorySyncMetaDataRepo(),
  );

  // Listen to status updates
  feroSync.statusStream.listen((status) {
    print('📡 Sync Status Update: $status');
  });

  // Start initial sync
  print('▶ Running initial sync for all features...');
  await feroSync.run();

  print('✅ All syncs completed!');
}
