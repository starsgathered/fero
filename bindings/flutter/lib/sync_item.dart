/// A small DTO representing a sync unit.
class SyncItem {
  final String featureKey;
  final String userId;
  final Map<String, dynamic>? payload;

  SyncItem({required this.featureKey, required this.userId, this.payload});
}
