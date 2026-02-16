/* --- Syncable Interface ---
Any object that can be synced should implement this interface.
It ensures every syncable object has:
- `syncId`: unique identifier for the item
- `version`: current version of the item */
abstract class Syncable {
  String get syncId;
  int get version;
}
