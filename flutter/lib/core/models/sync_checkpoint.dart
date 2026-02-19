/// --- SyncCheckpoint ---
/// Represents the sync state checkpoint for pagination.
///
/// Uses the monotonic syncId for deterministic ordering and resumable pagination.
/// This approach ensures:
/// 1. Consistent ordering using monotonically increasing IDs
/// 2. Ability to resume from exact point after interruption
/// 3. Simple and efficient pagination (WHERE syncId > afterId)
///
/// Immutable value object following clean architecture principles.
class SyncCheckpoint {
  /// Fetch items AFTER this ID. Query: WHERE syncId > afterId
  /// Example: afterId=100 → fetch items 101, 102, 103...
  final BigInt afterId;

  const SyncCheckpoint({
    required this.afterId,
  });

  /// Create checkpoint from a syncable item
  factory SyncCheckpoint.fromSyncable(BigInt syncId) {
    return SyncCheckpoint(
      afterId: syncId,
    );
  }

  /// Serialize to map for storage
  Map<String, dynamic> toJson() {
    return {
      'afterId': afterId.toString(),
    };
  }

  /// Deserialize from stored map
  factory SyncCheckpoint.fromJson(Map<String, dynamic> json) {
    return SyncCheckpoint(
      afterId: BigInt.parse(json['afterId'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncCheckpoint &&
          runtimeType == other.runtimeType &&
          afterId == other.afterId;

  @override
  int get hashCode => afterId.hashCode;

  @override
  String toString() => 'SyncCheckpoint(afterId: $afterId)';
}
