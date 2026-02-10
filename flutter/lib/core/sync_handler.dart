import 'package:fero_sync/core/sync_item.dart';
import 'package:fero_sync/core/sync_result.dart';

/// A feature-specific sync handler contract.
abstract class SyncHandler {
  /// Perform the sync for the provided item.
  /// Returns a [SyncResult] describing success/failure.
  Future<SyncResult> handle(SyncItem item);
}
