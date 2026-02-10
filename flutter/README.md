# Fero (Flutter)

**Fero** is a **Flutter/Dart sync orchestration library** that helps you run **reliable initial sync flows** using a clean, policy-driven architecture.

It separates:

* **Sync execution** (your handlers)
* **Sync orchestration** (Fero)
* **Sync state** (metadata repository)

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

### SyncHandler

Feature-level sync logic written in Dart.

```dart
abstract class SyncHandler {
  Future<SyncResult> handle(SyncItem item);
}
```

Handlers:

* Are stateless
* Contain only business logic
* Do not know if sync is initial or incremental

---

### SyncItem

Execution context passed to handlers.

```dart
SyncItem(
  featureKey: 'contacts',
  userId: 'user_123',
);
```

There is **no mode flag**.
Sync type is determined by metadata and orchestration logic.

---

### SyncMetadataRepository

Persists sync state for Flutter apps.

Responsibilities:

* Track last sync timestamps
* Decide whether sync is required
* Enable metadata-driven policies

Includes an in-memory implementation for testing.

---

### InitialSyncManager

Runs first-time sync for one or more features.

Responsibilities:

* Check metadata
* Execute handlers sequentially
* Apply retry + backoff
* Emit lifecycle status via `Stream`

```dart
await initialSync.runInitialSync(userId, featureKeys);
```

---

### FeroCoordinator

Flutter-friendly entry point.

Responsibilities:

* Throttle sync calls
* Coordinate when initial sync should run
* Keep orchestration logic out of UI

```dart
await coordinator.runInitialIfNeeded(
  'user_123',
  ['contacts', 'messages'],
);
```

---

## Example Usage in Flutter

### 1. Define Feature Handlers

```dart
class ContactsSyncHandler implements SyncHandler {
  @override
  Future<SyncResult> handle(SyncItem item) async {
    await Future.delayed(const Duration(seconds: 1));
    return SyncResult.success();
  }
}
```

---

### 2. Configure Fero

```dart
final metadataRepo = InMemorySyncMetadataRepository();

final handlers = {
  'contacts': ContactsSyncHandler(),
  'messages': MessagesSyncHandler(),
};

final initialSync = InitialSyncManager(
  metadataRepo: metadataRepo,
  handlers: handlers,
);

final coordinator = FeroCoordinator(
  initialManager: initialSync,
  syncMetadataRepository: metadataRepo,
);
```

---

### 3. Trigger Initial Sync

```dart
await coordinator.runInitialIfNeeded(
  'user_123',
  ['contacts', 'messages'],
);
```

---

### 4. Listen to Sync Status (UI-friendly)

```dart
initialSync.statusStream.listen((status) {
  debugPrint('Initial Sync Status: $status');
});
```

Works cleanly with:

* `StreamBuilder`
* Riverpod `StreamProvider`
* Bloc events

---

## Retry & Backoff (Flutter-safe)

Initial sync retries are handled internally.

```dart
FixedBackoffStrategy(baseMillis: 500);
ExponentialBackoffStrategy(baseMillis: 1, maxMillis: 30);
```

Handlers stay retry-agnostic.

---

## Cancellation

```dart
initialSync.cancel();
```

Useful when:

* User logs out
* App goes to background
* Sync screen is dismissed

---

## What Fero Does NOT Do

* No networking
* No database
* No background services
* No platform channels
* No UI integration

Fero only **orchestrates**.

---

## When to Use Fero in Flutter

Use Fero if:

* Your app has a non-trivial initial sync
* You want retryable, observable sync logic
* You want to keep sync logic out of widgets
* You need clean separation of concerns

Skip Fero if:

* You only fetch data once
* Sync failures don’t matter
* You prefer UI-driven async flows

---

## Status

🚧 Active development
APIs may evolve before stable release.

---

## License

MIT License