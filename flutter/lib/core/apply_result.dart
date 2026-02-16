import 'package:fero_sync/core/apply_error.dart';

/// --- ApplyResult ---
/// Result of trying to apply a batch of items (to local or remote storage)
/// Provides success flag and optional error details.
class ApplyResult {
  /// True if the operation succeeded
  final bool success;

  /// List of errors for failed items
  final List<ApplyError> errors;

  ApplyResult({
    required this.success,
    this.errors = const [],
  });

  /// Success factory
  factory ApplyResult.success() {
    return ApplyResult(success: true);
  }

  /// Failure factory
  factory ApplyResult.failure(List<ApplyError> errors) {
    return ApplyResult(success: false, errors: errors);
  }
}
