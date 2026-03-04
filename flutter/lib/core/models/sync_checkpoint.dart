class SyncCheckpoint {
  final BigInt lastSyncedId;
  final String lastSyncedAt;

  const SyncCheckpoint({
    required this.lastSyncedId,
    required this.lastSyncedAt,
  });

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
