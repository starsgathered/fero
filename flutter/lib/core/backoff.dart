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
    final num exp = pow(2, attempt);
    final int baseMs = baseMillis;
    final int capMs = min(maxMillis, (baseMs * exp).toInt());
    if (capMs <= 0) return Duration.zero;
    final int ms = _rnd.nextInt(capMs + 1);
    return Duration(milliseconds: ms);
  }
}
