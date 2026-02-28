import 'dart:async';

import 'package:fero_sync/core/models/sync_checkpoint.dart';
import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/results/apply_result.dart';
import 'package:fero_sync/core/results/sync_batch_result.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';
import 'package:fero_sync/feature_sync/feature_sync_config.dart';
import 'package:fero_sync/feature_sync/feature_sync_handler.dart';
import 'package:fero_sync/fero_sync.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';
import 'package:fero_sync/initial_sync/initial_sync_handler.dart';

/// ------------------
/// Example: Beginner-friendly usage
/// ------------------
Future<void> main() async {
  // Local database in memory
  final localDb = <LocalMessage>[];

  // Create FeroSync instance
  final feroSync = await FeroSync.create(
    metadataRepo: InMemorySyncMetaDataRepo(),
    initialSyncConfigs: {
      "messages": InitialSyncConfig(
        handler: MessageInitialSyncHandler(localDb),
      ),
    },
    featureSyncConfigs: {
      "messages": FeatureSyncConfig(
        handler: MessageFeatureSyncHandler(localDb),
      ),
    },
  );

  // Listen for initial sync status updates
  feroSync.initialSyncNotifier.addListener(() {
    print("📊 Initial Sync Status: ${feroSync.initialSyncNotifier.value}");
  });

  // Listen for background/incremental sync
  feroSync.featureSyncNotifier("messages")?.addListener(() {
    print("📡 Background Sync Running...");
  });

  // Start syncing (initial sync + automatic background sync)
  await feroSync.startSync();

  // Example: User adds a new message in the UI
  addMessageFromUI("Hello, world!", localDb, feroSync);
}

/// ------------------
/// Local and Server models
/// ------------------
class LocalMessage implements LocalItem {
  @override
  final String id;
  final String text;
  @override
  final int version;
  @override
  final bool locallyModified;

  LocalMessage({
    required this.id,
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
  final String text;
  @override
  final int version;
  @override
  final DateTime updatedAt;

  ServerMessage({
    required this.id,
    required this.syncId,
    required this.text,
    required this.version,
    required this.updatedAt,
  });
}

/// ------------------
/// Initial Sync Handler
/// ------------------
class MessageInitialSyncHandler extends InitialSyncHandler {
  final List<LocalMessage> _localDb;
  MessageInitialSyncHandler(this._localDb);

  @override
  Future<SyncBatchResult> fetchRemoteData({
    checkpoint,
    required int batchSize,
  }) async {
    print("🌍 Fetching old messages from server...");

    final serverMessages = [
      ServerMessage(
        id: "m1",
        syncId: BigInt.from(1),
        text: "Welcome 👋",
        version: 1,
        updatedAt: DateTime.now(),
      ),
    ];

    return SyncBatchResult.success(
      items:
          serverMessages.map((e) => SyncPayload<ServerItem>(data: e)).toList(),
      checkpoint: SyncCheckpoint(afterId: BigInt.from(1)),
    );
  }

  @override
  Future<ApplyResult> saveToLocal(
      List<SyncPayload<ServerItem>> remoteData) async {
    for (final item in remoteData) {
      final server = item.data as ServerMessage;
      _localDb.add(LocalMessage(
        id: server.id,
        text: server.text,
        version: server.version,
        locallyModified: false,
      ));
    }
    print("💾 Initial messages saved locally");
    return ApplyResult.success();
  }
}

/// ------------------
/// Feature Sync Handler (incremental / background sync)
/// ------------------
class MessageFeatureSyncHandler extends FeatureSyncHandler {
  final List<LocalMessage> _localDb;
  MessageFeatureSyncHandler(this._localDb);

  /// 1️⃣ Get unsent/locally modified messages
  @override
  Future<List<SyncPayload<LocalItem>>> getLocallyModified(
      {int batchSize = 50}) async {
    final unsent = _localDb
        .where((m) => m.locallyModified)
        .take(batchSize)
        .map((m) => SyncPayload<LocalItem>(data: m))
        .toList();
    print("📤 Found ${unsent.length} unsent messages");
    return unsent;
  }

  /// 2️⃣ Push local messages to server
  @override
  Future<ApplyResult> pushLocalChanges(
      [List<SyncPayload<LocalItem>>? localStates]) async {
    print("🚀 Sending ${localStates?.length ?? 0} messages to server...");
    for (final payload in localStates ?? []) {
      final msg = payload.data as LocalMessage;
      final index = _localDb.indexWhere((e) => e.id == msg.id);
      if (index != -1) {
        _localDb[index] = LocalMessage(
          id: msg.id,
          text: msg.text,
          version: msg.version + 1,
          locallyModified: false,
        );
      }
    }
    return ApplyResult.success();
  }

  /// 3️⃣ Fetch new messages from server
  @override
  Future<SyncBatchResult> fetchRemoteChanges(
      {checkpoint, required int batchSize}) async {
    print("🌍 Fetching new messages from server...");
    final newMessages = [
      ServerMessage(
        id: "m2",
        syncId: BigInt.from(2),
        text: "Hello from server!",
        version: 1,
        updatedAt: DateTime.now(),
      ),
    ];

    return SyncBatchResult.success(
      items: newMessages.map((e) => SyncPayload<ServerItem>(data: e)).toList(),
      checkpoint: SyncCheckpoint(afterId: BigInt.from(2)),
    );
  }

  /// 4️⃣ Apply remote messages locally
  @override
  Future<ApplyResult> applyRemoteChanges(
      List<SyncPayload<ServerItem>> remoteData) async {
    for (final payload in remoteData) {
      final server = payload.data as ServerMessage;
      final exists = _localDb.any((m) => m.id == server.id);
      if (!exists) {
        _localDb.add(LocalMessage(
          id: server.id,
          text: server.text,
          version: server.version,
          locallyModified: false,
        ));
      }
    }
    print("📥 Applied ${remoteData.length} new messages locally");
    return ApplyResult.success();
  }

  @override
  Future<List<SyncPayload<LocalItem>>> getLocallyModifiedByIds(
      {required List<String> ids}) async {
    return _localDb
        .where((m) => ids.contains(m.id))
        .map((m) => SyncPayload<LocalItem>(data: m))
        .toList();
  }
}

/// ------------------
/// In-memory metadata repo
/// ------------------
class InMemorySyncMetaDataRepo implements SyncMetaDataRepo {
  final Map<String, SyncCheckpoint?> _initialCheckpoints = {};
  final Map<String, bool> _initialCompleted = {};
  final Map<String, SyncCheckpoint?> _backgroundCheckpoints = {};

  @override
  Future<SyncCheckpoint?> getInitialSyncCheckpoint(String featureKey) async =>
      _initialCheckpoints[featureKey];

  @override
  Future<void> updateInitialSyncCheckpoint(
          String featureKey, SyncCheckpoint? checkpoint) async =>
      _initialCheckpoints[featureKey] = checkpoint;

  @override
  Future<bool> isInitialSyncCompleted(String featureKey) async =>
      _initialCompleted[featureKey] ?? false;

  @override
  Future<bool> areAllInitialSyncsCompleted(List<String> featureKeys) async {
    if (featureKeys.isEmpty) return true;
    for (final key in featureKeys) {
      if (!(_initialCompleted[key] ?? false)) return false;
    }
    return true;
  }

  @override
  Future<void> setInitialSyncCompleted(
          String featureKey, bool completed) async =>
      _initialCompleted[featureKey] = completed;

  @override
  Future<SyncCheckpoint?> getBackgroundSyncCheckpoint(
          String featureKey) async =>
      _backgroundCheckpoints[featureKey];

  @override
  Future<void> updateBackgroundSyncCheckpoint(
          String featureKey, SyncCheckpoint? checkpoint) async =>
      _backgroundCheckpoints[featureKey] = checkpoint;
}

/// ------------------
/// Helper: Simulate adding message from UI
/// ------------------
void addMessageFromUI(
    String text, List<LocalMessage> localDb, FeroSync feroSync) {
  final newMessage = LocalMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    text: text,
    version: 1,
    locallyModified: true,
  );
  localDb.add(newMessage);
  print("✏️ User added message locally: ${newMessage.text}");

  // Force sync this feature immediately
  feroSync.syncFeature("messages", force: true);
}
