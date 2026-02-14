import 'dart:convert';

import 'package:fero_sync/queue/sync_queue_repository.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// SQLite-backed implementation of `SyncQueueRepository`.
class DbSyncQueueRepository implements SyncQueueRepository {
  final Database _db;

  // Schema constants
  static const String _table = 'sync_tasks';
  static const String colId = 'id';
  static const String colFeatureKey = 'featureKey';
  static const String colData = 'data';
  static const String colEnqueuedAt = 'enqueuedAt';
  static const String colStatus = 'status';

  DbSyncQueueRepository._(this._db);

  SyncTask _syncTaskFromRow(Map<String, Object?> row) {
    return SyncTask(
      featureKey: row[colFeatureKey] as String,
      data: jsonDecode(row[colData] as String) as Map<String, dynamic>,
      enqueuedAt:
          DateTime.fromMillisecondsSinceEpoch(row[colEnqueuedAt] as int),
      status: SyncTaskStatus.values.firstWhere(
          (e) => e.name == (row[colStatus] as String),
          orElse: () => SyncTaskStatus.pending),
    );
  }

  /// Opens (or creates) the DB file and returns a repository instance.
  static Future<DbSyncQueueRepository> open({String? dbName}) async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, dbName ?? 'fero_sync.db');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            $colId TEXT PRIMARY KEY,
            $colFeatureKey TEXT NOT NULL,
            $colData TEXT NOT NULL,
            $colEnqueuedAt INTEGER NOT NULL,
            $colStatus TEXT NOT NULL DEFAULT '${SyncTaskStatus.pending.name}'
          )
        ''');
      },
    );

    return DbSyncQueueRepository._(db);
  }

  @override
  Future<void> enqueue(SyncTask task) async {
    final id = const Uuid().v4();
    await _db.insert(_table, {
      colId: id,
      colFeatureKey: task.featureKey,
      colData: jsonEncode(task.data),
      colEnqueuedAt: task.enqueuedAt.millisecondsSinceEpoch,
      colStatus: task.status.name,
    });
  }

  @override
  Future<SyncTask?> dequeue() async {
    return await _db.transaction((txn) async {
      final maps = await txn.query(
        _table,
        where: '$colStatus = ?',
        whereArgs: [SyncTaskStatus.pending.name],
        orderBy: '$colEnqueuedAt ASC',
        limit: 1,
      );

      if (maps.isEmpty) return null;

      final row = maps.first;
      final id = row[colId] as String;

      await txn.delete(
        _table,
        where: '$colId = ?',
        whereArgs: [id],
      );

      return _syncTaskFromRow(row);
    });
  }

  @override
  Future<SyncTask?> peek() async {
    final maps = await _db.query(
      _table,
      where: '$colStatus = ?',
      whereArgs: [SyncTaskStatus.pending.name],
      orderBy: '$colEnqueuedAt ASC',
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final row = maps.first;
    return _syncTaskFromRow(row);
  }

  @override
  Future<bool> isEmpty() async {
    final count = Sqflite.firstIntValue(await _db.rawQuery(
        'SELECT COUNT(*) FROM $_table WHERE $colStatus = ?',
        [SyncTaskStatus.pending.name]));
    return (count ?? 0) == 0;
  }

  @override
  Future<int> size() async {
    final count = Sqflite.firstIntValue(await _db.rawQuery(
        'SELECT COUNT(*) FROM $_table WHERE $colStatus = ?',
        [SyncTaskStatus.pending.name]));
    return count ?? 0;
  }

  @override
  Future<void> clear() async {
    await _db.delete(_table);
  }

  @override
  Future<List<SyncTask>> getTasksByFeature(String featureKey) async {
    final maps = await _db.query(
      _table,
      where: '$colFeatureKey = ?',
      whereArgs: [featureKey],
      orderBy: '$colEnqueuedAt ASC',
    );

    return maps
        .map((row) => SyncTask(
              featureKey: row['featureKey'] as String,
              data: jsonDecode(row['data'] as String) as Map<String, dynamic>,
              enqueuedAt:
                  DateTime.fromMillisecondsSinceEpoch(row['enqueuedAt'] as int),
              status: SyncTaskStatus.values.firstWhere(
                  (e) => e.name == (row['status'] as String),
                  orElse: () => SyncTaskStatus.pending),
            ))
        .toList();
  }

  @override
  Future<int> removeTasksByFeature(String featureKey) async {
    final removed = await _db
        .delete(_table, where: '$colFeatureKey = ?', whereArgs: [featureKey]);
    return removed;
  }

  /// Returns true if there is a completed marker for the given feature.
  Future<bool> isFeatureCompleted(String featureKey) async {
    final maps = await _db.query(_table,
        where: '$colFeatureKey = ? AND $colStatus = ?',
        whereArgs: [featureKey, SyncTaskStatus.completed.name],
        limit: 1);
    return maps.isNotEmpty;
  }

  /// Close the underlying DB.
  Future<void> close() async => _db.close();
}
