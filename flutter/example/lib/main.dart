import 'package:fero_sync/core/backoff.dart';
import 'package:fero_sync/core/conflict_resolution.dart';
import 'package:fero_sync/core/sync_event.dart';
import 'package:fero_sync/core/sync_handler.dart';
import 'package:fero_sync/fero_sync.dart';

/// Example: Contacts sync handler
/// Note: The SDK handles:
/// - Log storage automatically
/// - Conflict resolution automatically (using SDK's strategy)
/// 
/// You only implement:
/// - Version tracking
/// - Data application to databases
class ContactsSyncHandler implements SyncHandler {
  // In-memory storage for demo (replace with real DB)
  final Map<String, dynamic> _localDb = {'contacts': [], 'version': 0};

  @override
  Future<VersionInfo> getLocalVersion() async {
    final version = _localDb['version'] as int;
    return VersionInfo(version: version);
  }

  @override
  Future<VersionInfo> getRemoteVersion() async {
    // In real app, fetch from Fero server
    return VersionInfo(version: 2);
  }

  @override
  Future<void> applyToLocalDatabase(List<LogEvent> events) async {
    print('💾 Applying ${events.length} remote changes to local DB');
    for (final event in events) {
      print('  ✏️  ${event.operation}: ${event.data}');
    }
  }

  @override
  Future<void> applyToRemoteDatabase(List<LogEvent> events) async {
    print('🌐 Syncing ${events.length} local changes to Fero');
    for (final event in events) {
      print('  📤 ${event.operation}: ${event.data}');
    }
  }

  @override
  Future<void> updateLocalSyncVersion(int version) async {
    print('🔢 Updated local version to $version');
    _localDb['version'] = version;
  }

  @override
  String get featureName => 'Contacts';
}

/// Example: Messages sync handler
/// Uses the same SDK-provided conflict resolution
class MessagesSyncHandler implements SyncHandler {
  final Map<String, dynamic> _localDb = {'messages': [], 'version': 0};

  @override
  Future<VersionInfo> getLocalVersion() async {
    return VersionInfo(version: _localDb['version'] as int);
  }

  @override
  Future<VersionInfo> getRemoteVersion() async {
    return VersionInfo(version: 1);
  }

  @override
  Future<void> applyToLocalDatabase(List<LogEvent> events) async {
    print('💾 Applying ${events.length} messages locally');
    for (final event in events) {
      print('  📨 ${event.data}');
    }
  }

  @override
  Future<void> applyToRemoteDatabase(List<LogEvent> events) async {
    print('🌐 Syncing ${events.length} local messages to Fero');
    for (final event in events) {
      print('  📤 ${event.data}');
    }
  }

  @override
  Future<void> updateLocalSyncVersion(int version) async {
    print('🔢 Updated message version to $version');
    _localDb['version'] = version;
  }

  @override
  String get featureName => 'Messages';
}

void main() async {
  // --- Initialize handlers ---
  final handlers = <String, SyncHandler>{
    'contacts': ContactsSyncHandler(),
    'messages': MessagesSyncHandler(),
  };

  // --- Create FeroSync SDK with SQLite-backed log storage ---
  // Default: DbSyncLogRepository for persistent storage
  // Conflict Resolution: ConflictResolutionStrategy.highestVersionWins
  // Why versions? Fero server assigns versions - no clock skew issues!
  // Version is primary, timestamp is fallback tiebreaker
  final feroSync = await FeroSync.create(
    handlers: handlers,
    backoffStrategy: ExponentialBackoffStrategy(
      baseMillis: 100,
      maxMillis: 5000,
    ),
    conflictStrategy: ConflictResolutionStrategy.highestVersionWins,
  );

  // --- Register features ---
  feroSync.registerFeature('contacts');
  feroSync.registerFeature('messages');

  // --- Listen to status changes ---
  feroSync.statusStream.listen(
    (status) => print('📊 Sync Status: $status'),
    onError: (error) => print('⚠️  Sync Error: $error'),
  );

  // --- Listen to sync events including conflicts ---
  feroSync.eventStream.listen(
    (event) {
      if (event is InitialSyncStartedEvent) {
        print('🔄 Started syncing: ${event.featureKey}');
      } else if (event is InitialSyncCompletedEvent) {
        print('✅ Completed sync: ${event.featureKey}');
      } else if (event is InitialSyncFailedEvent) {
        print('❌ Failed to sync: ${event.featureKey} - ${event.error}');
      } else if (event is SyncConflictDetectedEvent) {
        print(
          '⚔️  CONFLICT DETECTED: ${event.featureKey}\n'
          '   Local changes: ${event.localChangesCount}\n'
          '   Remote changes: ${event.remoteChangesCount}\n'
          '   Conflicting IDs: ${event.conflictingIds}\n'
          '   Resolution: ${event.resolutionStrategy}',
        );
      }
    },
  );

  // --- Start listening for events from Fero server ---
  await feroSync.startSync();

  // --- Simulate events from Fero server ---
  Future.delayed(Duration(seconds: 1), () {
    print('\n📨 Fero Server: Requesting sync for Contacts...');
    feroSync.triggerInitialSync('contacts');
  });

  Future.delayed(Duration(seconds: 3), () {
    print('\n📨 Fero Server: Requesting sync for Messages...');
    feroSync.triggerInitialSync('messages');
  });

  // Keep the app running to see events flow
  await Future.delayed(Duration(seconds: 10));

  print('\n\n📈 Sync Complete! SDK Automatically Handled:');
  print('✓ Version tracking');
  print('✓ Persistent log storage (SQLite)');
  print('✓ Conflict resolution (highest-version-wins)');
  print('✓ Conflict detection and recording');
  print('✓ Retry logic with backoff');

  feroSync.dispose();
}
