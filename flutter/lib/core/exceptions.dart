/// Sync-specific exception hierarchy for the sync package.
abstract class SyncException implements Exception {
  final String message;
  const SyncException(this.message);

  @override
  String toString() => '${runtimeType.toString()}: $message';
}

class SyncAlreadyRunningException extends SyncException {
  const SyncAlreadyRunningException(super.message);
}

class HandlerNotFoundException extends SyncException {
  const HandlerNotFoundException(super.message);
}

class InitialSyncFailedException extends SyncException {
  const InitialSyncFailedException(super.message);
}

class SyncFailedException extends SyncException {
  const SyncFailedException(super.message);
}

class MaxRetriesExceededException extends SyncException {
  const MaxRetriesExceededException(super.message);
}

class DLQPushException extends SyncException {
  const DLQPushException(super.message);
}

class MetadataPersistenceException extends SyncException {
  const MetadataPersistenceException(super.message);
}

class OperationCancelledException extends SyncException {
  const OperationCancelledException(super.message);
}
