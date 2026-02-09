// initial_sync_manager.dart

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:fero/backoff.dart';
import 'package:fero/sync_handler.dart';
import 'package:fero/sync_item.dart';
import 'package:fero/sync_meta_data_repository.dart';
import 'package:fero/sync_result.dart';

/// ---------------- Native Library ----------------
final DynamicLibrary dylib = DynamicLibrary.open("libcore.so");

/// Rust callback typedefs
typedef RustCallbackNative = Void Function(Int32);
typedef RegisterCallbackNativeC =
    Void Function(Pointer<NativeFunction<RustCallbackNative>>);
typedef RegisterCallbackNativeDart =
    void Function(Pointer<NativeFunction<RustCallbackNative>>);

final RegisterCallbackNativeDart registerCallback =
    dylib
        .lookup<NativeFunction<RegisterCallbackNativeC>>('call_dart')
        .asFunction();

// Rust function: void rust_generate_numbers()
typedef RustGenerateNumbersC = Void Function();
typedef RustGenerateNumbersDart = void Function();

final RustGenerateNumbersDart rustGenerateNumbers =
    dylib
        .lookup<NativeFunction<RustGenerateNumbersC>>('rust_generate_numbers')
        .asFunction();

/// ---------------- Singleton Reference ----------------
InitialSyncManager? _singletonInstance;

/// Top-level function for Rust FFI
void _rustCallbackStatic(int number) {
  _singletonInstance?._handleRustNumber(number);
}

/// ---------------- InitialSyncManager ----------------
class InitialSyncManager {
  final SyncMetadataRepository _syncMetadataRepository;
  final Map<String, SyncHandler> _handlers;
  final BackoffStrategy _backoffStrategy;

  // Singleton instance accessor
  static InitialSyncManager? get instance => _singletonInstance;

  /// Private constructor
  InitialSyncManager._(
    this._syncMetadataRepository,
    this._handlers,
    this._backoffStrategy,
  ) {
    _singletonInstance = this;
    _registerRustCallback();
    // 3. Call Rust to generate numbers
    rustGenerateNumbers();
  }

  /// Factory constructor for singleton
  factory InitialSyncManager({
    required SyncMetadataRepository syncMetadataRepository,
    required Map<String, SyncHandler> handlers,
    required BackoffStrategy backoffStrategy,
  }) {
    return _singletonInstance ??
        InitialSyncManager._(syncMetadataRepository, handlers, backoffStrategy);
  }

  /// ---------------- Rust Callback Registration ----------------
  void _registerRustCallback() {
    final pointer = Pointer.fromFunction<RustCallbackNative>(
      _rustCallbackStatic, // ✅ top-level static function
    );
    registerCallback(pointer); // Only register once
  }

  /// ---------------- Handle Rust callback ----------------
  void _handleRustNumber(int number) {
    print("⚡ Flutter received number from Rust: $number");

    // Optional: route number to specific handler logic here
  }

  /// ---------------- Trigger from Rust with handlerId ----------------
  void triggerFromRust(Pointer<Utf8> handlerId, Pointer<Utf8> userId) async {
    final featureKey = handlerId.toDartString();
    final user = userId.toDartString();

    final item = SyncItem(userId: user, featureKey: featureKey);
    final result = await executeHandler(item);

    if (result.success) {
      await _syncMetadataRepository.updateSyncTime(
        userId: user,
        featureKey: featureKey,
        syncTime: DateTime.now(),
      );
    }
  }

  /// ---------------- Execute Handler ----------------
  Future<SyncResult> executeHandler(SyncItem item) async {
    final handler = _handlers[item.featureKey];
    if (handler == null) return SyncResult.failure();

    try {
      return await handler.handle(item);
    } catch (_) {
      return SyncResult.failure();
    }
  }

  /// ---------------- Run Sync ----------------
  Future<void> runSync(String userId) async {
    for (final entry in _handlers.entries) {
      final featureKey = entry.key;

      final required = await _syncMetadataRepository.isSyncRequired(
        userId: userId,
        featureKey: featureKey,
      );

      if (!required) continue;

      final handlerPtr = featureKey.toNativeUtf8();
      final userPtr = userId.toNativeUtf8();

      // TODO: call Rust function if needed
      // callRust(handlerPtr, userPtr, ...);

      calloc.free(handlerPtr);
      calloc.free(userPtr);
    }
  }
}
