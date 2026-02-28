import 'dart:async';
import 'package:fero_sync/feature_sync/feature_sync_handler.dart';
import 'package:fero_sync/core/models/sync_checkpoint.dart';
import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/initial_sync/initial_sync_handler.dart';
import 'package:fero_sync/fero_sync.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';
import 'package:fero_sync/feature_sync/feature_sync_config.dart';
import 'package:fero_sync/core/results/apply_result.dart';
import 'package:fero_sync/core/results/sync_batch_result.dart';

// ==========================
// STEP 1: Set up FeroSync
// ==========================
Future<void> main() async {
  print('🚀 FeroSync - User, Contacts & Messages\n');

  final feroSync = await FeroSync.create(
    initialSyncConfigs: {
      'user_preferences': InitialSyncConfig(
        handler: UserPreferencesInitialSyncHandler(),
        priority: 100,
      ),
    },
    // Feature sync: Runs periodically to keep data fresh
    // Handles incremental updates after initial sync is complete
    featureSyncConfigs: {
      'contacts': FeatureSyncConfig(
        handler: ContactSyncHandler(),
        priority: 90,
      ),
      'messages': FeatureSyncConfig(
        handler: MessageSyncHandler(),
        priority: 80,
        dependencies: ['contacts'],
      ),
    },
    metadataRepo: InMemorySyncMetaDataRepo(),
  );

  // Listen to initial sync status
  feroSync.initialSyncNotifier.addListener(() {
    print('📊 Initial Sync status: ${feroSync.initialSyncNotifier.value}');
  });

  // Listen to sync events
  feroSync.featureSyncNotifier('contacts')?.addListener(() {
    print(
        '📡 Contacts Sync status: ${feroSync.featureSyncNotifier('contacts')?.value}');
  });

  // Start syncing (initial + feature)
  feroSync.startSync();

  // Trigger manual background sync (optional)
  feroSync.syncAll();
}

// ==========================
// STEP 2: Data Models
// ==========================

// Local & Server UserPreferences
class LocalUserPreferences implements LocalItem {
  @override
  final String id;
  @override
  final int version;
  @override
  final bool locallyModified;
  final String userId;
  final String displayName;
  final String theme;

  LocalUserPreferences({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.theme,
    required this.version,
    this.locallyModified = false,
  });
}

class ServerUserPreferences implements ServerItem {
  @override
  final String id;
  @override
  final BigInt syncId;
  @override
  final int version;
  @override
  final DateTime updatedAt;
  final String userId;
  final String displayName;
  final String theme;

  ServerUserPreferences({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.theme,
    required this.syncId,
    required this.version,
    required this.updatedAt,
  });
}

// Local & Server Contact
class LocalContact implements LocalItem {
  @override
  final String id;
  @override
  final int version;
  @override
  final bool locallyModified;
  final String name;
  final String email;

  LocalContact({
    required this.id,
    required this.name,
    required this.email,
    required this.version,
    this.locallyModified = false,
  });
}

class ServerContact implements ServerItem {
  @override
  final String id;
  @override
  final BigInt syncId;
  @override
  final int version;
  @override
  final DateTime updatedAt;
  final String name;
  final String email;

  ServerContact({
    required this.id,
    required this.name,
    required this.email,
    required this.syncId,
    required this.version,
    required this.updatedAt,
  });
}

// Local & Server Message
class LocalMessage implements LocalItem {
  @override
  final String id;
  @override
  final int version;
  @override
  final bool locallyModified;
  final String contactId;
  final String text;

  LocalMessage({
    required this.id,
    required this.contactId,
    required this.text,
    required this.version,
    this.locallyModified = false,
  });
}

class ServerMessage implements ServerItem {
  @override
  final String id;
  @override
  final BigInt syncId;
  @override
  final int version;
  @override
  final DateTime updatedAt;
  final String contactId;
  final String text;

  ServerMessage({
    required this.id,
    required this.contactId,
    required this.text,
    required this.syncId,
    required this.version,
    required this.updatedAt,
  });
}

// ==========================
// STEP 3: Initial Sync Handler
// ==========================
class UserPreferencesInitialSyncHandler extends InitialSyncHandler {
  @override
  Future<SyncBatchResult> fetchRemoteData(
      {checkpoint, required int batchSize}) async {
    final serverPreferences = [
      ServerUserPreferences(
        id: 's1',
        userId: 'user-123',
        displayName: 'John Doe',
        theme: 'dark',
        syncId: BigInt.from(1),
        version: 1,
        updatedAt: DateTime.now().subtract(Duration(days: 2)),
      ),
    ];

    final lastItem =
        serverPreferences.isNotEmpty ? serverPreferences.last : null;

    return SyncBatchResult.success(
      items: serverPreferences
          .map((p) => SyncPayload<ServerItem>(data: p))
          .toList(),
      checkpoint:
          lastItem != null ? SyncCheckpoint(afterId: lastItem.syncId) : null,
    );
  }

  @override
  Future<ApplyResult> saveToLocal(
      List<SyncPayload<ServerItem>> remoteData) async {
    print('📥 Initial sync: Loaded user preferences');
    return ApplyResult.success();
  }
}

// ==========================
// STEP 4: Background Sync Handlers
// ==========================
class ContactSyncHandler extends FeatureSyncHandler {
  final List<LocalContact> _contacts = [
    LocalContact(
        id: 'c1',
        name: 'Alice',
        email: 'alice@example.com',
        version: 1,
        locallyModified: true),
  ];

  @override
  Future<List<SyncPayload<LocalItem>>> getLocallyModifiedByIds(
          {required List<String> ids}) async =>
      _contacts
          .where((c) => c.locallyModified && ids.contains(c.id))
          .map((c) => SyncPayload<LocalItem>(data: c))
          .toList();

  @override
  Future<SyncBatchResult> fetchRemoteChanges(
      {checkpoint, required int batchSize}) async {
    final serverContacts = [
      ServerContact(
          id: 'c1',
          name: 'Alice',
          email: 'alice@example.com',
          syncId: BigInt.from(100),
          version: 1,
          updatedAt: DateTime.now().subtract(Duration(minutes: 5))),
      ServerContact(
          id: 'c2',
          name: 'Bob',
          email: 'bob@example.com',
          syncId: BigInt.from(101),
          version: 1,
          updatedAt: DateTime.now()),
    ];
    final lastItem = serverContacts.isNotEmpty ? serverContacts.last : null;

    return SyncBatchResult.success(
      items:
          serverContacts.map((c) => SyncPayload<ServerItem>(data: c)).toList(),
      checkpoint:
          lastItem != null ? SyncCheckpoint(afterId: lastItem.syncId) : null,
    );
  }

  @override
  Future<ApplyResult> applyRemoteChanges(
      List<SyncPayload<ServerItem>> remoteStates) async {
    print('📇 Saved ${remoteStates.length} contacts');
    return ApplyResult.success();
  }

  @override
  Future<ApplyResult> pushLocalChanges(
      List<SyncPayload<LocalItem>> localStates) async {
    print('📤 Pushed ${localStates.length} contacts');
    return ApplyResult.success();
  }
}

class MessageSyncHandler extends FeatureSyncHandler {
  final List<LocalMessage> _messages = [
    LocalMessage(
        id: 'm1',
        contactId: 'c1',
        text: 'Hey, how are you?',
        version: 1,
        locallyModified: true),
  ];

  @override
  Future<List<SyncPayload<LocalItem>>> getLocallyModifiedByIds(
          {required List<String> ids}) async =>
      _messages
          .where((m) => m.locallyModified && ids.contains(m.id))
          .map((m) => SyncPayload<LocalItem>(data: m))
          .toList();

  @override
  Future<SyncBatchResult> fetchRemoteChanges(
      {checkpoint, required int batchSize}) async {
    final serverMessages = [
      ServerMessage(
          id: 'm2',
          contactId: 'c2',
          text: 'Welcome to FeroSync!',
          syncId: BigInt.from(201),
          version: 1,
          updatedAt: DateTime.now()),
    ];
    final lastItem = serverMessages.isNotEmpty ? serverMessages.last : null;

    return SyncBatchResult.success(
      items:
          serverMessages.map((m) => SyncPayload<ServerItem>(data: m)).toList(),
      checkpoint:
          lastItem != null ? SyncCheckpoint(afterId: lastItem.syncId) : null,
    );
  }

  @override
  Future<ApplyResult> applyRemoteChanges(
      List<SyncPayload<ServerItem>> remoteStates) async {
    print('💬 Saved ${remoteStates.length} messages');
    return ApplyResult.success();
  }

  @override
  Future<ApplyResult> pushLocalChanges(
      List<SyncPayload<LocalItem>> localStates) async {
    print('📤 Pushed ${localStates.length} messages');
    return ApplyResult.success();
  }
}
