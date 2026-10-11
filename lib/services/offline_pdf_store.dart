import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// A PDF that has been saved on this device.
class SavedPdf {
  final String subjectId;
  final String lessonId;
  final int version;
  final int chunks;
  final int bytes;

  const SavedPdf({
    required this.subjectId,
    required this.lessonId,
    required this.version,
    required this.chunks,
    required this.bytes,
  });
}

/// One row of "this subject was downloaded for offline use".
class DownloadRecord {
  final String subjectId;
  final DateTime downloadedAt;
  final int lessonCount;
  final int pdfExpected;

  const DownloadRecord({
    required this.subjectId,
    required this.downloadedAt,
    required this.lessonCount,
    required this.pdfExpected,
  });
}

/// OfflinePdfStore
/// ---------------
/// Permanent on-device storage for lesson PDFs the user chose to
/// download. Kept in its own SQLite file so LocalDbService's schema
/// doesn't need a migration.
///
/// PDFs are saved in 512 KB chunks (one row each) because Android's
/// SQLite cursor can't reliably read multi-MB blobs in one row.
class OfflinePdfStore {
  OfflinePdfStore._internal();
  static final OfflinePdfStore instance = OfflinePdfStore._internal();

  static Database? _db;

  static const int _chunkSize = 512 * 1024;
  static const String _tChunks = 'offline_pdf_chunks';
  static const String _tDownloads = 'offline_downloads';

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'reveduc_offline.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tChunks (
            subjectId TEXT NOT NULL,
            lessonId TEXT NOT NULL,
            version INTEGER NOT NULL,
            idx INTEGER NOT NULL,
            data BLOB NOT NULL,
            PRIMARY KEY (lessonId, version, idx)
          )
        ''');
        await db.execute('''
          CREATE TABLE $_tDownloads (
            subjectId TEXT PRIMARY KEY,
            downloadedAt TEXT NOT NULL,
            lessonCount INTEGER NOT NULL DEFAULT 0,
            pdfExpected INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  // ---------------------------------------------------------------
  // PDFs
  // ---------------------------------------------------------------

  /// Saves [bytes], replacing anything previously saved for the lesson.
  Future<void> savePdf({
    required String subjectId,
    required String lessonId,
    required int version,
    required Uint8List bytes,
  }) async {
    final db = await _database;
    final count = (bytes.length / _chunkSize).ceil();

    await db.transaction((txn) async {
      await txn.delete(_tChunks, where: 'lessonId = ?', whereArgs: [lessonId]);
      for (var i = 0; i < count; i++) {
        final start = i * _chunkSize;
        final end =
            (start + _chunkSize) > bytes.length ? bytes.length : start + _chunkSize;
        await txn.insert(_tChunks, {
          'subjectId': subjectId,
          'lessonId': lessonId,
          'version': version,
          'idx': i,
          'data': Uint8List.sublistView(bytes, start, end),
        });
      }
    });
  }

  /// The saved PDF for a lesson (any version), or null.
  Future<({int version, int chunks})?> getSavedPdf(String lessonId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT version, COUNT(*) AS c FROM $_tChunks WHERE lessonId = ? '
      'GROUP BY version ORDER BY version DESC LIMIT 1',
      [lessonId],
    );
    if (rows.isEmpty) return null;
    return (
      version: (rows.first['version'] as num).toInt(),
      chunks: (rows.first['c'] as num).toInt(),
    );
  }

  /// Reassembles a saved PDF of exactly [version], or null if it isn't
  /// saved (or a chunk is missing).
  Future<Uint8List?> loadPdf(String lessonId, int version) async {
    final db = await _database;
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_tChunks WHERE lessonId = ? AND version = ?',
      [lessonId, version],
    );
    final count = Sqflite.firstIntValue(countRows) ?? 0;
    if (count == 0) return null;

    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < count; i++) {
      final rows = await db.query(
        _tChunks,
        columns: ['data'],
        where: 'lessonId = ? AND version = ? AND idx = ?',
        whereArgs: [lessonId, version, i],
      );
      if (rows.isEmpty) return null;
      builder.add(rows.first['data'] as Uint8List);
    }
    return builder.takeBytes();
  }

  /// Whatever version is saved for the lesson — used as a last resort
  /// when the version the server reports can't be fetched (offline).
  Future<Uint8List?> loadLatestPdf(String lessonId) async {
    final saved = await getSavedPdf(lessonId);
    if (saved == null) return null;
    return loadPdf(lessonId, saved.version);
  }

  /// Every saved PDF with its size.
  Future<List<SavedPdf>> getSavedPdfs() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT subjectId, lessonId, version, COUNT(*) AS chunks, '
      'SUM(LENGTH(data)) AS bytes '
      'FROM $_tChunks GROUP BY lessonId, version',
    );
    return [
      for (final r in rows)
        SavedPdf(
          subjectId: r['subjectId'] as String,
          lessonId: r['lessonId'] as String,
          version: (r['version'] as num).toInt(),
          chunks: (r['chunks'] as num).toInt(),
          bytes: ((r['bytes'] ?? 0) as num).toInt(),
        ),
    ];
  }

  /// Removes saved PDFs of [subjectId] whose lesson isn't in
  /// [keepLessonIds] (e.g. an admin deleted the PDF).
  Future<void> pruneSubject(
      String subjectId, Iterable<String> keepLessonIds) async {
    final db = await _database;
    final keep = keepLessonIds.toList();
    if (keep.isEmpty) {
      await db.delete(_tChunks, where: 'subjectId = ?', whereArgs: [subjectId]);
      return;
    }
    final placeholders = List.filled(keep.length, '?').join(',');
    await db.delete(
      _tChunks,
      where: 'subjectId = ? AND lessonId NOT IN ($placeholders)',
      whereArgs: [subjectId, ...keep],
    );
  }

  // ---------------------------------------------------------------
  // Download records
  // ---------------------------------------------------------------

  Future<void> recordDownload({
    required String subjectId,
    required int lessonCount,
    required int pdfExpected,
  }) async {
    final db = await _database;
    await db.insert(
      _tDownloads,
      {
        'subjectId': subjectId,
        'downloadedAt': DateTime.now().toIso8601String(),
        'lessonCount': lessonCount,
        'pdfExpected': pdfExpected,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, DownloadRecord>> getDownloads() async {
    final db = await _database;
    final rows = await db.query(_tDownloads);
    return {
      for (final r in rows)
        r['subjectId'] as String: DownloadRecord(
          subjectId: r['subjectId'] as String,
          downloadedAt: DateTime.tryParse(r['downloadedAt'] as String) ??
              DateTime.now(),
          lessonCount: (r['lessonCount'] as num).toInt(),
          pdfExpected: (r['pdfExpected'] as num).toInt(),
        ),
    };
  }

  /// Removes a subject's saved PDFs and its "downloaded" record.
  Future<void> removeSubject(String subjectId) async {
    final db = await _database;
    await db.delete(_tChunks, where: 'subjectId = ?', whereArgs: [subjectId]);
    await db.delete(_tDownloads, where: 'subjectId = ?', whereArgs: [subjectId]);
  }

  Future<void> removeAll() async {
    final db = await _database;
    await db.delete(_tChunks);
    await db.delete(_tDownloads);
  }
}
