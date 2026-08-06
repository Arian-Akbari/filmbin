import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/models/models.dart';

/// The on-device mirror (deck 08, sections 6 and 8.4).
///
/// Three jobs:
/// * open the app instantly with the last known content, before the network
///   answers;
/// * keep the watch list readable with no connection at all;
/// * hold writes made offline in an outbox and replay them once we are back.
class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;

  static const _version = 1;
  static LocalDatabase? _instance;

  static Future<LocalDatabase> open({String? path}) async {
    if (_instance != null) return _instance!;
    final databasePath = path ?? p.join(await getDatabasesPath(), 'filmbin.db');
    final db = await openDatabase(
      databasePath,
      version: _version,
      onCreate: (db, version) async => _migrate(db, 0, version),
      onUpgrade: _migrate,
    );
    return _instance = LocalDatabase._(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    if (from < 1) {
      await db.execute('''
        CREATE TABLE titles (
          imdb_id    TEXT PRIMARY KEY,
          payload    TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE watchlist (
          imdb_id     TEXT PRIMARY KEY,
          status      TEXT,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          updated_at  INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE sections (
          key        TEXT PRIMARY KEY,
          title      TEXT NOT NULL,
          payload    TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE outbox (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          method     TEXT NOT NULL,
          path       TEXT NOT NULL,
          body       TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX idx_watchlist_status ON watchlist(status)');
    }
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  // ---- titles -------------------------------------------------------------

  Future<void> cacheTitles(Iterable<TitleSummary> titles) async {
    final batch = _db.batch();
    for (final title in titles) {
      batch.insert('titles', {
        'imdb_id': title.imdbId,
        'payload': jsonEncode(title.toJson()),
        'updated_at': _now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<TitleSummary?> readTitle(String imdbId) async {
    final rows = await _db.query('titles', where: 'imdb_id = ?', whereArgs: [imdbId], limit: 1);
    if (rows.isEmpty) return null;
    return TitleSummary.fromJson(
      Map<String, dynamic>.from(jsonDecode(rows.first['payload'] as String) as Map),
    );
  }

  // ---- watch list ---------------------------------------------------------

  Future<void> saveWatchlist(Iterable<TitleSummary> titles) async {
    final batch = _db.batch();
    for (final title in titles) {
      batch.insert('watchlist', {
        'imdb_id': title.imdbId,
        'status': title.myStatus?.apiValue,
        'is_favorite': title.isFavorite ? 1 : 0,
        'updated_at': _now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await cacheTitles(titles);
  }

  Future<List<TitleSummary>> readWatchlist({
    WatchStatus? status,
    bool favoritesOnly = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (status != null) {
      where.add('w.status = ?');
      args.add(status.apiValue);
    } else if (!favoritesOnly) {
      where.add('w.status IS NOT NULL');
    }
    if (favoritesOnly) where.add('w.is_favorite = 1');

    final rows = await _db.rawQuery(
      'SELECT t.payload FROM watchlist w '
      'JOIN titles t ON t.imdb_id = w.imdb_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY w.updated_at DESC',
      args,
    );

    return rows
        .map(
          (row) => TitleSummary.fromJson(
            Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map),
          ),
        )
        .toList();
  }

  Future<void> upsertWatchEntry(String imdbId, {WatchStatus? status, bool? isFavorite}) async {
    final existing = await _db.query('watchlist', where: 'imdb_id = ?', whereArgs: [imdbId]);
    final favorite =
        isFavorite ?? (existing.isEmpty ? false : (existing.first['is_favorite'] as int) == 1);
    await _db.insert('watchlist', {
      'imdb_id': imdbId,
      'status': status?.apiValue,
      'is_favorite': favorite ? 1 : 0,
      'updated_at': _now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeWatchEntry(String imdbId) =>
      _db.delete('watchlist', where: 'imdb_id = ?', whereArgs: [imdbId]);

  // ---- home rails ---------------------------------------------------------

  Future<void> saveSections(List<DiscoverSection> sections) async {
    final batch = _db.batch();
    for (final section in sections) {
      batch.insert('sections', {
        'key': section.key,
        'title': section.title,
        'payload': jsonEncode(section.items.map((t) => t.toJson()).toList()),
        'updated_at': _now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    for (final section in sections) {
      await cacheTitles(section.items);
    }
  }

  Future<List<DiscoverSection>> readSections() async {
    final rows = await _db.query('sections', orderBy: 'rowid');
    return rows.map((row) {
      final items = (jsonDecode(row['payload'] as String) as List)
          .map((e) => TitleSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return DiscoverSection(
        key: row['key'] as String,
        title: row['title'] as String,
        items: items,
      );
    }).toList();
  }

  // ---- offline outbox -----------------------------------------------------

  Future<void> enqueue(String method, String path, Map<String, dynamic>? body) =>
      _db.insert('outbox', {
        'method': method,
        'path': path,
        'body': body == null ? null : jsonEncode(body),
        'created_at': _now,
      });

  Future<List<OutboxEntry>> pendingActions() async {
    final rows = await _db.query('outbox', orderBy: 'created_at ASC');
    return rows
        .map(
          (row) => OutboxEntry(
            id: row['id'] as int,
            method: row['method'] as String,
            path: row['path'] as String,
            body: row['body'] == null
                ? null
                : Map<String, dynamic>.from(jsonDecode(row['body'] as String) as Map),
          ),
        )
        .toList();
  }

  Future<void> removeAction(int id) => _db.delete('outbox', where: 'id = ?', whereArgs: [id]);

  Future<int> pendingCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM outbox')) ?? 0;

  Future<void> clearUserData() async {
    await _db.delete('watchlist');
    await _db.delete('outbox');
  }

  /// Drops the read-only mirror only. The watch list and the outbox survive —
  /// they hold the user's own work, which no "clear cache" button should eat.
  Future<void> clearCache() async {
    await _db.delete('titles');
    await _db.delete('sections');
  }
}

class OutboxEntry {
  const OutboxEntry({required this.id, required this.method, required this.path, this.body});

  final int id;
  final String method;
  final String path;
  final Map<String, dynamic>? body;
}
