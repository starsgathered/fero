import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/results/apply_error.dart';

/// --- ApplyResult ---
/// Result of trying to apply a batch of items (to local or remote storage)
/// Provides success flag and optional error details.
class ApplyResult {
  /// True if the operation succeeded
  final bool success;
  final List<SyncPayload<ServerItem>> pushedItems;

  /// List of errors for failed items
  final List<ApplyError> errors;

  ApplyResult({
    required this.success,
    required this.pushedItems,
    this.errors = const [],
  });

  /// Success factory
  factory ApplyResult.success([List<SyncPayload<ServerItem>> pushedItems = const []]) {
    return ApplyResult(success: true, pushedItems: pushedItems);
  }

  /// Failure factory
  factory ApplyResult.failure(List<ApplyError> errors) {
    return ApplyResult(success: false, errors: errors, pushedItems: []);
  }
}
