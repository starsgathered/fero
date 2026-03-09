import 'dart:async';
import 'package:fero_sync/core/results/push_local_changes.dart';
import 'package:fero_sync/core/results/handle_push_results.dart';
import 'package:fero_sync/core/results/push_results_input.dart';
import 'package:fero_sync/fero_sync.dart';
import 'package:fero_sync/core/models/sync_checkpoint.dart';
import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/results/apply_result.dart';
import 'package:fero_sync/core/results/sync_batch_result.dart';
import 'package:fero_sync/core/sync_metadata_repo.dart';
import 'package:fero_sync/feature_sync/feature_sync_config.dart';
import 'package:fero_sync/feature_sync/feature_sync_handler.dart';
import 'package:fero_sync/initial_sync/enum/initial_sync_status.dart';
import 'package:fero_sync/initial_sync/initial_sync.dart';
import 'package:fero_sync/initial_sync/initial_sync_handler.dart';

/// ------------------------------------------------
/// Entry Point
/// ------------------------------------------------
Future<void> main() async {
  final localDb = <LocalMessage>[];

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

  feroSync.initialSyncNotifier.addListener(() {
    print("📊 Initial Sync Status: ${feroSync.initialSyncNotifier.value}");

    if (feroSync.initialSyncNotifier.value == InitialSyncStatus.completed) {
      print("✅ Initial Sync Finished");
      print("Local messages count: ${localDb.length}");
    }
  });

  feroSync.startInitialSync();

  feroSync.featureSyncNotifier("messages")?.addListener(() {
    print("📡 Background Sync Running...");
  });

  addMessageFromUI("Hello from UI!", localDb, feroSync);
}

/// ------------------------------------------------
/// Local Model
/// ------------------------------------------------
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

/// ------------------------------------------------
/// Server Model
/// ------------------------------------------------
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

/// ------------------------------------------------
/// Simulated SERVER DATABASE
/// ------------------------------------------------
class FakeServerDB {
  final List<ServerMessage> _messages = [
    ServerMessage(
      id: "m1",
      syncId: BigInt.from(1),
      text: "Welcome 👋",
      version: 1,
      updatedAt: DateTime.parse("2024-01-01T00:00:00Z"),
    ),
    ServerMessage(
      id: "m2",
      syncId: BigInt.from(2),
      text: "Hello from server!",
      version: 1,
      updatedAt: DateTime.parse("2024-01-01T00:01:00Z"),
    ),
    ServerMessage(
      id: "m3",
      syncId: BigInt.from(3),
      text: "Another message",
      version: 1,
      updatedAt: DateTime.parse("2024-01-01T00:02:00Z"),
    ),
  ];

  List<ServerMessage> fetchMessages({
    SyncCheckpoint? checkpoint,
    required int batchSize,
  }) {
    final startIndex = checkpoint == null
        ? 0
        : _messages.indexWhere((m) => m.syncId == checkpoint.lastSyncedId) + 1;

    return _messages.skip(startIndex).take(batchSize).toList();
  }

  bool hasMore({
    SyncCheckpoint? checkpoint,
    required int fetchedCount,
  }) {
    final startIndex = checkpoint == null
        ? 0
        : _messages.indexWhere((m) => m.syncId == checkpoint.lastSyncedId) + 1;

    return startIndex + fetchedCount < _messages.length;
  }
}

final fakeServer = FakeServerDB();

/// ------------------------------------------------
/// Initial Sync Handler
/// ------------------------------------------------
class MessageInitialSyncHandler extends InitialSyncHandler {
  final List<LocalMessage> _localDb;

  MessageInitialSyncHandler(this._localDb);

  @override
  Future<SyncBatchResult> fetchRemoteData({
    SyncCheckpoint? checkpoint,
    required int batchSize,
  }) async {
    print("🌍 Initial Sync Fetch");

    final items =
        fakeServer.fetchMessages(checkpoint: checkpoint, batchSize: batchSize);

    final hasMore = fakeServer.hasMore(
      checkpoint: checkpoint,
      fetchedCount: items.length,
    );

    return SyncBatchResult.success(
      items: items.map((e) => SyncPayload<ServerItem>(data: e)).toList(),
      stopIfNoNextPage: !hasMore,
    );
  }

  @override
  Future<ApplyResult> saveToLocal(
      List<SyncPayload<ServerItem>> remoteData) async {
    for (final payload in remoteData) {
      final server = payload.data as ServerMessage;

      _localDb.add(
        LocalMessage(
          id: server.id,
          text: server.text,
          version: server.version,
        ),
      );
    }

    print("💾 Saved ${remoteData.length} messages locally");

    return ApplyResult.success();
  }
}

/// ------------------------------------------------
/// Feature Sync Handler
/// ------------------------------------------------
class MessageFeatureSyncHandler extends FeatureSyncHandler {
  final List<LocalMessage> _localDb;

  MessageFeatureSyncHandler(this._localDb);

  @override
  Future<List<SyncPayload<LocalItem>>> getLocallyModified(
      {int batchSize = 50}) async {
    final modified = _localDb
        .where((m) => m.locallyModified)
        .take(batchSize)
        .map((m) => SyncPayload<LocalItem>(data: m))
        .toList();

    print("📤 Found ${modified.length} local changes");

    return modified;
  }

  @override
  Future<PushLocalChangesResult<LocalItem>> pushLocalChanges(
      [List<SyncPayload<LocalItem>>? localStates]) async {
    final results = <PushResultItem<LocalItem>>[];

    print("🚀 Uploading ${localStates?.length ?? 0} messages");

    for (final payload in localStates ?? []) {
      final msg = payload.data as LocalMessage;

      try {
        final index = _localDb.indexWhere((e) => e.id == msg.id);

        if (index == -1) {
          results.add(
            PushResultItem(
              id: msg.id,
              status: PushStatus.failed,
            ),
          );
          continue;
        }

        _localDb[index] = LocalMessage(
          id: msg.id,
          text: msg.text,
          version: msg.version + 1,
          locallyModified: false,
        );

        results.add(
          PushResultItem(
            id: msg.id,
            status: PushStatus.success,
          ),
        );
      } catch (e) {
        results.add(
          PushResultItem(
            id: msg.id,
            status: PushStatus.failed,
          ),
        );
      }
    }

    return PushLocalChangesResult(items: results);
  }

  @override
  Future<SyncBatchResult> fetchRemoteChanges({
    SyncCheckpoint? checkpoint,
    required int batchSize,
  }) async {
    print("🌍 Fetching remote updates");

    final items =
        fakeServer.fetchMessages(checkpoint: checkpoint, batchSize: batchSize);

    final hasMore = fakeServer.hasMore(
      checkpoint: checkpoint,
      fetchedCount: items.length,
    );

    return SyncBatchResult.success(
      items: items.map((e) => SyncPayload<ServerItem>(data: e)).toList(),
      stopIfNoNextPage: !hasMore,
    );
  }

  @override
  Future<ApplyResult> applyRemoteChanges(
      List<SyncPayload<ServerItem>> remoteData) async {
    for (final payload in remoteData) {
      final server = payload.data as ServerMessage;

      if (!_localDb.any((m) => m.id == server.id)) {
        _localDb.add(
          LocalMessage(
            id: server.id,
            text: server.text,
            version: server.version,
          ),
        );
      }
    }

    print("📥 Applied ${remoteData.length} remote messages");

    return ApplyResult.success();
  }

  @override
  Future<HandlePushResults> handlePushResults(
      HandlePushResultsInput pushResults) async {
    return HandlePushResults(
      success: true,
    );
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

/// ------------------------------------------------
/// Metadata Repo
/// ------------------------------------------------
class InMemorySyncMetaDataRepo implements SyncMetaDataRepo {
  final Map<String, SyncCheckpoint?> _checkpoints = {};
  final Map<String, bool> _initialCompleted = {};

  @override
  Future<SyncCheckpoint?> getCheckpoint(String featureKey) async =>
      _checkpoints[featureKey];

  @override
  Future<void> updateCheckpoint(
          String featureKey, SyncCheckpoint? checkpoint) async =>
      _checkpoints[featureKey] = checkpoint;

  @override
  Future<bool> isInitialSyncCompleted(String featureKey) async =>
      _initialCompleted[featureKey] ?? false;

  @override
  Future<bool> areAllInitialSyncsCompleted(List<String> featureKeys) async =>
      featureKeys.every((key) => _initialCompleted[key] ?? false);

  @override
  Future<void> setInitialSyncCompleted(
          String featureKey, bool completed) async =>
      _initialCompleted[featureKey] = completed;
}

/// ------------------------------------------------
/// Simulate UI Message Creation
/// ------------------------------------------------
void addMessageFromUI(
    String text, List<LocalMessage> localDb, FeroSync feroSync) {
  final newMessage = LocalMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    text: text,
    version: 1,
    locallyModified: true,
  );

  localDb.add(newMessage);

  print("✏️ User created message: ${newMessage.text}");

  feroSync.syncFeature("messages", force: true);
}
