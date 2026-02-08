abstract class BackoffStrategy {
  int get type; // 0 = Fixed, 1 = Exponential
  int get baseMillis;
  int get maxMillis;
}

class FixedBackoffStrategy implements BackoffStrategy {
  final int _baseMillis;

  FixedBackoffStrategy(this._baseMillis);

  @override
  int get type => 0;

  @override
  int get baseMillis => _baseMillis;

  @override
  int get maxMillis => _baseMillis; // Fixed uses same value
}

class ExponentialBackoffStrategy implements BackoffStrategy {
  final int _baseMillis;
  final int _maxMillis;

  ExponentialBackoffStrategy(this._baseMillis, this._maxMillis);

  @override
  int get type => 1;

  @override
  int get baseMillis => _baseMillis;

  @override
  int get maxMillis => _maxMillis;
}
