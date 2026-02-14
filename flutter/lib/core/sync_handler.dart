/// Represents a log event of a data change.
class LogEvent {
  final String id;
  final String operation; // 'create', 'update', 'delete'
  final Map<String, dynamic> data;
  final int version; // Primary ordering key (from Fero server)
  final DateTime timestamp; // Secondary (for analytics/UI only)

  LogEvent({
    required this.id,
    required this.operation,
    required this.data,
    required this.version,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Compare by version (primary) then timestamp (secondary fallback)
  /// Returns true if this event is newer than other
  bool isNewerThan(LogEvent other) {
    if (version != other.version) {
      return version > other.version;
    }
    // Fallback to timestamp if versions are equal
    return timestamp.isAfter(other.timestamp);
  }
}

/// Version information for sync state tracking.
/// Version is the primary ordering mechanism in Fero system.
/// 
/// Why versions instead of timestamps?
/// - Fero server is the source of truth - versions are server-assigned
/// - No clock skew issues (clients can have wrong time)
/// - Deterministic: version X is always before version X+1
/// - Works in distributed offline-first scenarios
/// - Timestamp is kept as secondary for analytics/UI only
class VersionInfo {
  final int version; // Primary: server-assigned version number
  final DateTime lastSyncAt; // Secondary: for UI/analytics

  VersionInfo({
    required this.version,
    DateTime? lastSyncAt,
  }) : lastSyncAt = lastSyncAt ?? DateTime.now();

  bool isNewerThan(VersionInfo other) => version > other.version;
  bool isAtLeast(VersionInfo other) => version >= other.version;
}

/// Merge result from comparing local and remote changes.
class MergeResult {
  final List<LogEvent> toApplyLocally;
  final List<LogEvent> toApplyRemotely;
  final bool hasConflicts;

  MergeResult({
    required this.toApplyLocally,
    required this.toApplyRemotely,
    this.hasConflicts = false,
  });
}

/// A feature-specific sync handler contract.
/// The user provides these callbacks to orchestrate synchronization.
/// Note: The SDK handles log storage internally - users don't manage logs directly.
/// Conflict resolution is handled by the SDK using the configured strategy.
abstract class SyncHandler {
  /// Get the current local version for this feature.
  /// Used to determine if sync is needed.
  Future<VersionInfo> getLocalVersion();

  /// Get the current remote version for this feature.
  /// Used to determine if sync is needed.
  Future<VersionInfo> getRemoteVersion();

  /// Apply remote log events to the local database.
  /// [events] are the changes that occurred remotely (determined by conflict strategy).
  /// After this completes, the SDK automatically logs these changes.
  Future<void> applyToLocalDatabase(List<LogEvent> events);

  /// Apply local log events to the remote database.
  /// [events] are the changes that occurred locally (determined by conflict strategy).
  /// After this completes, the SDK automatically logs these changes.
  Future<void> applyToRemoteDatabase(List<LogEvent> events);

  /// Update the local version marker after successful sync.
  /// [version] is the new version number.
  /// Called automatically by SDK after sync completes.
  Future<void> updateLocalSyncVersion(int version);

  /// Optional: Provide a readable name for this feature.
  /// Used in logging and analytics.
  String get featureName => runtimeType.toString();
}
