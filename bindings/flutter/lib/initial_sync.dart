// initial_sync_manager.dart

import 'dart:ffi';

import 'package:fero/backoff.dart';
import 'package:fero/sync_handler.dart';
import 'package:fero/sync_item.dart';
import 'package:fero/sync_meta_data_repository.dart';
import 'package:fero/sync_result.dart';
import 'package:ffi/ffi.dart';

typedef CallRustNative =
    Void Function(
      Pointer<Void> handlerId,
      Pointer<Utf8> userId,
      // Uint8 backoffType,
      // Uint64 baseMillis,
      // Uint64 maxMillis,
    );

typedef CallRustDart =
    void Function(
      Pointer<Void> handlerId,
      Pointer<Utf8> userId,
      // int backoffType,
      // int baseMillis,
      // int maxMillis,
    );
typedef ReportResultNative = Void Function(Uint64 handlerId, Uint8 success);
typedef ReportResultDart = void Function(int handlerId, int success);
final dylib = DynamicLibrary.open("libcore.so");
final reportResultToRust = dylib
    .lookupFunction<ReportResultNative, ReportResultDart>('report_sync_result');
final callRust = dylib.lookupFunction<CallRustNative, CallRustDart>(
  'call_rust',
);

class InitialSyncManager {
  final SyncMetadataRepository syncMetadataRepository;
  final Map<String, SyncHandler> _handlers;
  final BackoffStrategy backoffStrategy;

  InitialSyncManager({
    required this.syncMetadataRepository,
    required Map<String, SyncHandler> handlers,
    required this.backoffStrategy,
  }) : _handlers = handlers;

  /// Run sync for all registered features for a user
  Future<void> runSync(String userId) async {
    for (final entry in _handlers.entries) {
      final featureKey = entry.key;

      final required = await syncMetadataRepository.isSyncRequired(
        userId: userId,
        featureKey: featureKey,
      );

      if (required) {
        print('[SDK] Sync required for $featureKey');

        // Instead of directly calling Dart, trigger Rust
        final handlerId = Pointer<Void>.fromAddress(
          featureKey.hashCode,
        ); // Use usize, not Utf8
        final userIdPtr = userId.toNativeUtf8();

        callRust(
          handlerId,
          userIdPtr,
          // backoffStrategy.type,
          // backoffStrategy.baseMillis,
          // backoffStrategy.maxMillis,
        );

        calloc.free(userIdPtr); // free userId only
      } else {
        print('[SDK] $featureKey is already up-to-date');
      }
    }
  }

  void triggerFromRust(Pointer<Void> handlerId, Pointer<Utf8> userId) {
    final featureKey = handlerId.address.toString();
    final userIdStr = userId.toDartString();

    final item = SyncItem(userId: userIdStr, featureKey: featureKey);

    // Execute Dart handler and report back to Rust
    executeHandler(item)
        .then((result) async {
          reportResultToRust(handlerId.address, result.success ? 1 : 0);
          await syncMetadataRepository.updateSyncTime(
            userId: userIdStr,
            featureKey: featureKey,
            syncTime: DateTime.now(),
          );
        })
        .catchError((_) {
          reportResultToRust(handlerId.address, 0);
        });
  }

  /// Called by Rust when it wants to execute a handler
  Future<SyncResult> executeHandler(SyncItem item) async {
    final handler = _handlers[item.featureKey];
    if (handler == null) {
      throw Exception("Something went wrong");
    }

    final syncItem = SyncItem(
      userId: item.userId,
      featureKey: item.featureKey,
    ); // Rust can pass feature if needed
    try {
      return await handler.handle(syncItem);
    } catch (e) {
      return SyncResult.failure();
    }
  }
}
