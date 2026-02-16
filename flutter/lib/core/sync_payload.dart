import 'package:fero_sync/core/syncable.dart';

/// --- SyncPayload ---
/// Generic container for a feature's data and its version.
/// - `T` is the actual business data type, which must implement Syncable.
/// - Keeps metadata separate from your business data.
class SyncPayload<T extends Syncable> {
  final T data;

  SyncPayload({required this.data});
}
