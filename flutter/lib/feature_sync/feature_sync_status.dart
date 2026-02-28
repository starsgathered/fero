import 'package:flutter/foundation.dart';

enum SyncProcessStatus {
  notStarted,
  running,
  completed,
  failed,
}

class FeatureSyncStatus {
  final String featureKey;
  final ValueNotifier<SyncProcessStatus> statusNotifier;
  final ValueNotifier<String?> errorNotifier;

  FeatureSyncStatus({required this.featureKey})
      : statusNotifier = ValueNotifier(SyncProcessStatus.notStarted),
        errorNotifier = ValueNotifier(null);

  void start() {
    statusNotifier.value = SyncProcessStatus.running;
    errorNotifier.value = null;
  }

  void complete() {
    statusNotifier.value = SyncProcessStatus.completed;
    errorNotifier.value = null;
  }

  void fail(String error) {
    statusNotifier.value = SyncProcessStatus.failed;
    errorNotifier.value = error;
  }
}
