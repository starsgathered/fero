/* --- Syncable Interfaces ---
Separate types for local and server items to ensure type safety.

LocalItem: Items created on device, may not have server-assigned syncId yet
ServerItem: Items from server, always have syncId assigned by server

This separation makes it clear which fields are guaranteed to exist.
*/

/// Base interface for syncable items with common fields
abstract class Syncable {
  /// Business identifier (user-facing, e.g., UUID)
  String get id;

  /// Current version of the item (server-assigned)
  int get version;
}

/// Items created locally - may not have server-assigned syncId yet
abstract class LocalItem implements Syncable {
  /// Whether this item has been modified locally and needs sync
  bool get locallyModified;
}

/// Items from server - always have syncId assigned by server
abstract class ServerItem implements Syncable {
  /// Sync identifier - guaranteed to exist (server-assigned, monotonic)
  BigInt get syncId;

  /// Last updated timestamp from server
  DateTime get updatedAt;
}
