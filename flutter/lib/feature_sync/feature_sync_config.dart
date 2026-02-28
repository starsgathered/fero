import 'package:fero_sync/feature_sync/feature_sync_handler.dart';

/// Configuration for a feature's sync behavior.
class FeatureSyncConfig {
  final FeatureSyncHandler handler;
  final List<String> dependencies;
  final int priority; // Higher = syncs first

  const FeatureSyncConfig({
    required this.handler,
    this.dependencies = const [],
    this.priority = 0,
  });
}
