# FeroSync

**FeroSync** is a **Flutter/Dart offline-first sync library** for reliable bidirectional data sync.
It handles **initial sync, incremental feature sync, conflict resolution, retry/backoff, and checkpointing**. Fero means circulate here and there to get data

---

## Features

* ✅ Initial Sync (first-time load)
* ✅ Feature Sync (incremental updates)
* ✅ Version-based Conflict Resolution
* ✅ Checkpoint Pagination
* ✅ Retry & Backoff (exponential/fixed)
* ✅ Event Streams for UI updates
* ✅ Feature Dependencies
* ✅ Type-safe separation of LocalItem & ServerItem

---

## Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  fero_sync: ^0.4.9
```

---

## Quick Start

```dart
import 'package:fero_sync/fero_sync.dart';

final localDb = <LocalMessage>[];

// Initialize FeroSync with initial + feature sync handlers
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

// Listen to initial sync status
feroSync.initialSyncNotifier.addListener(() {
  print("Initial Sync: ${feroSync.initialSyncNotifier.value}");
});

// Start initial sync
feroSync.startInitialSync();

// Listen to background/incremental sync
feroSync.featureSyncNotifier("messages")?.addListener(() {
  print("Background Sync Running...");
});

// Add a new message from UI
addMessageFromUI("Hello, world!", localDb, feroSync);
```

---

## Example

A full working example is available inside the repository:

[example/lib/main.dart](example/lib/main.dart)


The example demonstrates:

* Initial sync
* Incremental feature sync
* Local updates
* Server push simulation
* Conflict handling

---

## Key Concepts

* **Initial Sync**: Pulls full data for first-time setup.
* **Feature Sync**: Incrementally syncs local changes and server updates.
* **Handlers**: Define how to fetch, apply, and push data.
* **Metadata Repo**: Stores checkpoints & sync state for each feature.
* **Notifiers**: Listen to `initialSyncNotifier` or `featureSyncNotifier('featureKey')` for UI updates.

---

## Lifecycle Methods

```dart
feroSync.cancel();  // Stop ongoing sync
feroSync.dispose(); // Clean up resources
```

---

## Example Use Cases

✅ Offline-first apps<br/>
✅ Multi-feature sync with dependencies<br/>
✅ Apps needing reliable retry and conflict resolution<br/>

❌ Not suitable for one-time fetches or real-time DBs like Firebase/ Supabase

---

## Architecture Overview

```
            Flutter App (UI)
                   │
           FeroSync Orchestrator
                   │
  ┌────────────────┴─────────────────┐
  │  Initial Sync / Feature Sync     │
  │  (incremental background sync)   │
  └────────────────┬─────────────────┘
                   │
    Your Handlers (fetch/apply/push)
```

* Pure Dart, no platform dependencies
* Testable, maintainable, event-driven

---

## Documentation & Support

* 📖 [Full Documentation](https://pub.dev/packages/fero_sync/example)
* 🐛 Report bugs on [GitHub Issues](https://github.com/starsgathered/fero/issues)
* 💬 Discuss features on [GitHub Discussions](https://github.com/starsgathered/fero/discussions)
