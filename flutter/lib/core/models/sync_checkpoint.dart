import 'dart:convert';

class SyncCheckpoint {
  final BigInt lastSyncedId;
  final String lastSyncedAt;

  const SyncCheckpoint({
    required this.lastSyncedId,
    required this.lastSyncedAt,
  });

  /// Encode checkpoint to opaque cursor string
  String encode() {
    final jsonMap = {
      'lastSyncedId': lastSyncedId.toString(),
      'lastSyncedAt': lastSyncedAt,
    };
    return base64Encode(utf8.encode(jsonEncode(jsonMap)));
  }

  /// Decode from cursor string
  factory SyncCheckpoint.fromCursor(String cursor) {
    final decoded = utf8.decode(base64Decode(cursor));
    final map = jsonDecode(decoded) as Map<String, dynamic>;
    return SyncCheckpoint(
      lastSyncedId: BigInt.parse(map['lastSyncedId'] as String),
      lastSyncedAt: map['lastSyncedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'lastSyncedId': lastSyncedId.toString(),
        'lastSyncedAt': lastSyncedAt,
      };

  factory SyncCheckpoint.fromJson(Map<String, dynamic> json) => SyncCheckpoint(
        lastSyncedId: BigInt.parse(json['lastSyncedId'] as String),
        lastSyncedAt: json['lastSyncedAt'] as String,
      );

  @override
  String toString() =>
      'SyncCheckpoint(lastSyncedId: $lastSyncedId, lastSyncedAt: $lastSyncedAt)';
}
