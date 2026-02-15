# Fero (Flutter)

**Fero** is a **Flutter/Dart sync orchestration library** that helps you run **reliable, bidirectional sync flows** using a clean, version-based conflict resolution architecture.

Fero separates concerns:

* **Sync execution** (your handlers implementing `SyncHandler`)
* **Sync orchestration** (Fero's `FeroSync` class)
* **Versioning & conflict resolution** (built-in version-tracking semantics)

So your Flutter app code stays simple, testable, and predictable.

---

## What Problem Fero Solves

In Flutter apps, initial sync logic often becomes:

* Scattered across screens
* Tightly coupled to UI lifecycle
* Hard to retry or cancel
* Difficult to test

Fero centralizes this logic into a **single orchestration layer**.

---

## Flutter-Specific Design

Fero is designed around **Flutter async patterns**:

* `Future`-based execution
* `Stream`-based status updates
* Pure Dart handlers
* No isolates, no platform channels
* Works with Riverpod / Bloc / Provider

---

## Core Concepts

### Syncable

Base interface for any object that can be synced.

```dart
abstract class Syncable {
  String get syncId;      // Unique identifier for the item
  int get version;        // Server-assigned version number
}
```

Every syncable object must have:

* **syncId**: Unique identifier for ordering and conflict detection
* **version**: Server-assigned version for deterministic ordering and conflict resolution

Why versions instead of timestamps?
* Server is the source of truth
* Deterministic ordering (version X always comes before version X+1)
* Works offline-first and in distributed scenarios
* Enables reliable conflict resolution

---

### SyncPayload

Generic container for feature data and metadata.

```dart
class SyncPayload<T extends Syncable> {
  final T data;
  
  SyncPayload({required this.data});
}
```

Keeps business data separate from sync orchestration concerns.

---

### SyncBatchResult

Result of fetching a batch of items from remote or local storage.

```dart
class SyncBatchResult {
  final List<SyncPayload<Syncable>> items;
  final String? nextCursor;  // For pagination
  
  SyncBatchResult({
    required this.items,
    this.nextCursor,
  });
}
```

---

### ApplyResult

Result of applying changes to local or remote storage.

```dart
class ApplyResult {
  final bool success;
  final List<ApplyError> errors;
  
  ApplyResult({
    required this.success,
    this.errors = const [],
  });
}
```

Provides detailed error information for failed items.

---

### SyncHandler

Contract for implementing feature-specific sync logic.

```dart
abstract class SyncHandler {
  /// Get all local items for this feature
  Future<List<SyncPayload<Syncable>>> getLocal();

  /// Get the last sync cursor (null if never synced)
  Future<String?> getLastSyncCursor();

  /// Update the last sync cursor after successful sync
  Future<void> updateLastSyncCursor(String cursor);

  /// Fetch remote items with optional pagination
  Future<SyncBatchResult> getRemote({String? cursor});

  /// Apply remote items to local storage
  Future<ApplyResult> applyToLocal(List<SyncPayload<Syncable>> remoteStates);

  /// Apply local items to remote storage
  Future<ApplyResult> applyToRemote(List<SyncPayload<Syncable>> localStates);
}
```

Handlers:

* Are **stateless** and reusable
* Contain only **business logic**
* Never modify sync state directly
* Can be tested independently

---

### ConflictResolutionStrategy

Determines how to handle conflicting versions between local and remote.

```dart
enum ConflictResolutionStrategy {
  highestVersionWins,  // Remote data with higher version wins
  // More strategies coming soon
}
```

Applied automatically during sync orchestration.

---

### BackoffStrategy

Controls retry behavior for failed sync operations.

```dart
// Fixed backoff: always wait the same duration
FixedBackoffStrategy(baseMillis: 500)

// Exponential backoff: double wait time after each retry
ExponentialBackoffStrategy(baseMillis: 100, maxMillis: 30000)
```

---

### FeroSync

Main orchestrator for running sync operations.

```dart
final feroSync = await FeroSync.create(
  handlers: {
    'contacts': ContactsSyncHandler(),
    'messages': MessagesSyncHandler(),
  },
  backoffStrategy: ExponentialBackoffStrategy(
    baseMillis: 100,
    maxMillis: 30000,
  ),
  conflictStrategy: ConflictResolutionStrategy.highestVersionWins,
);
```

Responsibilities:

* Orchestrates sync across multiple features
* Applies retry and backoff strategies
* Resolves conflicts using configured strategy
* Emits status and event streams for UI or logging
* Manages lifecycle (start, run, cancel, dispose)

---

## Example Usage in Flutter

### 1. Define a Syncable Data Model

Your business objects must implement `Syncable`:

```dart
class Contact implements Syncable {
  final String id;
  final String name;
  final String email;
  final int version;

  Contact({
    required this.id,
    required this.name,
    required this.email,
    required this.version,
  });

  @override
  String get syncId => id;

  @override
  int get version => version;
}
```

---

### 2. Implement a SyncHandler

Implement all six methods required by `SyncHandler`:

```dart
class ContactsSyncHandler implements SyncHandler {
  final LocalDatabase localDb;
  final RemoteApi remoteApi;

  ContactsSyncHandler({
    required this.localDb,
    required this.remoteApi,
  });

  @override
  Future<List<SyncPayload<Syncable>>> getLocal() async {
    final contacts = await localDb.getContacts();
    return contacts
        .map((c) => SyncPayload(data: c))
        .toList();
  }

  @override
  Future<String?> getLastSyncCursor() async {
    return await localDb.getContactsSyncCursor();
  }

  @override
  Future<void> updateLastSyncCursor(String cursor) async {
    await localDb.saveContactsSyncCursor(cursor);
  }

  @override
  Future<SyncBatchResult> getRemote({String? cursor}) async {
    final batch = await remoteApi.fetchContacts(cursor: cursor);
    return SyncBatchResult(
      items: batch.contacts
          .map((c) => SyncPayload(data: c))
          .toList(),
      nextCursor: batch.nextCursor,
    );
  }

  @override
  Future<ApplyResult> applyToLocal(
    List<SyncPayload<Syncable>> remoteStates,
  ) async {
    try {
      final contacts = remoteStates
          .map((p) => p.data as Contact)
          .toList();
      await localDb.saveContacts(contacts);
      return ApplyResult.success();
    } catch (e) {
      return ApplyResult.failure([
        ApplyError(
          message: 'Failed to save contacts: $e',
          code: 'SAVE_ERROR',
        ),
      ]);
    }
  }

  @override
  Future<ApplyResult> applyToRemote(
    List<SyncPayload<Syncable>> localStates,
  ) async {
    try {
      final contacts = localStates
          .map((p) => p.data as Contact)
          .toList();
      await remoteApi.uploadContacts(contacts);
      return ApplyResult.success();
    } catch (e) {
      return ApplyResult.failure([
        ApplyError(
          message: 'Failed to upload contacts: $e',
          code: 'UPLOAD_ERROR',
        ),
      ]);
    }
  }
}
```

---

### 3. Create and Configure FeroSync

```dart
final feroSync = await FeroSync.create(
  handlers: {
    'contacts': ContactsSyncHandler(
      localDb: database,
      remoteApi: apiClient,
    ),
    'messages': MessagesSyncHandler(
      localDb: database,
      remoteApi: apiClient,
    ),
  },
  backoffStrategy: ExponentialBackoffStrategy(
    baseMillis: 100,
    maxMillis: 30000,
  ),
  conflictStrategy: ConflictResolutionStrategy.highestVersionWins,
);
```

---

### 4. Start Sync

```dart
// Start listening to events internally
await feroSync.startSync();

// Run the initial sync for all features
await feroSync.run();
```

---

### 5. Listen to Status Updates (UI-friendly)

```dart
// Listen to status changes
feroSync.statusStream.listen((status) {
  debugPrint('Sync Status: $status');
});

// Listen to raw events for logging
feroSync.eventStream.listen((event) {
  debugPrint('Sync Event: $event');
});
```

Use with Flutter widgets:

```dart
StreamBuilder<dynamic>(
  stream: feroSync.statusStream,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Text('Syncing...');
    }
    return const Text('Sync Complete');
  },
)
```

Or with Riverpod:

```dart
final syncStatusProvider = StreamProvider((ref) {
  return feroSync.statusStream;
});
```

---

### 6. Trigger Sync for Specific Features

```dart
// Manually trigger initial sync for a feature
feroSync.triggerInitialSync('contacts');

// Emit a custom sync event
feroSync.emitSyncEvent(InitialSyncRequiredEvent(featureKey: 'messages'));
```

---

### 7. Cancel and Dispose

```dart
// Cancel ongoing sync operations
feroSync.cancel();

// Clean up resources
feroSync.dispose();
```

---

## Retry & Backoff Strategy

Retries are automatic and configurable:

```dart
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
* **No background services** — Use `WorkManager` or `Workmanager` package for background sync
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

```dart
final feroSync = await FeroSync.create(handlers: {...});
await feroSync.startSync();
await feroSync.run();
```

Key changes:

* Use `FeroSync.create()` instead of `FeroCoordinator`
* Implement all 6 methods in `SyncHandler` (not just `handle()`)
* Use `Syncable` instead of `SyncItem`
* Use `SyncPayload<T>` for data containers
* Version numbers are now required (not timestamps)

---

## Status

🚧 Active development
APIs may evolve before stable release.

---

## License

MIT License
