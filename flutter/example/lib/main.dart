import 'dart:async';

import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/fero_sync.dart';
import 'package:fero_sync/initial_sync/initial_sync_status.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// FEROSYNC EXAMPLE - BEGINNER'S GUIDE
/// ============================================================================
///
/// This example demonstrates how to use FeroSync to keep your app's data
/// synchronized with a server. Here's how it works:
///
/// 1. **Data Models** - Define what data you want to sync (Contacts, Notes, etc.)
/// 2. **Sync Handlers** - Create handlers that know how to:
///    - Read data from your local database (getLocal)
///    - Fetch data from your server (getRemote)
///    - Save server data locally (applyToLocal)
///    - Upload local changes to server (applyToRemote)
/// 3. **Initialize FeroSync** - Register all your handlers
/// 4. **Run Sync** - Call feroSync.run() to sync everything!
///
/// --- VISUAL FLOW ---
///
/// When you call feroSync.run():
///
///   📱 Your Phone          FeroSync Engine          ☁️  Server
///   ─────────────          ───────────────          ──────────
///        │                       │                       │
///   1.   │──getLocal()──────────>│                       │
///        │<─[Contact v1]─────────│                       │
///        │                       │                       │
///   2.   │                       │───getRemote()────────>│
///        │                       │<─[Contact v3]─────────│
///        │                       │                       │
///   3.   │                   [Compares:                  │
///        │                    v3 > v1, server wins]      │
///        │                       │                       │
///   4.   │<─applyToLocal()───────│                       │
///        │   [Save v3]           │                       │
///        │                       │                       │
///   ✅   │     [Sync Complete!]  │                       │
///
/// --- GLOSSARY ---
///
/// 📖 **Syncable**: An interface your data models implement to work with FeroSync.
///    Requires: syncId (unique ID) and version (number for conflict resolution)
///
/// 📖 **SyncPayload**: A wrapper around your data. Think of it as an envelope that
///    carries your Contact/Note through the sync process. You create it like:
///    `SyncPayload<Syncable>(data: myContact)`
///
/// 📖 **Version**: A number that increases each time an item is updated.
///    Example: You edit a contact → version goes from 5 to 6.
///    Higher version = newer data. Used to resolve conflicts.
///
/// 📖 **Cursor**: A bookmark for pagination. Like saying "give me items after #100".
///    The server returns a cursor, and you pass it back to get the next page.
///    If cursor is null, you're fetching from the beginning.
///
/// 📖 **Conflict Resolution**: What happens when local and server have different
///    versions of the same item. Strategy determines which one wins.
///    - highestVersionWins: Newer version always wins (most common)
///    - localWins: Your device's version always wins
///    - remoteWins: Server's version always wins
///
/// 📖 **Backoff Strategy**: How long to wait before retrying after an error.
///    Exponential: Wait 100ms, then 200ms, then 400ms, etc. (prevents hammering server)
///
/// --- ICON LEGEND ---
///
/// 📱 = Local device operations (reading/writing to your app's database)
/// ☁️  = Server operations (fetching/uploading to your backend)
/// 💾 = Saving data
/// ✅ = Success!
/// ============================================================================

/// --- Example Data Models ---

/// Represents a contact in your app.
///
/// Implements [Syncable] to make it compatible with FeroSync.
/// The Syncable interface requires TWO things:
///
/// 1. `syncId`: A unique identifier (like "contact_123" or just the id)
///    - Must be unique across all contacts
///    - Never changes for the same contact
///
/// 2. `version`: A number that increases with each edit
///    - First created: version = 1
///    - Edit the name: version = 2
///    - Edit the email: version = 3
///    - FeroSync uses this to know which data is newest
///
/// 💡 Real-world example:
/// - You edit Alice's email offline → local version becomes 4
/// - Server has Alice's data at version 6 (edited by someone else)
/// - When syncing: version 6 > version 4, so server wins
/// - Your local data is updated to version 6
class Contact implements Syncable {
  final String id;
  final String name;
  final String email;

  /// Version number for conflict resolution
  /// Higher version = more recent update
  @override
  final int version;

  /// Unique identifier used by the sync system
  @override
  String get syncId => id;

  Contact({
    required this.id,
    required this.name,
    required this.email,
    required this.version,
  });
}

/// Represents a note in your app.
///
/// Also implements [Syncable] just like Contact.
/// You can make any of your data models syncable by implementing this interface.
class Note implements Syncable {
  final String id;
  final String content;

  @override
  final int version;

  @override
  String get syncId => id;

  Note({required this.id, required this.content, required this.version});
}

/// --- Concrete Handlers ---

/// Handler for syncing contacts from the server.
///
/// A SyncHandler tells FeroSync how to sync a specific type of data.
/// Think of it as a bridge between FeroSync and your app's database/API.
///
/// You implement 6 methods (grouped by purpose):
///
/// 📋 CURSOR METHODS (for pagination/incremental sync):
/// 1. **getLastSyncCursor()** - "Where did we stop last time?"
///    Returns: null (first sync) or "item_100" (continue from item 100)
///
/// 2. **updateLastSyncCursor()** - "Remember where we stopped this time"
///    Saves: "item_200" so next sync starts there
///
/// 📱 LOCAL DATABASE METHODS:
/// 3. **getLocal()** - "What contacts do I have on this phone?"
///    Returns: List of contacts from SQLite/Hive/your database
///
/// 5. **applyToLocal()** - "Save these contacts from the server to my phone"
///    Does: Insert or update contacts in your local database
///
/// ☁️  SERVER API METHODS:
/// 4. **getRemote()** - "Give me the latest contacts from the server"
///    Does: HTTP GET request to your API
///
/// 6. **applyToRemote()** - "Upload my local changes to the server"
///    Does: HTTP POST/PUT request to your API
///
/// 💡 In a real app:
/// - Replace `_localContacts` with actual database queries (SQLite, Hive, etc.)
/// - Replace the simulated server calls with real HTTP requests (http package)
class ContactsSyncHandler extends SyncHandler {
  // In-memory storage for this example.
  // In a real app, this would be SQLite, Hive, Isar, or another database.
  final List<Contact> _localContacts = [
    Contact(id: '1', name: 'Alice', email: 'alice@example.com', version: 1),
    Contact(id: '2', name: 'Bob', email: 'bob@example.com', version: 1),
  ];

  // Cursor for incremental sync ("give me only items changed since last time")
  // In a real app, save this to persistent storage (SharedPreferences, etc.)
  String? _lastSyncCursor;

  @override
  Future<String?> getLastSyncCursor() async => _lastSyncCursor;

  @override
  Future<void> updateLastSyncCursor(String cursor) async {
    _lastSyncCursor = cursor;
  }

  /// Reads all contacts from the local database.
  ///
  /// FeroSync calls this to see what data you have locally.
  /// Returns a list of [SyncPayload] which wraps your data items.
  ///
  /// In a real app:
  /// - Query your database: `await db.query('contacts')`
  /// - Convert results to Contact objects
  /// - Wrap each in SyncPayload
  @override
  Future<List<SyncPayload<Syncable>>> getLocal() async {
    print('📱 [Contacts] Reading local database...');

    // Simulate database read time (in real app, this would be actual DB query)
    await Future.delayed(const Duration(milliseconds: 300));

    // Wrap each contact in SyncPayload (required by FeroSync)
    return _localContacts.map((c) => SyncPayload<Syncable>(data: c)).toList();
  }

  /// Fetches contacts from the server.
  ///
  /// FeroSync calls this to get the latest data from your backend.
  ///
  /// Parameters:
  /// - [cursor]: A bookmark for pagination (can be null)
  ///   - null = "Give me the first batch of contacts"
  ///   - "page_2" = "Give me contacts starting from page 2"
  ///
  /// Returns:
  /// - [SyncBatchResult] with two things:
  ///   1. items: The contacts you fetched (wrapped in SyncPayload)
  ///   2. nextCursor: Bookmark for next batch (null if no more items)
  ///
  /// 💡 Pagination example:
  /// - First call: cursor=null, returns 100 contacts + nextCursor="page_2"
  /// - Second call: cursor="page_2", returns 100 more + nextCursor="page_3"
  /// - Third call: cursor="page_3", returns 50 contacts + nextCursor=null (done!)
  ///
  /// In a real app:
  /// ```dart
  /// final response = await http.get(
  ///   'https://api.example.com/contacts?cursor=$cursor'
  /// );
  /// final json = jsonDecode(response.body);
  /// final contacts = (json['contacts'] as List)
  ///     .map((c) => Contact.fromJson(c))
  ///     .toList();
  /// return SyncBatchResult(
  ///   items: contacts.map((c) => SyncPayload(data: c)).toList(),
  ///   nextCursor: json['nextCursor'],
  /// );
  /// ```
  @override
  Future<SyncBatchResult> getRemote({String? cursor}) async {
    print('☁️  [Contacts] Fetching from server...');

    // Simulate network request time (in real app, this would be HTTP call)
    await Future.delayed(const Duration(seconds: 2));

    // Simulate server response with updated contacts
    // Notice the higher version numbers - server has newer data!
    final remoteContacts = [
      Contact(
          id: '1',
          name: 'Alice Johnson',
          email: 'alice.j@example.com',
          version: 3), // Server version is newer (3 vs 1)
      Contact(
          id: '2',
          name: 'Bob Smith',
          email: 'bob.smith@example.com',
          version: 2), // Server version is newer (2 vs 1)
      Contact(
          id: '3',
          name: 'Charlie Brown',
          email: 'charlie@example.com',
          version: 1), // New contact not in local database
    ];

    print(
        '✅ [Contacts] Received ${remoteContacts.length} contacts from server');
    final items =
        remoteContacts.map((c) => SyncPayload<Syncable>(data: c)).toList();

    return SyncBatchResult(
      items: items,
      nextCursor:
          null, // null means no more pages. Set to a string for pagination.
    );
  }

  /// Saves server data to the local database.
  ///
  /// FeroSync calls this AFTER comparing local vs server data and deciding what wins.
  /// The [remoteStates] parameter contains the "winning" data that should be saved.
  ///
  /// What you receive:
  /// - List of contacts that need to be saved/updated in your local database
  /// - These might be new contacts, or updates to existing ones
  ///
  /// What you should do:
  /// - For each contact, check if it exists locally (by id)
  /// - If exists: UPDATE the local version
  /// - If new: INSERT into local database
  ///
  /// 💡 In a real app with SQLite:
  /// ```dart
  /// for (final payload in remoteStates) {
  ///   final contact = payload.data as Contact;
  ///   await db.insert(
  ///     'contacts',
  ///     contact.toMap(),
  ///     conflictAlgorithm: ConflictAlgorithm.replace, // Upsert
  ///   );
  /// }
  /// ```
  ///
  /// Return:
  /// - ApplyResult.success() if everything saved correctly
  /// - ApplyResult.failure() if something went wrong
  @override
  Future<ApplyResult> applyToLocal(
      List<SyncPayload<Syncable>> remoteStates) async {
    print(
        '💾 [Contacts] Saving ${remoteStates.length} contacts to local database...');

    // Simulate database write time
    await Future.delayed(const Duration(milliseconds: 500));

    // Save each contact to local storage
    for (final payload in remoteStates) {
      final contact = payload.data as Contact;
      final index = _localContacts.indexWhere((c) => c.id == contact.id);

      if (index >= 0) {
        // Contact exists - update it
        _localContacts[index] = contact;
        print('  📝 Updated: ${contact.name}');
      } else {
        // New contact - add it
        _localContacts.add(contact);
        print('  ➕ Added: ${contact.name}');
      }
    }
    print('✅ [Contacts] Saved to local database!');
    return ApplyResult.success();
  }

  /// Uploads local changes to the server.
  ///
  /// FeroSync calls this when you have local changes that need to be sent to the server.
  /// This is for bi-directional sync (not just downloading from server).
  ///
  /// In a real app:
  /// - Make HTTP POST/PUT request to your API
  /// - Send the contact data as JSON
  /// - Handle API errors and return ApplyResult.failure() if upload fails
  @override
  Future<ApplyResult> applyToRemote(
      List<SyncPayload<Syncable>> localStates) async {
    print(
        '☁️  [Contacts] Uploading ${localStates.length} contacts to server...');

    // Simulate HTTP request time
    await Future.delayed(const Duration(seconds: 1));

    print('✅ [Contacts] Upload complete!');
    return ApplyResult.success();
  }
}

/// Handler for syncing notes from the server.
///
/// This is a simpler example - starts with no local notes,
/// and fetches them all from the server on first sync.
///
/// The structure is identical to ContactsSyncHandler:
/// - getLocal/getRemote for reading data
/// - applyToLocal/applyToRemote for writing data
/// - cursor methods for pagination
class NotesSyncHandler extends SyncHandler {
  // Starts empty - will be populated on first sync
  final List<Note> _localNotes = [];
  String? _lastSyncCursor;

  @override
  Future<String?> getLastSyncCursor() async => _lastSyncCursor;

  @override
  Future<void> updateLastSyncCursor(String cursor) async {
    _lastSyncCursor = cursor;
  }

  /// Reads all notes from local storage (starts empty for this example)
  @override
  Future<List<SyncPayload<Syncable>>> getLocal() async {
    print('📱 [Notes] Reading local database...');
    await Future.delayed(const Duration(milliseconds: 150));
    return _localNotes.map((n) => SyncPayload<Syncable>(data: n)).toList();
  }

  /// Fetches notes from the server
  @override
  Future<SyncBatchResult> getRemote({String? cursor}) async {
    print('☁️  [Notes] Fetching from server...');
    await Future.delayed(const Duration(seconds: 1));

    // Simulate server response with 2 notes
    final remoteNotes = [
      Note(id: '1', content: 'Meeting notes from Monday', version: 1),
      Note(id: '2', content: 'Project ideas', version: 1),
    ];

    print('✅ [Notes] Received ${remoteNotes.length} notes from server');
    return SyncBatchResult(
      items: remoteNotes.map((n) => SyncPayload<Syncable>(data: n)).toList(),
      nextCursor: null,
    );
  }

  /// Saves notes from server to local storage
  @override
  Future<ApplyResult> applyToLocal(
      List<SyncPayload<Syncable>> remoteStates) async {
    print(
        '💾 [Notes] Saving ${remoteStates.length} notes to local database...');
    await Future.delayed(const Duration(milliseconds: 300));

    for (final payload in remoteStates) {
      final note = payload.data as Note;
      final index = _localNotes.indexWhere((n) => n.id == note.id);
      if (index >= 0) {
        _localNotes[index] = note;
        print('  📝 Updated note');
      } else {
        _localNotes.add(note);
        print('  ➕ Added note');
      }
    }
    print('✅ [Notes] Saved to local database!');
    return ApplyResult.success();
  }

  /// Uploads notes to the server
  @override
  Future<ApplyResult> applyToRemote(
      List<SyncPayload<Syncable>> localStates) async {
    print('☁️  [Notes] Uploading ${localStates.length} notes to server...');
    await Future.delayed(const Duration(milliseconds: 600));
    print('✅ [Notes] Upload complete!');
    return ApplyResult.success();
  }
}

/// --- Main ---
///
/// App entry point - sets up FeroSync and launches the UI
void main() async {
  // 1. Ensure Flutter bindings are initialized (required for async main)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Setup Handlers for different features
  //    Each key is a "feature name" that you can use to track sync status
  //    Each value is a handler that knows how to sync that type of data
  final handlers = <String, SyncHandler>{
    'contacts': ContactsSyncHandler(),
    'notes': NotesSyncHandler(),
  };

  // 3. Initialize FeroSync with your handlers and strategies
  final feroSync = await FeroSync.create(
    handlers: handlers,

    // Backoff strategy: How long to wait before retrying after failures
    // Exponential = starts small (100ms), doubles each retry, caps at 5 seconds
    backoffStrategy: ExponentialBackoffStrategy(
      baseMillis: 100,
      maxMillis: 5000,
    ),

    // Conflict resolution: What to do when local and server have different versions
    // highestVersionWins = newer version (higher number) always wins
    conflictStrategy: ConflictResolutionStrategy.highestVersionWins,
  );

  // 4. Run the App
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blue,
    ),
    home: SyncDashboard(feroSync: feroSync),
  ));
}

/// Main UI for the demo app.
///
/// Shows:
/// - Overall sync status (ready, syncing, completed)
/// - Individual feature status (contacts, tasks, notes)
/// - A "Sync All" button to trigger synchronization
class SyncDashboard extends StatefulWidget {
  final FeroSync feroSync;

  const SyncDashboard({Key? key, required this.feroSync}) : super(key: key);

  @override
  State<SyncDashboard> createState() => _SyncDashboardState();
}

class _SyncDashboardState extends State<SyncDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('FeroSync Demo',
            style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            const Text(
              "How it works:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Click 'Sync All' to download the latest data from the server for all features. Watch the console for detailed sync progress!",
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 32),
            const Text("FEATURES",
                style: TextStyle(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 12),
            _buildFeatureTile(
                'contacts', Icons.contact_phone_rounded, 'Contacts'),
            const SizedBox(height: 8),
            _buildFeatureTile('notes', Icons.note_rounded, 'Notes'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          print('\n🚀 ========== STARTING SYNC ==========\n');
          // This triggers FeroSync to run all registered handlers
          // Watch the console to see the sync process in action!
          widget.feroSync.run();
        },
        label: const Text('Sync All'),
        icon: const Icon(Icons.sync),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  /// Global Status Card
  Widget _buildStatusCard() {
    return StreamBuilder<InitialSyncStatus>(
      stream: widget.feroSync.statusStream as Stream<InitialSyncStatus>,
      builder: (context, snapshot) {
        final status = snapshot.data ?? InitialSyncStatus.notStarted;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
            ],
          ),
          child: Row(
            children: [
              _getIconForStatus(status),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusText(status),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _getStatusSubtitle(status),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Individual Feature Tile
  Widget _buildFeatureTile(
      String featureKey, IconData icon, String displayName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent, size: 28),
        title: Text(displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Syncs $displayName data from server'),
        trailing: StreamBuilder(
          stream: widget.feroSync.eventStream,
          builder: (context, snapshot) {
            final status = widget.feroSync.getFeatureStatus(featureKey);
            return _getFeatureStatusIcon(status);
          },
        ),
      ),
    );
  }

  Widget _getFeatureStatusIcon(InitialSyncStatus? status) {
    if (status == InitialSyncStatus.running) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (status == InitialSyncStatus.completed) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    return const Icon(Icons.cloud_outlined, color: Colors.grey);
  }

  Widget _getIconForStatus(InitialSyncStatus status) {
    if (status == InitialSyncStatus.running) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    }
    return Icon(
      status == InitialSyncStatus.completed
          ? Icons.cloud_done
          : Icons.cloud_off,
      color:
          status == InitialSyncStatus.completed ? Colors.green : Colors.orange,
      size: 32,
    );
  }

  String _getStatusText(InitialSyncStatus status) {
    switch (status) {
      case InitialSyncStatus.running:
        return "Syncing...";
      case InitialSyncStatus.completed:
        return "All Synced";
      case InitialSyncStatus.failed:
        return "Sync Failed";
      default:
        return "Ready to Sync";
    }
  }

  String _getStatusSubtitle(InitialSyncStatus status) {
    switch (status) {
      case InitialSyncStatus.running:
        return "Downloading updates from server...";
      case InitialSyncStatus.completed:
        return "All features are up to date";
      case InitialSyncStatus.failed:
        return "Check console for error details";
      default:
        return "Click 'Sync All' to start";
    }
  }
}
