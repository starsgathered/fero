# FeroSync

**FeroSync** is a **Flutter/Dart offline-first sync library** for bidirectional data sync with conflict resolution, retry logic, and pagination.  
*Fero* means "circulate" — move data here and there reliably.

---

## Features

- ✅ Initial Sync (first-time load)
- ✅ Feature Sync (incremental updates)
- ✅ Version-based Conflict Resolution
- ✅ Checkpoint Pagination
- ✅ Retry & Backoff (exponential or fixed)
- ✅ Event Streams for UI
- ✅ Feature Dependencies
- ✅ Type-Safe (LocalItem & ServerItem separation)

---

## Quick Start

```yaml
dependencies:
  fero_sync: ^0.4.6
```

```dart
final feroSync = await FeroSync.create(
  initialSyncConfigs: {
    'user_preferences': FeatureInitialSyncConfig(handler: UserPreferencesInitialSyncHandler(), priority: 100),
  },
  featureSyncConfigs: {
    'contacts': FeatureSyncConfig(handler: ContactSyncHandler(), priority: 100),
    'messages': FeatureSyncConfig(handler: MessageSyncHandler(), priority: 90, dependencies: ['contacts']),
  },
  metadataRepo: InMemorySyncMetaDataRepo(),
);
await feroSync.startSync();
```

* Listen to **initial sync status**: `feroSync.initialSyncNotifier`
* Listen to **feature-level background sync**: `feroSync.featureSyncNotifier('contacts')`
* Listen to **all sync events**: `feroSync.featureSyncNotifier`

---

## When to Use

✅ Apps with offline-first sync and bidirectional updates
✅ Multi-feature sync with dependencies
✅ Reliable retry and conflict resolution

❌ Not for simple one-time fetches or real-time DBs (Firebase, Supabase, etc.)

---

## Example

See [example/lib/main.dart](example/lib/main.dart) for a working demo with:

* User Preferences (initial sync)
* Contacts (background sync)
* Messages (background sync with dependencies)

---

## Lifecycle

```dart
feroSync.cancel();  // Stop ongoing sync
feroSync.dispose(); // Clean resources
```

---

## Architecture

```
Flutter App (UI)
       │
   FeroSync Orchestrator
       │
 ┌─────┴─────┐
 │Initial Sync│ Feature Sync (incremental sync)
 └─────┬─────┘
       │
   Your Handlers (fetchRemoteData, applyRemoteChanges, pushLocalChanges)
```

* Pure Dart, no UI or platform dependencies
* Testable, maintainable, event-driven handlers

---

## Docs & Support

* 📖 [Full Documentation](https://pub.dev/packages/fero_sync/example)
* 🐛 Found a bug or issue? Please post it on GitHub [Issues](https://github.com/starsgathered/fero/issues)
* 💬 [Discussions](https://github.com/starsgathered/fero/discussions)