import 'dart:math';

abstract class BackoffStrategy {
  int get type; // 0 = Fixed, 1 = Exponential
  int get baseMillis;
  int get maxMillis;
  Duration nextDelay(int attempt);
}

class FixedBackoffStrategy implements BackoffStrategy {
  @override
  final int baseMillis;

  FixedBackoffStrategy({required this.baseMillis});

  @override
  int get type => 0;

  @override
  int get maxMillis => baseMillis; // Fixed uses same value

  @override
  Duration nextDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;
    return Duration(milliseconds: baseMillis);
  }
}

class ExponentialBackoffStrategy implements BackoffStrategy {
  @override
  final int baseMillis;
  @override
  final int maxMillis;
  final Random _rnd = Random();

  ExponentialBackoffStrategy({
    required this.baseMillis,
    required this.maxMillis,
  });

  @override
  int get type => 1;

  @override
  Duration nextDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;

    final int exponential = (baseMillis * pow(2, attempt - 1)).toInt();
    final int capped = min(exponential, maxMillis);
    if (capped <= 0) return Duration.zero;

    final int half = capped ~/ 2;
    final int jitter = half + _rnd.nextInt(half + 1);

    return Duration(milliseconds: jitter);
  }
}

/// Reusable retry helper with backoff strategy.
/// Returns null if all retries fail or operation is cancelled.
class RetryPolicy {
  final BackoffStrategy backoff;
  final int maxRetries;

  RetryPolicy({
    required this.backoff,
    this.maxRetries = 3,
  });

  /// Attempt operation with retries and backoff.
  /// [isCancelled] optional callback to check for cancellation.
  Future<T?> attempt<T>(
    Future<T> Function() operation, {
    bool Function()? isCancelled,
  }) async {
    int attempt = 0;

    while (true) {
      if (isCancelled?.call() ?? false) return null;

      try {
        return await operation();
      } catch (_) {
        attempt++;
        if (attempt > maxRetries) return null;
        final delay = backoff.nextDelay(attempt);
        if (delay > Duration.zero) {
          await Future.delayed(delay);
        }
      }
    }
  }
}
