/// --- SyncCheckpoint ---
/// Represents the sync state checkpoint for pagination using an opaque cursor.
///
/// The cursor is an opaque string token (for example a syncId encoded as
/// string) provided by the server to resume pagination. Keeping it as a
/// string makes the checkpoint flexible and transport-agnostic.
class SyncCheckpoint {
  /// Opaque cursor token used to fetch the next page.
  final String cursor;

  const SyncCheckpoint({
    required this.cursor,
  });

  /// Create checkpoint from a syncable item's syncId.
  factory SyncCheckpoint.fromSyncable(String cursor) {
    return SyncCheckpoint(
      cursor: cursor,
    );
  }

  /// Serialize to map for storage
  Map<String, dynamic> toJson() {
    return {
      'cursor': cursor,
    };
  }

  /// Deserialize from stored map
  factory SyncCheckpoint.fromJson(Map<String, dynamic> json) {
    return SyncCheckpoint(
      cursor: json['cursor'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncCheckpoint &&
          runtimeType == other.runtimeType &&
          cursor == other.cursor;

  @override
  int get hashCode => cursor.hashCode;

  @override
  String toString() => 'SyncCheckpoint(cursor: $cursor)';
}
