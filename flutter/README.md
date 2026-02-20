# Fero

**Fero** is a **Flutter/Dart offline-first sync library** that orchestrates bidirectional data synchronization between your app and server with built-in conflict resolution, retry logic, and pagination support.
Fero means "circulate" (from "pheero" / "phiro" — "move here and there").

## Features

- ✅ **Initial Sync** - Load essential data on first install or login
- ✅ **Background Sync** - Keep data fresh with incremental updates
- ✅ **Version-based Conflict Resolution** - Automatic conflict handling using server versions
- ✅ **Checkpoint Pagination** - Resume sync from exact point after interruption
- ✅ **Retry & Backoff** - Configurable exponential backoff for failed operations
- ✅ **Event Streams** - Observable sync events for UI updates
- ✅ **Dependency Management** - Sync features in order with dependencies
- ✅ **Type-Safe** - Separate LocalItem and ServerItem types for clarity

---

## Why Fero?

Building offline-first Flutter apps is hard. Fero solves common sync challenges:

| Problem | Fero Solution |
|---------|---------------|
| Sync logic scattered across UI | Centralized sync orchestration |
| Complex retry logic | Built-in exponential backoff |
| Conflict resolution bugs | Version-based conflict strategy |
| Interrupted syncs lose progress | Checkpoint-based pagination |
| Tightly coupled code | Clean handler interfaces |
| Hard to test | Pure business logic handlers |

---

## Quick Start

### 1. Add Dependency

```yaml
dependencies:
  fero_sync: ^0.4.5
```

### 2. Define Your Data Models

Create separate types for local and server items:

```dart
// Local item (on device)
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

// Server item (from backend)
class ServerContact implements ServerItem {
  @override
  final String id;
  @override
  final int syncId;        // Monotonic ID for pagination
  @override
  final int version;
  @override
  final DateTime updatedAt; // When last updated on server
  
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
```

### 3. Implement Sync Handlers

**Initial Sync Handler** (for first-time data load):

```dart
class UserPreferencesInitialSyncHandler extends InitialSyncHandler {
  @override
  Future<SyncBatchResult> fetchRemoteData({
    SyncCheckpoint? checkpoint,
    required int batchSize,
  }) async {
    // Load from server: WHERE syncId > checkpoint.lastSyncId LIMIT batchSize
    final prefs = await api.fetchUserPreferences();
    
    return SyncBatchResult(
      items: prefs.map((p) => SyncPayload<ServerItem>(data: p)).toList(),
      checkpoint: SyncCheckpoint(
        lastSyncId: prefs.last.syncId,
        updatedAt: prefs.last.updatedAt,
      ),
    );
  }

  @override
  Future<ApplyResult> saveToLocal(List<SyncPayload<ServerItem>> data) async {
    await db.saveUserPreferences(data);
    return ApplyResult.success();
  }
}
```

**Background Sync Handler** (for incremental updates):

```dart
class ContactSyncHandler extends BackgroundSyncHandler {
  @override
  Future<List<SyncPayload<LocalItem>>> getLocallyModified() async {
    // Get items that need syncing
    final contacts = await db.getModifiedContacts();
    return contacts.map((c) => SyncPayload<LocalItem>(data: c)).toList();
  }

  @override
  Future<SyncBatchResult> fetchRemoteChanges({
    SyncCheckpoint? checkpoint,
    required int batchSize,
  }) async {
    // Fetch from server with pagination
    final contacts = await api.fetchContacts(
      afterSyncId: checkpoint?.lastSyncId,
      limit: batchSize,
    );
    
    return SyncBatchResult(
      items: contacts.map((c) => SyncPayload<ServerItem>(data: c)).toList(),
      checkpoint: contacts.isNotEmpty
          ? SyncCheckpoint(
              lastSyncId: contacts.last.syncId,
              updatedAt: contacts.last.updatedAt,
            )
          : null,
    );
  }

  @override
  Future<ApplyResult> applyRemoteChanges(List<SyncPayload<ServerItem>> data) async {
    await db.saveContacts(data);
    return ApplyResult.success();
  }

  @override
  Future<ApplyResult> pushLocalChanges(List<SyncPayload<LocalItem>> data) async {
    await api.uploadContacts(data);
    return ApplyResult.success();
  }
}
```

### 4. Initialize FeroSync

```dart
final feroSync = await FeroSync.create(
  // Initial sync: Essential data loaded on first login
  initialSyncConfigs: {
    'user_preferences': FeatureInitialSyncConfig(
      handler: UserPreferencesInitialSyncHandler(),
      priority: 100,
    ),
  },
  // Background sync: Incremental updates
  backgroundSyncConfigs: {
    'contacts': FeatureSyncConfig(
      handler: ContactSyncHandler(),
      priority: 100,
    ),
    'messages': FeatureSyncConfig(
      handler: MessageSyncHandler(),
      priority: 90,
      dependencies: ['contacts'], // Sync contacts first
    ),
  },
  metadataRepo: InMemorySyncMetaDataRepo(),
  conflictStrategy: ConflictResolutionStrategy.highestVersionWins,
);
```

### 5. Start Syncing

```dart
// Listen to events
feroSync.backgroundSyncEventStream?.listen((event) {
  print('Sync event: ${event.runtimeType}');
});Advanced Usage

### Feature Dependencies

Ensure features sync in the correct order:
```dart
backgroundSyncConfigs: {
  'users': FeatureSyncConfig(
  @override
  final BigInt syncId;        // Monotonic ID for pagination (BigInt used by Fero)
  ),
  'posts': FeatureSyncConfig(
    handler: PostSyncHandler(),
    priority: 90,
    dependencies: ['users'], // Wait for users first
  ),
  'comments': FeatureSyncConfig(
    handler: CommentSyncHandler(),
    priority: 80,
    dependencies: ['posts'], // Wait for posts first
  ),
}
        afterId: prefs.last.syncId,

### Pagination with Checkpoints

Resume sync from where you left off:

```dart
Future<SyncBatchResult> fetchRemoteChanges({
  SyncCheckpoint? checkpoint,
  required int batchSize,
}) async {
  // Use checkpoint to paginate
  final afterSyncId = checkpoint?.lastSyncId ?? 0;
  
              afterId: contacts.last.syncId,
    'SELECT * FROM items WHERE syncId > $afterSyncId LIMIT $batchSize'
  );
  
  return SyncBatchResult(
    items: items.map((i) => SyncPayload<ServerItem>(data: i)).toList(),
    checkpoint: items.isNotEmpty
        ? SyncCheckpoint(
            lastSyncId: items.last.syncId,
            updatedAt: items.last.updatedAt,
          )
        : null, // null = no more pages
  );
}
```

              afterId: lastMsg.syncId,

```dart
feroSync.backgroundSyncEventStream?.listen((event) {
  if (event is BackgroundSyncStartedEvent) {
    print('Started syncing ${event.featureKey}');
  } else if (event is BackgroundSyncCompletedEvent) {
    print('Completed syncing ${event.featureKey}');
  } else if (event is BackgroundSyncFailedEvent) {
    print('Failed syncing ${event.featureKey}: ${event.error}');
  }
});
```

### Custom Metadata Repository

Implement persistent storage for sync metadata:

```dart
class HiveSyncMetaDataRepo implements SyncMetaDataRepo {
  @override
  Future<SyncCheckpoint?> getCheckpoint(String featureKey) async {
    final box = await Hive.openBox('sync_metadata');
    final json = box.get('checkpoint_$featureKey');
    return json != null ? SyncCheckpoint.fromJson(json) : null;
  }

  @override
  Future<void> saveCheckpoint(String featureKey, SyncCheckpoint checkpoint) async {
    final box = await Hive.openBox('sync_metadata');
    await box.put('checkpoint_$featureKey', checkpoint.toJson());
  }
}
```

### UI Integration

**With StreamBuilder:**

```dart
StreamBuilder(
  stream: feroSync.backgroundSyncEventStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final event = snapshot.data;
      if (event is BackgroundSyncStartedEvent) {
        return CircularProgressIndicator();
      }
    }
    return Text('Synced');
  },
)
```

**With Riverpod:**

```dart
final syncEventsProvider = StreamProvider((ref) {
  return feroSync.backgroundSyncEventStream!;
});

// In your widget
ref.watch(syncEventsProvider).when(
  data: (event) => Text('Event: ${event.runtimeType}'),
  loading: () => CircularProgressIndicator(),
  error: (e, s) => Text('Error: $e'),
dart
// Fixed backoff: always wait 500ms between retries
final backoff = FixedBackoffStrategy(baseMillis: 500);

// Exponential backoff: starts at 100ms, doubles each retry, max 30s
final backoff = ExponentialBackoffStrategy(
  baseMillis: 100,
  maxMillis: 30000,
);
```

By default, `FeroSync.create()` uses exponential backoff with sensible defaults.

---

## Conflict Resolution

When the same item is modified locally and remotely, Fero resolves conflicts automatically:

```dart
ConflictResolutionStrategy.highestVersionWins  // Default
```

Resolution happens during sync based on:

* **Version numbers** (from your `Syncable` objects)
* **Configured strategy** (currently highest-version-wins)
* **Handler logic** (you decide what "winning" means to your data)

---

## Cancellation

```dart
// Stop ongoing sync operations
feroSync.cancel();
```

Useful when:

* User logs out mid-sync
* App goes to background
* User dismisses sync screen
* Network becomes unavailable

---

## Disposal

```dart
// Clean up all resources
feroSync.dispose();
```

Call when:

* Closing the sync feature
* App is shutting down
* User logs out

---

## Advanced: Custom Status Tracking

```dart
// Get status for a specific feature
final status = feroSync.getFeatureStatus('contacts');

// Listen to specific events
feroSync.eventStream
  .where((event) => event.featureKey == 'contacts')
  .listen((event) {
    debugPrint('Contacts event: $event');
  });
```

---

## What Fero Does NOT Do

* **No networking** — You implement network calls in your handlers
* **No database** — You handle local storage in your handlers
* **No platform channels** — Pure Dart, no native code
* **No UI components** — You build your sync UI with `StreamBuilder` or state management

Fero **only orchestrates sync logic** — your handlers do the heavy lifting.

---

## When to Use Fero in Flutter

**Use Fero if:**

* Your app has initial sync (users expect data on first launch)
* You need reliable retry logic
* Multiple features need independent sync handlers
* You want observable, loggable sync operations
* You need bidirectional sync (upload + download)

**Skip Fero if:**

* You only fetch data once (no sync needed)
* You use a real-time database (Firebase, Supabase, etc.)
* Sync is simple CRUD without conflict handling
* You prefer UI-driven data fetching

---

## Architecture & Design Philosophy

### Version-Based Ordering

Fero uses server-assigned versions instead of timestamps:

* **Deterministic**: Version X always comes before X+1
* **Server-centric**: No reliance on client clocks
* **Offline-friendly**: Works without network connectivity
* **Conflict-safe**: Unambiguous resolution when items conflict

### Separation of Concerns

```
┌─────────────────────────────────────┐
│         Your Flutter App             │
│  (UI, Widgets, Riverpod/Bloc)       │
└──────────────┬──────────────────────┘
               │
         ┌─────▼──────────┐
         │   FeroSync     │
         │ (Orchestration)│
         └─────┬──────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼────────────┐   ┌───▼────────────┐
│  SyncHandlers  │   │  SyncEvents &  │
│  (Your Logic)  │   │    Streams     │
└────────────────┘   └────────────────┘
```

**FeroSync** never touches your data — it only orchestrates calls to your handlers.

---

## Testing

Handlers are easy to test because they're pure business logic:

```dart
test('ContactsSyncHandler applies remote contacts', () async {
  final handler = ContactsSyncHandler(
    localDb: MockLocalDatabase(),
    remoteApi: MockRemoteApi(),
  );

  final result = await handler.applyToLocal([
    SyncPayload(
      data: Contact(
        id: '1',
        name: 'Alice',
        email: 'alice@example.com',
        version: 1,
      ),
    ),
  ]);

  expect(result.success, true);
});
```

---

## Project Structure

```
flutter/
├── lib/
│   ├── fero_sync.dart              # Main FeroSync class
│   └── core/
│       ├── sync_handler.dart       # SyncHandler contract & data classes
│       ├── backoff.dart            # Backoff strategies
│       ├── conflict_resolution.dart# Conflict resolution strategies
│       ├── sync_event.dart         # Event definitions
│       └── ...
│   └── initial_sync/
│       ├── initial_sync.dart       # InitialSyncManager (internal)
│       └── ...
├── test/
│   └── ...
├── pubspec.yaml
└── README.md
```

---

## API Reference

### FeroSync

```dart
// Factory constructor
static Future<FeroSync> create({
  required Map<String, SyncHandler> handlers,
  BackoffStrategy? backoffStrategy,
  ConflictResolutionStrategy? conflictStrategy,
}) async

// Lifecycle
Future<void> startSync()
Future<void> run()
void cancel()
void dispose()

// Events
void triggerInitialSync(String featureKey)
void emitSyncEvent(SyncEvent event)

// Status
dynamic getFeatureStatus(String featureKey)
Stream<dynamic> get statusStream
Stream<SyncEvent> get eventStream
```

---

## Roadmap

* ✅ Initial sync orchestration
* ✅ Version-based conflict resolution
* ✅ Retry & backoff strategies
* 🔄 Incremental sync support
* 🔄 Delta sync (only changed items)
* 🔄 Compression for large batches
* 🔄 Multi-device conflict resolution
* 🔄 Offline persistence
* 🔄 More conflict resolution strategies

---

## Migration Guide

If you're upgrading from an older version:

### Before (Old API)

```dart
await coordinator.runInitialIfNeeded('user_123', ['contacts']);
```

### After (New API)

```Architecture

Fero separates concerns into clear layers:


┌─────────────────────────────────────┐
│      Your Flutter App (UI)          │
│   StreamBuilder / Riverpod / Bloc   │
└──────────────┬──────────────────────┘
               │ Events
         ┌─────▼──────────┐
         │   FeroSync     │
         │ (Orchestrator) │
         └─────┬──────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼───────────┐   ┌────▼────────────┐
│ Initial Sync  │   │ Background Sync │
│ (First load)  │   │ (Incremental)   │
└───┬───────────┘   └────┬────────────┘
    │                    │
    └─────────┬──────────┘
              │
    ┌─────────▼─────────────┐
    │   Your Handlers       │
    │  (Business Logic)     │
    │  • fetchRemoteData    │
    │  • applyRemoteChanges │
    │  • pushLocalChanges   │
    └───────────────────────┘
```

### Design Principles

1. **Version-Based Ordering** - Use server-assigned versions (not timestamps) for deterministic conflict resolution
2. **Checkpoint Pagination** - Resume sync from exact point using monotonic syncId
3. **Type Safety** - Separate LocalItem and ServerItem types prevent bugs
4. **Pure Handlers** - Stateless, testable business logic
5. **Event-Driven** - Observable streams for UI updates

---

## What Fero Does NOT Do

- ❌ **No networking** - You implement API calls in handlers
- ❌ **No database** - You handle local storage (SQLite, Hive, etc.)
- ❌ **No platform channels** - Pure Dart, cross-platform
- ❌ **No UI widgets** - You build UI with streams

Fero **orchestrates sync logic** - you handle data storage and network calls.

---

## When to Use Fero

### ✅ Use Fero If:

- Your app needs offline-first sync
- You have initial data load requirements
- You need automatic conflict resolution
- Multiple features require coordinated sync
- You want testable, maintainable sync logic
- You need bidirectional sync (upload + download)

### ❌ Skip Fero If:

- You only fetch data once (no sync needed)
- You use real-time databases (Firebase, Supabase)
- Simple CRUD without conflicts
- You prefer UI-driven data fetching

---

## Testing

Handlers are pure business logic, easy to test:

```dart
test('ContactSyncHandler fetches remote changes', () async {
  final handler = ContactSyncHandler(db: mockDb, api: mockApi);
  
  when(mockApi.fetchContacts(afterSyncId: 0, limit: 50))
      .thenAnswer((_) async => [
        ServerContact(id: 'c1', name: 'Alice', syncId: 101, version: 1, updatedAt: DateTime.now()),
      ]);

  final result = await handler.fetchRemoteChanges(batchSize: 50);
  
  expect(result.items.length, 1);
  expect(result.checkpoint?.lastSyncId, 101);
});
```

---

## Examples

See [example/lib/main.dart](example/lib/main.dart) for a complete working example with:
- User preferences (initial sync)
- Contacts (background sync)
- Messages (background sync with dependencies)

---

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new features
4. Submit a pull request

---

## License

MIT License - see LICENSE file for details

---

## Support

- 📖 [Documentation](https://github.com/starsgathered/fero)
- 🐛 [Issue Tracker](https://github.com/starsgathered/fero/issues)
- 💬 [Discussions](https://github.com/starsgathered/fero/discussions)