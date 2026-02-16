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
