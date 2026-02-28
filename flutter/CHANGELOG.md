# Changelog

## 0.1.0 - 2026-02-10
- Initial Flutter SDK release of Fero
- Added InitialSyncManager, FeroCoordinator, and core sync handlers

## 0.2.0 - 2026-02-10
- Added example folder demonstrating usage of Fero in a Flutter app

## 0.3.0 - 2026-02-10
- Change main parameter to make easy to use

## 0.4.0 - 2026-02-15
- **Major API refactoring**: Replaced `FeroCoordinator` with simplified `FeroSync` class
- **Added conflict resolution**: Introduced multiple conflict resolution strategies (server wins, client wins, merge both, highest version wins)
- **Added sync event system**: New event-based architecture for tracking sync lifecycle (InitialSyncRequired, Started, Completed, Failed events)
- **Enhanced sync handlers**: Improved `SyncHandler` with conflict resolution and versioning support
- **Improved initial sync**: Enhanced initial sync algorithm with queue-based processing
- **Breaking change**: Removed `sync_coordinator.dart` and `sync_meta_data_repository.dart` in favor of new architecture
- Updated example to demonstrate new API with conflict resolution and event handling

## 0.4.1 - 2026-02-15
- Updated example usage

## 0.4.2 - 2026-02-15
- Updated Readme.md

## 0.4.3 - 2026-02-15
- Added RetryConfig

## 0.4.4 - 2026-02-17
- Remove unnecessary code from InitialSyncManager

## 0.4.5 - 2026-02-20

- Improved initial sync robustness and cancellation handling.
- Fixed a status notifier leak when disposing the initial sync manager.
- Minor bug fixes in background sync and retry/backoff handling.
- Updated example and documentation to match API refactorings.
- Code cleanup and small performance improvements.

## 0.4.6 - 2026-02-28

- Minor bug fixes and stability improvements.
- Improved sync reliability and retry/backoff handling.
- Updated example and documentation to reflect latest API changes.
- Small performance optimizations and code cleanup.
