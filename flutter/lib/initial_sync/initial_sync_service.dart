import 'package:fero_sync/core/events/sync_event.dart';

/// Public interface for the initial sync service.
/// Manages event-driven synchronization with Fero's central server.
abstract class InitialSyncService {
  /// Stream of sync events (from server and local operations).
  Stream<SyncEvent> get eventStream;

  /// Run initial sync for all handlers.
  Future<void> run();

  /// Listen to incoming sync events from Fero server.
  /// This should be called once during app initialization.
  Future<void> startListeningToEvents();

  /// Manually emit a sync event (useful for testing or advanced scenarios).
  void emitEvent(SyncEvent event);

  /// Cancel ongoing initial sync operation.
  void cancel();

  /// Dispose and cleanup resources.
  void dispose();
}
