import 'dart:async';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/fero_sync.dart';
import 'package:fero_sync/initial_sync/initial_sync_status.dart';

/// ----------------------------
/// 1. Model
/// ----------------------------

class Contact implements Syncable {
  final String id;
  final String name;

  @override
  final int version;

  @override
  String get syncId => id;

  Contact({
    required this.id,
    required this.name,
    required this.version,
  });
}

/// ----------------------------
/// 2. Sync Handler
/// ----------------------------

class ContactsSyncHandler extends SyncHandler {
  final List<Contact> _localContacts = [
    Contact(id: '1', name: 'Alice', version: 1),
  ];

  String? _cursor;

  @override
  Future<String?> getLastSyncCursor() async => _cursor;

  @override
  Future<void> updateLastSyncCursor(String cursor) async {
    _cursor = cursor;
  }

  @override
  Future<List<SyncPayload<Syncable>>> getLocal() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _localContacts.map((c) => SyncPayload<Syncable>(data: c)).toList();
  }

  @override
  Future<SyncBatchResult> getRemote({String? cursor}) async {
    await Future.delayed(const Duration(seconds: 1));
    // Fetch remote contacts from API with pagination using cursor/offset, offset can be convert to string
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
    await Future.delayed(const Duration(seconds: 1));
    // Apply remote changes to local storage (e.g. database)
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

  @override
  Future<ApplyResult> applyToRemote(
      List<SyncPayload<Syncable>> localStates) async {
    await Future.delayed(const Duration(seconds: 1));
    // Make API calls to update remote server with local changes
    return ApplyResult.success();
  }
}

/// 3. Main

Future<void> main() async {
  print('🚀 Initializing FeroSync...\n');

  final feroSync = await FeroSync.create(
    handlers: {
      'contacts': ContactsSyncHandler(),
    },
  );

  // Listen to global sync status
  feroSync.statusStream.listen((status) {
    if (status == InitialSyncStatus.completed) {
      print('📡 Initial Sync completed');
      return;
    }
    print('📡 Sync Status: $status');
  });

  print('\n▶ Starting sync...\n');

  await feroSync.run();

  print('\n✅ Sync finished.');
}
