import 'dart:convert';

import 'package:fero_sync/core/sync_handler.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Internal repository for storing and retrieving sync log events.
/// The SDK uses this to track all changes without exposing it to users.
abstract class SyncLogRepository {
  /// Record a local change (create, update, delete operation).
  Future<void> addLocalLog(
    String featureKey,
    LogEvent event,
  );

  /// Record a remote change.
  Future<void> addRemoteLog(
    String featureKey,
    LogEvent event,
  );

  /// Get all local log events since the last given version.
  /// Used during merge to determine what changed locally.
  Future<List<LogEvent>> getLocalLogsSince(
    String featureKey,
    int sinceVersion,
  );

  /// Get all remote log events since the last given version.
  /// Used during merge to determine what changed remotely.
  Future<List<LogEvent>> getRemoteLogsSince(
    String featureKey,
    int sinceVersion,
  );

  /// Clear logs up to a certain version (after successful sync).
  Future<void> clearLogsBefore(String featureKey, int version);

  /// Get conflict history for a feature (for analytics).
  Future<List<SyncConflict>> getConflictHistory(String featureKey);

  /// Record a conflict incident.
  Future<void> recordConflict(String featureKey, SyncConflict conflict);
}

/// In-memory implementation of SyncLogRepository (for testing/demo).
class InMemorySyncLogRepository implements SyncLogRepository {
  final Map<String, List<LogEvent>> _localLogs = {};
  final Map<String, List<LogEvent>> _remoteLogs = {};
  final Map<String, List<SyncConflict>> _conflicts = {};

  @override
  Future<void> addLocalLog(String featureKey, LogEvent event) async {
    _localLogs.putIfAbsent(featureKey, () => []).add(event);
  }

  @override
  Future<void> addRemoteLog(String featureKey, LogEvent event) async {
    _remoteLogs.putIfAbsent(featureKey, () => []).add(event);
  }

  @override
  Future<List<LogEvent>> getLocalLogsSince(
    String featureKey,
    int sinceVersion,
  ) async {
    return _localLogs[featureKey]
            ?.where((e) => e.version > sinceVersion)
            .toList() ??
        [];
  }

  @override
  Future<List<LogEvent>> getRemoteLogsSince(
    String featureKey,
    int sinceVersion,
  ) async {
    return _remoteLogs[featureKey]
            ?.where((e) => e.version > sinceVersion)
            .toList() ??
        [];
  }

  @override
  Future<void> clearLogsBefore(String featureKey, int version) async {
    _localLogs[featureKey]?.removeWhere((e) => e.version <= version);
    _remoteLogs[featureKey]?.removeWhere((e) => e.version <= version);
  }

  @override
  Future<List<SyncConflict>> getConflictHistory(String featureKey) async {
    return _conflicts[featureKey] ?? [];
  }

  @override
  Future<void> recordConflict(String featureKey, SyncConflict conflict) async {
    _conflicts.putIfAbsent(featureKey, () => []).add(conflict);
  }
}

/// Represents a sync conflict for tracking and analytics.
class SyncConflict {
  final String featureKey;
  final List<String> conflictingIds;
  final String resolutionStrategy; // How it was resolved
  final int localChangeCount;
  final int remoteChangeCount;
  final DateTime detectedAt;

  SyncConflict({
    required this.featureKey,
    required this.conflictingIds,
    required this.resolutionStrategy,
    required this.localChangeCount,
    required this.remoteChangeCount,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();
}

/// SQLite-backed implementation of SyncLogRepository.
/// Persists all log events and conflicts to local SQLite database.
class DbSyncLogRepository implements SyncLogRepository {
  final Database _db;

  // Table names and column constants
  static const String _localLogsTable = 'local_sync_logs';
  static const String _remoteLogsTable = 'remote_sync_logs';
  static const String _conflictsTable = 'sync_conflicts';

  // Local/Remote logs columns
  static const String colId = 'id';
  static const String colFeatureKey = 'featureKey';
  static const String colOperation = 'operation';
  static const String colData = 'data';
  static const String colVersion = 'version';
  static const String colTimestamp = 'timestamp';

  // Conflicts columns
  static const String colConflictId = 'id';
  static const String colConflictFeatureKey = 'featureKey';
  static const String colConflictingIds = 'conflictingIds';
  static const String colResolutionStrategy = 'resolutionStrategy';
  static const String colLocalChangeCount = 'localChangeCount';
  static const String colRemoteChangeCount = 'remoteChangeCount';
  static const String colDetectedAt = 'detectedAt';

  DbSyncLogRepository._(this._db);

  /// Opens (or creates) the database and returns a repository instance.
  static Future<DbSyncLogRepository> open({String? dbName}) async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, dbName ?? 'fero_sync.db');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table for local log events
        await db.execute('''
          CREATE TABLE $_localLogsTable (
            $colId TEXT PRIMARY KEY,
            $colFeatureKey TEXT NOT NULL,
            $colOperation TEXT NOT NULL,
            $colData TEXT NOT NULL,
            $colVersion INTEGER NOT NULL,
            $colTimestamp INTEGER NOT NULL
          )
        ''');

        // Index for efficient queries by featureKey and version
        await db.execute(
          'CREATE INDEX idx_local_feature_version ON $_localLogsTable($colFeatureKey, $colVersion)',
        );

        // Table for remote log events
        await db.execute('''
          CREATE TABLE $_remoteLogsTable (
            $colId TEXT PRIMARY KEY,
            $colFeatureKey TEXT NOT NULL,
            $colOperation TEXT NOT NULL,
            $colData TEXT NOT NULL,
            $colVersion INTEGER NOT NULL,
            $colTimestamp INTEGER NOT NULL
          )
        ''');

        // Index for efficient queries by featureKey and version
        await db.execute(
          'CREATE INDEX idx_remote_feature_version ON $_remoteLogsTable($colFeatureKey, $colVersion)',
        );

        // Table for conflict history (for analytics)
        await db.execute('''
          CREATE TABLE $_conflictsTable (
            $colConflictId TEXT PRIMARY KEY,
            $colConflictFeatureKey TEXT NOT NULL,
            $colConflictingIds TEXT NOT NULL,
            $colResolutionStrategy TEXT NOT NULL,
            $colLocalChangeCount INTEGER NOT NULL,
            $colRemoteChangeCount INTEGER NOT NULL,
            $colDetectedAt INTEGER NOT NULL
          )
        ''');

        // Index for efficient conflict queries by feature
        await db.execute(
          'CREATE INDEX idx_conflicts_feature ON $_conflictsTable($colConflictFeatureKey)',
        );
      },
    );

    return DbSyncLogRepository._(db);
  }

  LogEvent _logEventFromRow(Map<String, Object?> row) {
    return LogEvent(
      id: row[colId] as String,
      operation: row[colOperation] as String,
      data: jsonDecode(row[colData] as String) as Map<String, dynamic>,
      version: row[colVersion] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row[colTimestamp] as int),
    );
  }

  SyncConflict _syncConflictFromRow(Map<String, Object?> row) {
    return SyncConflict(
      featureKey: row[colConflictFeatureKey] as String,
      conflictingIds: List<String>.from(
        jsonDecode(row[colConflictingIds] as String) as List<dynamic>,
      ),
      resolutionStrategy: row[colResolutionStrategy] as String,
      localChangeCount: row[colLocalChangeCount] as int,
      remoteChangeCount: row[colRemoteChangeCount] as int,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(
        row[colDetectedAt] as int,
      ),
    );
  }

  @override
  Future<void> addLocalLog(String featureKey, LogEvent event) async {
    await _db.insert(_localLogsTable, {
      colId: event.id,
      colFeatureKey: featureKey,
      colOperation: event.operation,
      colData: jsonEncode(event.data),
      colVersion: event.version,
      colTimestamp: event.timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> addRemoteLog(String featureKey, LogEvent event) async {
    await _db.insert(_remoteLogsTable, {
      colId: event.id,
      colFeatureKey: featureKey,
      colOperation: event.operation,
      colData: jsonEncode(event.data),
      colVersion: event.version,
      colTimestamp: event.timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<LogEvent>> getLocalLogsSince(
    String featureKey,
    int sinceVersion,
  ) async {
    final maps = await _db.query(
      _localLogsTable,
      where: '$colFeatureKey = ? AND $colVersion > ?',
      whereArgs: [featureKey, sinceVersion],
      orderBy: '$colVersion ASC',
    );

    return maps.map(_logEventFromRow).toList();
  }

  @override
  Future<List<LogEvent>> getRemoteLogsSince(
    String featureKey,
    int sinceVersion,
  ) async {
    final maps = await _db.query(
      _remoteLogsTable,
      where: '$colFeatureKey = ? AND $colVersion > ?',
      whereArgs: [featureKey, sinceVersion],
      orderBy: '$colVersion ASC',
    );

    return maps.map(_logEventFromRow).toList();
  }

  @override
  Future<void> clearLogsBefore(String featureKey, int version) async {
    await _db.transaction((txn) async {
      await txn.delete(
        _localLogsTable,
        where: '$colFeatureKey = ? AND $colVersion <= ?',
        whereArgs: [featureKey, version],
      );

      await txn.delete(
        _remoteLogsTable,
        where: '$colFeatureKey = ? AND $colVersion <= ?',
        whereArgs: [featureKey, version],
      );
    });
  }

  @override
  Future<List<SyncConflict>> getConflictHistory(String featureKey) async {
    final maps = await _db.query(
      _conflictsTable,
      where: '$colConflictFeatureKey = ?',
      whereArgs: [featureKey],
      orderBy: '$colDetectedAt DESC',
    );

    return maps.map(_syncConflictFromRow).toList();
  }

  @override
  Future<void> recordConflict(String featureKey, SyncConflict conflict) async {
    await _db.insert(_conflictsTable, {
      colConflictId: '${featureKey}_${DateTime.now().millisecondsSinceEpoch}',
      colConflictFeatureKey: featureKey,
      colConflictingIds: jsonEncode(conflict.conflictingIds),
      colResolutionStrategy: conflict.resolutionStrategy,
      colLocalChangeCount: conflict.localChangeCount,
      colRemoteChangeCount: conflict.remoteChangeCount,
      colDetectedAt: conflict.detectedAt.millisecondsSinceEpoch,
    });
  }

  /// Close the underlying database.
  Future<void> close() async => _db.close();
}
