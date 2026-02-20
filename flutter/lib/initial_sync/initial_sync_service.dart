/// Public interface for the initial sync service.
/// Manages event-driven synchronization with Fero's central server.
abstract class InitialSyncService {
  /// Run initial sync for all handlers.
  Future<void> run();

  /// Cancel ongoing initial sync operation.
  void cancel();

  /// Dispose and cleanup resources.
  void dispose();
}
