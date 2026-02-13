/// A small DTO representing a sync unit.
class SyncItem {
  final String featureKey;
  final Map<String, dynamic>? payload;

  SyncItem({required this.featureKey, this.payload});
}
