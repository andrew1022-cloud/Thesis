import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// One personal note. A note is always attached to a subject
/// ([subjectId]/[subjectName]) and, optionally, a specific topic
/// within that subject (a lesson title, or any free-typed label like
/// "Midterm review"). [topic] null/empty means a general subject note.
class NoteItem {
  final String id;
  final String uid;
  final String subjectId;
  final String subjectName;
  final String topic;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteItem({
    required this.id,
    required this.uid,
    required this.subjectId,
    required this.subjectName,
    required this.topic,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteItem.fromRow(Map<String, dynamic> row) {
    return NoteItem(
      id: row['id'] as String,
      uid: row['uid'] as String,
      subjectId: (row['subjectId'] as String?) ?? '',
      subjectName: (row['subjectName'] as String?) ?? '',
      topic: (row['topic'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      content: (row['content'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((row['createdAt'] as String?) ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse((row['updatedAt'] as String?) ?? '') ??
              DateTime.now(),
    );
  }
}

/// NotesDbService
/// --------------
/// Offline-first personal notes: create/edit/delete/browse notes,
/// scoped per subject and (optionally) per topic within that subject.
/// Mirrors LocalDbService's sync pattern — SQLite is read/written
/// first so the UI is instant and works offline, then the change is
/// pushed to Firestore under `users/{uid}/notes/{noteId}`. A `synced`
/// flag on unsynced rows lets [pushPendingSyncs] retry later.
class NotesDbService {
  NotesDbService._internal();
  static final NotesDbService instance = NotesDbService._internal();

  static Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _dbName = 'reveduc_notes.db';
  static const int _dbVersion = 1;
  static const String tableNotes = 'notes';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableNotes (
            id TEXT PRIMARY KEY,
            uid TEXT NOT NULL,
            subjectId TEXT NOT NULL,
            subjectName TEXT,
            topic TEXT,
            title TEXT NOT NULL,
            content TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  String _newId() =>
      'note_${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(this) % 10000}';

  // =================================================================
  // CREATE / UPDATE / DELETE
  // =================================================================

  Future<NoteItem> createNote({
    required String uid,
    required String subjectId,
    required String subjectName,
    String topic = '',
    required String title,
    String content = '',
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final id = _newId();

    final row = {
      'id': id,
      'uid': uid,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'topic': topic,
      'title': title,
      'content': content,
      'createdAt': now,
      'updatedAt': now,
      'synced': 0,
      'deleted': 0,
    };
    await db.insert(tableNotes, row);

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(id)
          .set({
        'subjectId': subjectId,
        'subjectName': subjectName,
        'topic': topic,
        'title': title,
        'content': content,
        'createdAt': now,
        'updatedAt': now,
      });
      await db.update(tableNotes, {'synced': 1},
          where: 'id = ?', whereArgs: [id]);
    } catch (_) {
      // Offline — retried by pushPendingSyncs.
    }

    return NoteItem.fromRow(row);
  }

  Future<void> updateNote({
    required String uid,
    required String noteId,
    String? subjectId,
    String? subjectName,
    String? topic,
    String? title,
    String? content,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final updates = <String, dynamic>{'updatedAt': now, 'synced': 0};
    if (subjectId != null) updates['subjectId'] = subjectId;
    if (subjectName != null) updates['subjectName'] = subjectName;
    if (topic != null) updates['topic'] = topic;
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;

    await db.update(tableNotes, updates,
        where: 'id = ? AND uid = ?', whereArgs: [noteId, uid]);

    try {
      final firestoreUpdates = Map<String, dynamic>.from(updates)
        ..remove('synced');
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(noteId)
          .set(firestoreUpdates, SetOptions(merge: true));
      await db.update(tableNotes, {'synced': 1},
          where: 'id = ?', whereArgs: [noteId]);
    } catch (_) {}
  }

  /// Soft-deletes locally (so a pending sync can still tell Firestore
  /// about it) and removes the Firestore doc outright when reachable.
  Future<void> deleteNote({required String uid, required String noteId}) async {
    final db = await database;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(noteId)
          .delete();
      await db.delete(tableNotes, where: 'id = ?', whereArgs: [noteId]);
    } catch (_) {
      // Offline — mark deleted locally, hide from queries, and let
      // pushPendingSyncs finish the Firestore delete later.
      await db.update(
        tableNotes,
        {'deleted': 1, 'synced': 0},
        where: 'id = ? AND uid = ?',
        whereArgs: [noteId, uid],
      );
    }
  }

  // =================================================================
  // READS
  // =================================================================

  Future<List<NoteItem>> getAllNotes(String uid) async {
    final db = await database;
    final rows = await db.query(
      tableNotes,
      where: 'uid = ? AND deleted = 0',
      whereArgs: [uid],
      orderBy: 'updatedAt DESC',
    );
    return rows.map(NoteItem.fromRow).toList();
  }

  Future<List<NoteItem>> getNotesForSubject(String uid, String subjectId) async {
    final db = await database;
    final rows = await db.query(
      tableNotes,
      where: 'uid = ? AND subjectId = ? AND deleted = 0',
      whereArgs: [uid, subjectId],
      orderBy: 'updatedAt DESC',
    );
    return rows.map(NoteItem.fromRow).toList();
  }

  Future<List<NoteItem>> getNotesForTopic({
    required String uid,
    required String subjectId,
    required String topic,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableNotes,
      where: 'uid = ? AND subjectId = ? AND topic = ? AND deleted = 0',
      whereArgs: [uid, subjectId, topic],
      orderBy: 'updatedAt DESC',
    );
    return rows.map(NoteItem.fromRow).toList();
  }

  /// Simple case-insensitive search across title/content/topic,
  /// optionally scoped to one subject.
  Future<List<NoteItem>> searchNotes({
    required String uid,
    required String query,
    String? subjectId,
  }) async {
    final db = await database;
    final like = '%${query.trim()}%';
    final where = StringBuffer('uid = ? AND deleted = 0 AND ('
        'title LIKE ? OR content LIKE ? OR topic LIKE ?)');
    final args = <Object?>[uid, like, like, like];
    if (subjectId != null) {
      where.write(' AND subjectId = ?');
      args.add(subjectId);
    }
    final rows = await db.query(
      tableNotes,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );
    return rows.map(NoteItem.fromRow).toList();
  }

  /// Distinct (subjectId, subjectName) pairs the user has notes
  /// under — used to build a subject filter/section list.
  Future<List<Map<String, String>>> getSubjectsWithNotes(String uid) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT subjectId, subjectName
      FROM $tableNotes
      WHERE uid = ? AND deleted = 0
      ORDER BY subjectName ASC
    ''', [uid]);
    return rows
        .map((r) => {
              'subjectId': (r['subjectId'] as String?) ?? '',
              'subjectName': (r['subjectName'] as String?) ?? '',
            })
        .toList();
  }

  // =================================================================
  // SYNC
  // =================================================================

  /// Pulls this user's notes down from Firestore into the local
  /// cache — call after login / on a fresh install.
  Future<void> syncFromFirestore(String uid) async {
    final db = await database;
    final snapshot =
        await _firestore.collection('users').doc(uid).collection('notes').get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existing =
          await db.query(tableNotes, where: 'id = ?', whereArgs: [doc.id]);
      final row = {
        'id': doc.id,
        'uid': uid,
        'subjectId': data['subjectId'] ?? '',
        'subjectName': data['subjectName'] ?? '',
        'topic': data['topic'] ?? '',
        'title': data['title'] ?? '',
        'content': data['content'] ?? '',
        'createdAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
        'updatedAt': data['updatedAt'] ?? DateTime.now().toIso8601String(),
        'synced': 1,
        'deleted': 0,
      };
      if (existing.isEmpty) {
        await db.insert(tableNotes, row);
      } else {
        await db.update(tableNotes, row, where: 'id = ?', whereArgs: [doc.id]);
      }
    }
  }

  /// Retries anything that couldn't reach Firestore earlier — call
  /// opportunistically (e.g. app resume, pull-to-refresh).
  Future<void> pushPendingSyncs(String uid) async {
    final db = await database;
    final pending = await db.query(
      tableNotes,
      where: 'uid = ? AND synced = 0',
      whereArgs: [uid],
    );

    for (final row in pending) {
      final id = row['id'] as String;
      try {
        if (row['deleted'] == 1) {
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('notes')
              .doc(id)
              .delete();
          await db.delete(tableNotes, where: 'id = ?', whereArgs: [id]);
        } else {
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('notes')
              .doc(id)
              .set({
            'subjectId': row['subjectId'],
            'subjectName': row['subjectName'],
            'topic': row['topic'],
            'title': row['title'],
            'content': row['content'],
            'createdAt': row['createdAt'],
            'updatedAt': row['updatedAt'],
          }, SetOptions(merge: true));
          await db.update(tableNotes, {'synced': 1},
              where: 'id = ?', whereArgs: [id]);
        }
      } catch (_) {
        // Still offline — leave it pending.
      }
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
