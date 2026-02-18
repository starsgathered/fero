import 'package:fero_sync/policies/backoff.dart';
import 'package:fero_sync/core/exceptions.dart';
import 'package:fero_sync/core/models/sync_payload.dart';
import 'package:fero_sync/core/models/syncable.dart';
import 'package:fero_sync/core/models/sync_checkpoint.dart';
import 'package:fero_sync/core/results/sync_batch_result.dart';
import 'package:fero_sync/core/results/apply_result.dart';

/// Common pagination and batch execution logic shared across sync managers.
///
/// - handles only the orchestration of paginated sync operations with retry logic.
/// - extensible through function parameters.
class SyncExecutor {
  final RetryPolicy retryPolicy;

  SyncExecutor({required this.retryPolicy});

  /// Execute paginated sync with checkpoint-based pagination (for background sync).
  ///
  /// [fetchBatch] - Function to fetch a batch of items given a checkpoint
  /// [applyBatch] - Function to apply a batch of items locally
  /// [onBatchComplete] - Optional callback after each batch is processed
  /// [isCancelled] - Function to check if operation should be cancelled
  /// [initialCheckpoint] - Starting checkpoint for pagination
  Future<void> executePaginatedSync({
    required Future<SyncBatchResult> Function(SyncCheckpoint? checkpoint)
        fetchBatch,
    required Future<ApplyResult> Function(List<SyncPayload<ServerItem>>)
        applyBatch,
    required String featureKey,
    void Function(SyncCheckpoint? checkpoint)? onBatchComplete,
    bool Function()? isCancelled,
    SyncCheckpoint? initialCheckpoint,
  }) async {
    SyncCheckpoint? checkpoint = initialCheckpoint;

    while (true) {
      // Check cancellation
      if (isCancelled?.call() ?? false) {
        throw OperationCancelledException('Sync cancelled during pagination');
      }

      // Fetch batch with retry
      final batchResult = await retryPolicy.attempt(
        () async {
          final result = await fetchBatch(checkpoint);
          if (!result.success) {
            throw SyncFailedException(
                'Failed fetch batch: ${result.errorMessage ?? "unknown"}');
          }
          return result;
        },
      );

      if (batchResult == null) {
        throw MaxRetriesExceededException(
          'Failed to fetch batch for feature: $featureKey',
        );
      }

      if (isCancelled?.call() ?? false) {
        throw OperationCancelledException('Sync cancelled after fetch');
      }
      if (batchResult.items.isEmpty) {
        // No items in this batch, end pagination
        break;
      }
      // Apply batch if not empty
      final applyResult = await applyBatch(batchResult.items);
      if (!applyResult.success) {
        throw SyncFailedException(
          'Failed to apply batch for feature: $featureKey. '
          'Errors: ${applyResult.errors.map((e) => e.message).join(', ')}',
        );
      }

      // Update checkpoint
      if (batchResult.checkpoint != null) {
        checkpoint = batchResult.checkpoint;
        onBatchComplete?.call(checkpoint);
      }
    }
  }
}
