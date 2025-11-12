import 'dart:convert';

import 'package:flutter_http_cache/src/data/storage.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';
import 'package:flutter_http_cache/src/domain/valueobject/eviction_strategy.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

/// Persistent cache storage using SQLite
/// Stores cache entries on disk for persistence across app restarts
///
/// THREAD SAFETY:
/// This class uses a single lock ([_lock]) to ensure thread-safe operations.
/// All public methods acquire this lock before performing database operations.
///
/// IMPORTANT: Internal methods with "Unsafe" suffix assume the lock is already held.
/// Never call these methods from outside a locked context, as they will cause deadlocks
/// or race conditions. Always use the public API or ensure the lock is held.
class DiskStorage implements CacheStorage {
  final String _dbPath;
  final int _maxEntries;
  final int _maxBytes;
  final EvictionStrategy _evictionStrategy;

  Database? _database;
  final _lock = Lock();
  int _currentBytes = 0;

  static const String _tableName = 'cache_entries';

  DiskStorage({
    required String dbPath,
    int maxEntries = 1000,
    int maxBytes = 50 * 1024 * 1024, // 50MB default
    EvictionStrategy evictionStrategy = EvictionStrategy.lru,
  })  : _dbPath = dbPath,
        _maxEntries = maxEntries,
        _maxBytes = maxBytes,
        _evictionStrategy = evictionStrategy;

  /// Initializes the database
  Future<void> initialize() async {
    if (_database != null) return;

    await _lock.synchronized(() async {
      if (_database != null) return;

      _database = await openDatabase(
        _dbPath,
        version: 1,
        onCreate: _onCreate,
      );

      // Calculate current bytes used
      _currentBytes = await _calculateTotalSize();
    });
  }

  /// Creates the database schema
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        key TEXT PRIMARY KEY,
        method TEXT NOT NULL,
        uri TEXT NOT NULL,
        status_code INTEGER NOT NULL,
        headers TEXT NOT NULL,
        body BLOB NOT NULL,
        response_time TEXT NOT NULL,
        request_time TEXT NOT NULL,
        vary_headers TEXT,
        is_incomplete INTEGER NOT NULL DEFAULT 0,
        content_range TEXT,
        is_invalid INTEGER NOT NULL DEFAULT 0,
        size INTEGER NOT NULL,
        access_time TEXT NOT NULL,
        access_count INTEGER NOT NULL DEFAULT 1,
        created_time TEXT NOT NULL
      )
    ''');

    // Create indexes for efficient lookups
    await db.execute(
      'CREATE INDEX idx_access_time ON $_tableName(access_time)',
    );
    await db.execute(
      'CREATE INDEX idx_access_count ON $_tableName(access_count)',
    );
    await db.execute(
      'CREATE INDEX idx_created_time ON $_tableName(created_time)',
    );
  }

  @override
  Future<CacheEntry?> get(String key) async {
    await initialize();

    return _lock.synchronized(() async {
      final db = _database!;

      final results = await db.query(
        _tableName,
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final row = results.first;

      // Update access metrics
      await db.update(
        _tableName,
        {
          'access_time': DateTime.now().toIso8601String(),
          'access_count': (row['access_count'] as int) + 1,
        },
        where: 'key = ?',
        whereArgs: [key],
      );

      return _rowToCacheEntry(row);
    });
  }

  @override
  Future<bool> put(String key, CacheEntry entry) async {
    await initialize();

    return _lock.synchronized(() async {
      final db = _database!;
      final entrySize = _calculateEntrySize(entry);

      // Check if entry is too large
      if (entrySize > _maxBytes) return false;

      // Get existing entry size if it exists
      final existingRow = await db.query(
        _tableName,
        columns: ['size'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      int existingSize = 0;
      if (existingRow.isNotEmpty) {
        existingSize = existingRow.first['size'] as int;
      }

      // Evict entries if necessary
      while (await _shouldEvictUnsafe(entrySize - existingSize)) {
        final keyToEvict = await _selectEvictionCandidate();
        if (keyToEvict == null) break;
        await _removeEntryUnsafe(keyToEvict);
      }

      // Insert or replace entry
      await db.insert(
        _tableName,
        _cacheEntryToRow(key, entry, entrySize),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _currentBytes = _currentBytes - existingSize + entrySize;

      return true;
    });
  }

  @override
  Future<bool> remove(String key) async {
    await initialize();

    return _lock.synchronized(() async {
      return await _removeEntryUnsafe(key);
    });
  }

  @override
  Future<bool> contains(String key) async {
    await initialize();

    return _lock.synchronized(() async {
      final db = _database!;

      final result = await db.query(
        _tableName,
        columns: ['key'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      return result.isNotEmpty;
    });
  }

  @override
  Future<void> clear() async {
    await initialize();

    return _lock.synchronized(() async {
      final db = _database!;
      await db.delete(_tableName);
      _currentBytes = 0;
    });
  }

  @override
  Future<void> clearWhere(bool Function(CacheEntry entry) predicate) async {
    await initialize();

    return _lock.synchronized(() async {
      final db = _database!;
      final results = await db.query(_tableName);

      final keysToRemove = <String>[];

      for (final row in results) {
        final entry = _rowToCacheEntry(row);
        if (predicate(entry)) {
          keysToRemove.add(row['key'] as String);
        }
      }

      for (final key in keysToRemove) {
        await _removeEntryUnsafe(key);
      }
    });
  }

  @override
  Future<List<String>> keys() async {
    await initialize();

    return _lock.synchronized(() async {
      final db = _database!;
      final results = await db.query(_tableName, columns: ['key']);
      return results.map((row) => row['key'] as String).toList();
    });
  }

  @override
  Future<int> size() async {
    await initialize();

    return _lock.synchronized(() async {
      final db = _database!;
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      return Sqflite.firstIntValue(result) ?? 0;
    });
  }

  @override
  Future<int> sizeInBytes() async {
    await initialize();

    return _lock.synchronized(() async {
      return _currentBytes;
    });
  }

  @override
  Future<void> close() async {
    await _lock.synchronized(() async {
      await _database?.close();
      _database = null;
    });
  }

  /// Converts a cache entry to a database row
  Map<String, dynamic> _cacheEntryToRow(
      String key, CacheEntry entry, int size) {
    return {
      'key': key,
      'method': entry.method,
      'uri': entry.uri.toString(),
      'status_code': entry.statusCode,
      'headers': jsonEncode(entry.headers),
      'body': entry.body,
      'response_time': entry.responseTime.toIso8601String(),
      'request_time': entry.requestTime.toIso8601String(),
      'vary_headers':
          entry.varyHeaders != null ? jsonEncode(entry.varyHeaders) : null,
      'is_incomplete': entry.isIncomplete ? 1 : 0,
      'content_range': entry.contentRange,
      'is_invalid': entry.isInvalid ? 1 : 0,
      'size': size,
      'access_time': DateTime.now().toIso8601String(),
      'access_count': 1,
      'created_time': DateTime.now().toIso8601String(),
    };
  }

  /// Converts a database row to a cache entry
  CacheEntry _rowToCacheEntry(Map<String, dynamic> row) {
    return CacheEntry(
      method: row['method'] as String,
      uri: Uri.parse(row['uri'] as String),
      statusCode: row['status_code'] as int,
      headers: Map<String, String>.from(jsonDecode(row['headers'] as String)),
      body: (row['body'] as List).cast<int>(),
      responseTime: DateTime.parse(row['response_time'] as String),
      requestTime: DateTime.parse(row['request_time'] as String),
      varyHeaders: row['vary_headers'] != null
          ? Map<String, String>.from(jsonDecode(row['vary_headers'] as String))
          : null,
      isIncomplete: (row['is_incomplete'] as int) == 1,
      contentRange: row['content_range'] as String?,
      isInvalid: (row['is_invalid'] as int) == 1,
    );
  }

  /// Calculates the size of an entry
  int _calculateEntrySize(CacheEntry entry) {
    int size = entry.body.length;

    for (final header in entry.headers.entries) {
      size += header.key.length + header.value.length;
    }

    size += entry.uri.toString().length;
    size += entry.method.length;

    if (entry.varyHeaders != null) {
      for (final header in entry.varyHeaders!.entries) {
        size += header.key.length + header.value.length;
      }
    }

    return size;
  }

  /// Calculates total size of all entries
  Future<int> _calculateTotalSize() async {
    final db = _database!;
    final result =
        await db.rawQuery('SELECT SUM(size) as total FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Gets the entry count without acquiring lock
  ///
  /// INTERNAL USE ONLY - Assumes [_lock] is already held.
  /// Calling this method without holding the lock may cause race conditions.
  /// Use [size()] from external code instead.
  Future<int> _sizeUnsafe() async {
    assert(_database != null, 'Database must be initialized');
    final db = _database!;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Checks if eviction is needed
  ///
  /// INTERNAL USE ONLY - Assumes [_lock] is already held.
  /// This method must not call any public methods that acquire the lock,
  /// as this would cause a deadlock.
  Future<bool> _shouldEvictUnsafe(int additionalBytes) async {
    assert(_database != null, 'Database must be initialized');
    final currentSize = await _sizeUnsafe();
    return currentSize >= _maxEntries ||
        (_currentBytes + additionalBytes) > _maxBytes;
  }

  /// Selects eviction candidate based on strategy
  ///
  /// INTERNAL USE ONLY - Assumes [_lock] is already held.
  Future<String?> _selectEvictionCandidate() async {
    assert(_database != null, 'Database must be initialized');
    switch (_evictionStrategy) {
      case EvictionStrategy.lru:
        return await _selectLRU();
      case EvictionStrategy.lfu:
        return await _selectLFU();
      case EvictionStrategy.fifo:
        return await _selectFIFO();
      case EvictionStrategy.ttl:
        return await _selectTTL();
    }
  }

  /// Selects least recently used entry for eviction
  ///
  /// INTERNAL USE ONLY - Assumes [_lock] is already held.
  Future<String?> _selectLRU() async {
    assert(_database != null, 'Database must be initialized');
    final db = _database!;
    final result = await db.query(
      _tableName,
      columns: ['key'],
      orderBy: 'access_time ASC',
      limit: 1,
    );

    return result.isNotEmpty ? result.first['key'] as String : null;
  }

  /// Selects least frequently used entry for eviction
  ///
  /// INTERNAL USE ONLY - Assumes [_lock] is already held.
  Future<String?> _selectLFU() async {
    assert(_database != null, 'Database must be initialized');
    final db = _database!;
    final result = await db.query(
      _tableName,
      columns: ['key'],
      orderBy: 'access_count ASC, access_time ASC',
      limit: 1,
    );

    return result.isNotEmpty ? result.first['key'] as String : null;
  }

  /// Selects oldest entry for eviction (first in, first out)
  ///
  /// INTERNAL USE ONLY - Assumes [_lock] is already held.
  Future<String?> _selectFIFO() async {
    assert(_database != null, 'Database must be initialized');
    final db = _database!;
    final result = await db.query(
      _tableName,
      columns: ['key'],
      orderBy: 'created_time ASC',
      limit: 1,
    );

    return result.isNotEmpty ? result.first['key'] as String : null;
  }

  /// Selects entry based on TTL for eviction
  ///
  /// INTERNAL USE ONLY - Assumes [_lock] is already held.
  Future<String?> _selectTTL() async {
    assert(_database != null, 'Database must be initialized');
    // For TTL eviction, we would need freshness calculation
    // Fallback to LRU for now
    return await _selectLRU();
  }

  /// Removes an entry and updates size tracking
  ///
  /// INTERNAL USE ONLY - Assumes [_lock] is already held.
  /// This method updates [_currentBytes] directly, so it must be called
  /// within a locked context to prevent race conditions.
  /// Use [remove()] from external code instead.
  Future<bool> _removeEntryUnsafe(String key) async {
    assert(_database != null, 'Database must be initialized');
    final db = _database!;

    // Get size first
    final row = await db.query(
      _tableName,
      columns: ['size'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (row.isEmpty) return false;

    final size = row.first['size'] as int;

    final count = await db.delete(
      _tableName,
      where: 'key = ?',
      whereArgs: [key],
    );

    if (count > 0) {
      _currentBytes -= size;
      return true;
    }

    return false;
  }
}
