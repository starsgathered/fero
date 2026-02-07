import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';

final DynamicLibrary _lib = Platform.isAndroid
    ? DynamicLibrary.open('libcore.so')
    : DynamicLibrary.process();

typedef _c_has = Uint8 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _dart_has = int Function(Pointer<Utf8>, Pointer<Utf8>);
final _dart_has _has = _lib.lookupFunction<_c_has, _dart_has>('fero_initial_sync_has_initial_sync');

typedef _c_run = Void Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _dart_run = void Function(Pointer<Utf8>, Pointer<Utf8>);
final _dart_run _run = _lib.lookupFunction<_c_run, _dart_run>('fero_initial_sync_run_initial_sync');

typedef _c_cancel = Void Function();
typedef _dart_cancel = void Function();
final _dart_cancel _cancel = _lib.lookupFunction<_c_cancel, _dart_cancel>('fero_initial_sync_cancel');

typedef _c_get_status = Uint32 Function();
typedef _dart_get_status = int Function();
final _dart_get_status _getStatus = _lib.lookupFunction<_c_get_status, _dart_get_status>('fero_initial_sync_get_status');

enum InitialSyncStatus { notStarted, running, completed, cancelled }

InitialSyncStatus _statusFromInt(int v) {
  switch (v) {
    case 1:
      return InitialSyncStatus.running;
    case 2:
      return InitialSyncStatus.completed;
    case 3:
      return InitialSyncStatus.cancelled;
    case 0:
    default:
      return InitialSyncStatus.notStarted;
  }
}

bool hasInitialSync(String userId, List<String> featureKeys) {
  final pUser = userId.toNativeUtf8();
  final pKeys = jsonEncode(featureKeys).toNativeUtf8();
  try {
    final res = _has(pUser, pKeys);
    return res != 0;
  } finally {
    malloc.free(pUser);
    malloc.free(pKeys);
  }
}

void runInitialSync(String userId, List<String> featureKeys) {
  final pUser = userId.toNativeUtf8();
  final pKeys = jsonEncode(featureKeys).toNativeUtf8();
  try {
    _run(pUser, pKeys);
  } finally {
    malloc.free(pUser);
    malloc.free(pKeys);
  }
}

void cancelInitialSync() {
  _cancel();
}

InitialSyncStatus getInitialSyncStatus() {
  final v = _getStatus();
  return _statusFromInt(v);
}
