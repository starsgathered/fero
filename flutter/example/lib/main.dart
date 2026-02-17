import 'dart:async';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/core/results/apply_result.dart';
import 'package:fero_sync/background_sync/background_sync_handler.dart';
import 'package:fero_sync/initial_sync/initial_sync_handler.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';
import 'package:fero_sync/core/results/sync_batch_result.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';
import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/models/sync_checkpoint.dart';
import 'package:fero_sync/fero_sync.dart';
import 'package:fero_sync/background_sync/feature_sync_config.dart';

// 🎯 FeroSync Example - User, Contacts & Messages
// =================================================
// Sync user preferences, contacts, and messages

// STEP 1: Set up and run
// --------------------------------

Future<void> main() async {
  print('🚀 FeroSync - User, Contacts & Messages\n');

  // Create FeroSync with multiple feature handlers
  final feroSync = await FeroSync.create(
    // Initial sync: Runs once when user logs in or app is first installed
    // Downloads essential data needed before the app can be used
    initialSyncConfigs: {
      'user_preferences': FeatureInitialSyncConfig(
        handler: UserPreferencesInitialSyncHandler(),
        priority: 100,
      ),
    },
    conflictStrategy: ConflictResolutionStrategy.highestVersionWins,
    // Background sync: Runs periodically to keep data fresh
    // Handles incremental updates after initial sync is complete
    backgroundSyncConfigs: {
      'contacts': FeatureSyncConfig(
        handler: ContactSyncHandler(),
        priority: 100, // Sync contacts first
      ),
      'messages': FeatureSyncConfig(
        handler: MessageSyncHandler(),
        priority: 90, // Then messages
        dependencies: ['contacts'], // Messages depend on contacts
      ),
    },
    metadataRepo: InMemorySyncMetaDataRepo(),
  );

  // Listen to sync events
  feroSync.backgroundSyncEventStream?.listen((event) {
    print('📡 ${event.runtimeType}');
  });

  // Start syncing all features
  print('▶️  Syncing contacts and messages...\n');
  feroSync.backgroundManager?.syncAll();

  await Future.delayed(Duration(seconds: 1));
  print('\n✅ Sync complete!\n');
}

// STEP 2: Define your data models
// --------------------------------

/// Local UserPreferences
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

/// Server UserPreferences
class ServerUserPreferences implements ServerItem {
  @override
  final String id;
  @override
  final int syncId;
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

/// Local Contact
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

/// Server Contact
class ServerContact implements ServerItem {
  @override
  final String id;
  @override
  final int syncId;
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

/// Local Message
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

/// Server Message
class ServerMessage implements ServerItem {
  @override
  final String id;
  @override
  final int syncId;
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

// Initial Sync Handler: For first-time data load
class UserPreferencesInitialSyncHandler extends InitialSyncHandler {
  @override
  Future<SyncBatchResult> fetchRemoteData({
    checkpoint,
    required int batchSize,
  }) async {
    // Load user preferences from server on first login
    // This is essential data needed before the app can function
    final serverPreferences = [
      ServerUserPreferences(
        id: 'pref-1',
        userId: 'user-123',
        displayName: 'John Doe',
        theme: 'dark',
        syncId: 1,
        version: 1,
        updatedAt: DateTime.now().subtract(Duration(days: 2)),
      ),
    ];

    final lastItem =
        serverPreferences.isNotEmpty ? serverPreferences.last : null;

    return SyncBatchResult(
      items: serverPreferences
          .map((p) => SyncPayload<ServerItem>(data: p))
          .toList(),
      checkpoint: lastItem != null
          ? SyncCheckpoint(
              lastSyncId: lastItem.syncId, updatedAt: lastItem.updatedAt)
          : null,
    );
  }

  @override
  Future<ApplyResult> saveToLocal(
      List<SyncPayload<ServerItem>> remoteData) async {
    print('📥 Initial sync: Loaded user preferences');
    return ApplyResult.success();
  }
}

// Background Sync Handler: For incremental updates

// STEP 3: Implement sync handlers
// --------------------------------

class ContactSyncHandler extends BackgroundSyncHandler {
  final List<LocalContact> _contacts = [
    LocalContact(
      id: 'c1',
      name: 'Alice',
      email: 'alice@example.com',
      version: 1,
      locallyModified: true,
    ),
  ];

  @override
  Future<List<SyncPayload<LocalItem>>> getLocallyModified() async {
    return _contacts
        .where((c) => c.locallyModified)
        .map((c) => SyncPayload<LocalItem>(data: c))
        .toList();
  }

  @override
  Future<SyncBatchResult> fetchRemoteChanges(
      {checkpoint, required int batchSize}) async {
    final serverContacts = [
      ServerContact(
        id: 'c1',
        name: 'Alice',
        email: 'alice@example.com',
        syncId: 100,
        version: 1,
        updatedAt: DateTime.now().subtract(Duration(minutes: 5)),
      ),
      ServerContact(
        id: 'c2',
        name: 'Bob',
        email: 'bob@example.com',
        syncId: 101,
        version: 1,
        updatedAt: DateTime.now(),
      ),
    ];

    // last item picked for checkpointing to ensure correct pagination
    final lastItem = serverContacts.isNotEmpty ? serverContacts.last : null;

    return SyncBatchResult(
      items:
          serverContacts.map((c) => SyncPayload<ServerItem>(data: c)).toList(),
      checkpoint: lastItem != null
          ? SyncCheckpoint(
              lastSyncId: lastItem.syncId, updatedAt: lastItem.updatedAt)
          : null,
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

class MessageSyncHandler extends BackgroundSyncHandler {
  final List<LocalMessage> _messages = [
    LocalMessage(
      id: 'm1',
      contactId: 'c1',
      text: 'Hey, how are you?',
      version: 1,
      locallyModified: true,
    ),
  ];

  @override
  Future<List<SyncPayload<LocalItem>>> getLocallyModified() async {
    return _messages
        .where((m) => m.locallyModified)
        .map((m) => SyncPayload<LocalItem>(data: m))
        .toList();
  }

  @override
  Future<SyncBatchResult> fetchRemoteChanges(
      {checkpoint, required int batchSize}) async {
    final serverMessages = [
      ServerMessage(
        id: 'm2',
        contactId: 'c2',
        text: 'Welcome to FeroSync!',
        syncId: 201,
        version: 1,
        updatedAt: DateTime.now(),
      ),
    ];
    final lastMsg = serverMessages.isNotEmpty ? serverMessages.last : null;

    return SyncBatchResult(
      items:
          serverMessages.map((m) => SyncPayload<ServerItem>(data: m)).toList(),
      checkpoint: lastMsg != null
          ? SyncCheckpoint(
              lastSyncId: lastMsg.syncId, updatedAt: lastMsg.updatedAt)
          : null,
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
