import 'dart:async';
import 'dart:collection';

/// Status for a `SyncTask`.
enum SyncTaskStatus { pending, inProgress, completed, failed }

/// Represents a synchronization task in the queue
class SyncTask {
  final String featureKey;
  final Map<String, dynamic> data;
  final DateTime enqueuedAt;
  final SyncTaskStatus status;

  SyncTask({
    required this.featureKey,
    required this.data,
    DateTime? enqueuedAt,
    this.status = SyncTaskStatus.pending,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();

  @override
  String toString() =>
      'SyncTask(featureKey: $featureKey, status: $status, enqueuedAt: $enqueuedAt)';
}

/// Abstract repository for queue-based synchronization
abstract class SyncQueueRepository {
  /// Enqueue a sync task for processing
  Future<void> enqueue(SyncTask task);

  /// Dequeue the next sync task for processing
  /// Returns `null` if the queue is empty
  Future<SyncTask?> dequeue();

  /// Peek at the next task without removing it
  /// Returns `null` if the queue is empty
  Future<SyncTask?> peek();

  /// Check if the queue is empty
  Future<bool> isEmpty();

  /// Get the current queue size
  Future<int> size();

  /// Clear all tasks from the queue
  Future<void> clear();

  /// Get all tasks for a specific feature key
  Future<List<SyncTask>> getTasksByFeature(String featureKey);

  /// Remove all tasks for a specific feature key
  Future<int> removeTasksByFeature(String featureKey);
}

/// In-memory implementation of `SyncQueueRepository` using a queue
class InMemorySyncQueueRepository implements SyncQueueRepository {
  final Queue<SyncTask> _queue = Queue();

  @override
  Future<void> enqueue(SyncTask task) async {
    _queue.add(task);
  }

  @override
  Future<SyncTask?> dequeue() async {
    if (_queue.isEmpty) return null;
    return _queue.removeFirst();
  }

  @override
  Future<SyncTask?> peek() async {
    if (_queue.isEmpty) return null;
    return _queue.first;
  }

  @override
  Future<bool> isEmpty() async {
    return _queue.isEmpty;
  }

  @override
  Future<int> size() async {
    return _queue.length;
  }

  @override
  Future<void> clear() async {
    _queue.clear();
  }

  @override
  Future<List<SyncTask>> getTasksByFeature(String featureKey) async {
    return _queue.where((task) => task.featureKey == featureKey).toList();
  }

  @override
  Future<int> removeTasksByFeature(String featureKey) async {
    final initialSize = _queue.length;
    _queue.removeWhere((task) => task.featureKey == featureKey);
    return initialSize - _queue.length;
  }
}
