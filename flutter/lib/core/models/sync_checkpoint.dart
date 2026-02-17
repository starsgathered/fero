/// --- SyncCheckpoint ---
/// Represents the sync state checkpoint for pagination.
///
/// Uses the monotonic syncId for deterministic ordering and resumable pagination.
/// This approach ensures:
/// 1. Consistent ordering using monotonically increasing IDs
/// 2. Ability to resume from exact point after interruption
/// 3. Simple and efficient pagination (WHERE syncId > lastSyncId)
///
/// Immutable value object following clean architecture principles.
class SyncCheckpoint {
  /// The syncId of the last synced item (monotonic identifier)
  final int lastSyncId;

  /// Last updated timestamp from the checkpoint
  final DateTime updatedAt;

  const SyncCheckpoint({
    required this.lastSyncId,
    required this.updatedAt,
  });

  /// Create checkpoint from a syncable item
  factory SyncCheckpoint.fromSyncable(int syncId, DateTime updatedAt) {
    return SyncCheckpoint(
      lastSyncId: syncId,
      updatedAt: updatedAt,
    );
  }

  /// Serialize to map for storage
  Map<String, dynamic> toJson() {
    return {
      'lastSyncId': lastSyncId,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Deserialize from stored map
  factory SyncCheckpoint.fromJson(Map<String, dynamic> json) {
    return SyncCheckpoint(
      lastSyncId: json['lastSyncId'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncCheckpoint &&
          runtimeType == other.runtimeType &&
          lastSyncId == other.lastSyncId &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(lastSyncId, updatedAt);

  @override
  String toString() =>
      'SyncCheckpoint(lastSyncId: $lastSyncId, updatedAt: $updatedAt)';
}
