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
