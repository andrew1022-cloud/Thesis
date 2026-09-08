import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'notes_db_service.dart';

/// LocalDbService
/// ----------------
/// Offline-first local cache for RevEduc's reviewer content, synced
/// from Firestore. Firestore is the source of truth; this service
/// pulls it down into SQLite so lessons and quizzes can be read
/// instantly and offline.
///
/// Reviewer content (subjects/lessons/quiz) is shared across all
/// users. Everything else here — quiz attempts, bookmarks, lesson
/// progress, and the daily-use log that drives the streak — is
/// per-account: tagged with the Firebase Auth uid, mirrored up to
/// Firestore as it's created, and pulled back down on a fresh
/// install / new device via [syncUserDataFromFirestore]. Pass the
/// current uid into every per-account method — this service doesn't
/// read FirebaseAuth itself.
///
/// Add to pubspec.yaml:
///   dependencies:
///     sqflite: ^2.3.0
///     path: ^1.9.0
///   (cloud_firestore is already in your pubspec.yaml)
///
/// ---------------------------------------------------------------
/// ASSUMED FIRESTORE STRUCTURE (adjust field names below to match
/// whatever you actually create, then update the mapper functions):
///
///   subjects/{subjectId}
///     - name, description, code ('GE'|'PE'|'SP'), colorHex, order, updatedAt
///
///   subjects/{subjectId}/lessons/{lessonId}
///     - title, content, order, updatedAt
///
///   subjects/{subjectId}/lessons/{lessonId}/quiz/{questionId}
///     - questionText, optionA-D, correctOption, explanation, order, updatedAt
///
///   users/{uid}/quizAttempts/{attemptId}   (auto-generated id)
///     - subjectId, lessonId, score, totalItems, quizType, dateTaken
///     - quizType: 'competency' | 'lesson' | 'subject'
///
///   users/{uid}/bookmarks/{questionId}     (doc id == questionId)
///     - dateBookmarked
///
///   users/{uid}/lessonProgress/{lessonId}  (doc id == lessonId)
///     - subjectId, isCompleted, lastOpenedAt, completedAt
///
///   users/{uid}/appUsage/{yyyy-mm-dd}      (doc id == date string)
///     - openedAt
/// ---------------------------------------------------------------
class LocalDbService {
  LocalDbService._internal();
  static final LocalDbService instance = LocalDbService._internal();

  static Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _dbName = 'reveduc_local.db';
  static const int _dbVersion = 3;

  static const String tableSubjects = 'subjects';
  static const String tableLessons = 'lessons';
  static const String tableQuizQuestions = 'quiz_questions';
  static const String tableQuizAttempts = 'quiz_attempts';
  static const String tableBookmarks = 'bookmarks';
  static const String tableLessonProgress = 'user_lesson_progress';
  static const String tableAppUsage = 'app_usage_log';

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
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableSubjects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            code TEXT,
            colorHex TEXT,
            orderIndex INTEGER DEFAULT 0,
            updatedAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableLessons (
            id TEXT PRIMARY KEY,
            subjectId TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT,
            orderIndex INTEGER DEFAULT 0,
            updatedAt TEXT,
            FOREIGN KEY (subjectId) REFERENCES $tableSubjects (id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableQuizQuestions (
            id TEXT PRIMARY KEY,
            subjectId TEXT NOT NULL,
            lessonId TEXT NOT NULL,
            questionText TEXT NOT NULL,
            optionA TEXT NOT NULL,
            optionB TEXT NOT NULL,
            optionC TEXT NOT NULL,
            optionD TEXT NOT NULL,
            correctOption TEXT NOT NULL,
            explanation TEXT,
            orderIndex INTEGER DEFAULT 0,
            updatedAt TEXT,
            FOREIGN KEY (lessonId) REFERENCES $tableLessons (id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableQuizAttempts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            subjectId TEXT,
            lessonId TEXT,
            quizType TEXT,
            score INTEGER NOT NULL,
            totalItems INTEGER NOT NULL,
            dateTaken TEXT NOT NULL,
            firestoreId TEXT,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableBookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            questionId TEXT NOT NULL,
            dateBookmarked TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            UNIQUE (userId, questionId)
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableLessonProgress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            subjectId TEXT NOT NULL,
            lessonId TEXT NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            lastOpenedAt TEXT,
            completedAt TEXT,
            synced INTEGER NOT NULL DEFAULT 0,
            UNIQUE (userId, lessonId)
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableAppUsage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            dateString TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            UNIQUE (userId, dateString)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE $tableQuizAttempts ADD COLUMN userId TEXT NOT NULL DEFAULT ""');
          await db.execute(
              'ALTER TABLE $tableQuizAttempts ADD COLUMN firestoreId TEXT');
          await db.execute(
              'ALTER TABLE $tableQuizAttempts ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE $tableBookmarks ADD COLUMN userId TEXT NOT NULL DEFAULT ""');
          await db.execute(
              'ALTER TABLE $tableBookmarks ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE $tableSubjects ADD COLUMN code TEXT');
          await db.execute(
              'ALTER TABLE $tableSubjects ADD COLUMN colorHex TEXT');
          await db.execute(
              'ALTER TABLE $tableQuizAttempts ADD COLUMN quizType TEXT');
          await db.execute('''
            CREATE TABLE $tableLessonProgress (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              userId TEXT NOT NULL,
              subjectId TEXT NOT NULL,
              lessonId TEXT NOT NULL,
              isCompleted INTEGER NOT NULL DEFAULT 0,
              lastOpenedAt TEXT,
              completedAt TEXT,
              synced INTEGER NOT NULL DEFAULT 0,
              UNIQUE (userId, lessonId)
            )
          ''');
          await db.execute('''
            CREATE TABLE $tableAppUsage (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              userId TEXT NOT NULL,
              dateString TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0,
              UNIQUE (userId, dateString)
            )
          ''');
        }
      },
    );
  }

  // =================================================================
  // FIRESTORE SYNC — REVIEWER CONTENT (shared, not account-specific)
  // =================================================================

  Future<void> syncAll() async {
    final subjects = await syncSubjects();
    for (final subject in subjects) {
      final subjectId = subject['id'] as String;
      final lessons = await syncLessonsForSubject(subjectId);
      for (final lesson in lessons) {
        final lessonId = lesson['id'] as String;
        await syncQuizForLesson(subjectId, lessonId);
      }
    }
  }

  Future<List<Map<String, dynamic>>> syncSubjects() async {
    final snapshot =
        await _firestore.collection('subjects').orderBy('order').get();

    final db = await database;
    final batch = db.batch();
    final rows = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final row = _subjectFromDoc(doc);
      rows.add(row);
      batch.insert(tableSubjects, row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    return rows;
  }

  Future<List<Map<String, dynamic>>> syncLessonsForSubject(
      String subjectId) async {
    final snapshot = await _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('lessons')
        .orderBy('order')
        .get();

    final db = await database;
    final batch = db.batch();
    final rows = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final row = _lessonFromDoc(doc, subjectId);
      rows.add(row);
      batch.insert(tableLessons, row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    return rows;
  }

  Future<List<Map<String, dynamic>>> syncQuizForLesson(
      String subjectId, String lessonId) async {
    final snapshot = await _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('lessons')
        .doc(lessonId)
        .collection('quiz')
        .orderBy('order')
        .get();

    final db = await database;
    final batch = db.batch();
    final rows = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final row = _quizFromDoc(doc, subjectId, lessonId);
      rows.add(row);
      batch.insert(tableQuizQuestions, row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    return rows;
  }

  Map<String, dynamic> _subjectFromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'name': data['name'] ?? '',
      'description': data['description'] ?? '',
      'code': data['code'] ?? '',
      'colorHex': data['colorHex'] ?? '',
      'orderIndex': data['order'] ?? 0,
      'updatedAt':
          (data['updatedAt'] as Timestamp?)?.toDate().toIso8601String(),
    };
  }

  Map<String, dynamic> _lessonFromDoc(
      QueryDocumentSnapshot doc, String subjectId) {
    final data = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'subjectId': subjectId,
      'title': data['title'] ?? '',
      'content': data['content'] ?? '',
      'orderIndex': data['order'] ?? 0,
      'updatedAt':
          (data['updatedAt'] as Timestamp?)?.toDate().toIso8601String(),
    };
  }

  Map<String, dynamic> _quizFromDoc(
      QueryDocumentSnapshot doc, String subjectId, String lessonId) {
    final data = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'subjectId': subjectId,
      'lessonId': lessonId,
      'questionText': data['questionText'] ?? '',
      'optionA': data['optionA'] ?? '',
      'optionB': data['optionB'] ?? '',
      'optionC': data['optionC'] ?? '',
      'optionD': data['optionD'] ?? '',
      'correctOption': data['correctOption'] ?? '',
      'explanation': data['explanation'] ?? '',
      'orderIndex': data['order'] ?? 0,
      'updatedAt':
          (data['updatedAt'] as Timestamp?)?.toDate().toIso8601String(),
    };
  }

  // =================================================================
  // LOCAL READS — REVIEWER CONTENT
  // =================================================================

  Future<List<Map<String, dynamic>>> getSubjects() async {
    final db = await database;
    return db.query(tableSubjects, orderBy: 'orderIndex ASC');
  }

  /// A single subject row by id, or null if it isn't cached locally.
  /// Used by the Subject Detail screen.
  Future<Map<String, dynamic>?> getSubjectById(String subjectId) async {
    final db = await database;
    final rows = await db.query(
      tableSubjects,
      where: 'id = ?',
      whereArgs: [subjectId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getLessons(String subjectId) async {
    final db = await database;
    return db.query(
      tableLessons,
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'orderIndex ASC',
    );
  }

  Future<Map<String, dynamic>?> getLessonById(String lessonId) async {
    final db = await database;
    final rows =
        await db.query(tableLessons, where: 'id = ?', whereArgs: [lessonId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> getLessonCountForSubject(String subjectId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableLessons WHERE subjectId = ?',
      [subjectId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalLessonCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM $tableLessons');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// All quiz questions across every lesson in [subjectId], combined —
  /// used to build the "Take a Subject Quiz" flow (as opposed to a
  /// single lesson's competency quiz).
  Future<List<Map<String, dynamic>>> getQuizQuestionsForSubject(
      String subjectId) async {
    final lessons = await getLessons(subjectId);
    final all = <Map<String, dynamic>>[];
    for (final lesson in lessons) {
      final qs = await getQuizQuestions(lesson['id'] as String);
      all.addAll(qs);
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> getQuizQuestions(String lessonId) async {
    final db = await database;
    return db.query(
      tableQuizQuestions,
      where: 'lessonId = ?',
      whereArgs: [lessonId],
      orderBy: 'orderIndex ASC',
    );
  }

  // =================================================================
  // QUIZ ATTEMPTS — per account, mirrored to Firestore
  // =================================================================

  /// [quizType] should be one of 'competency', 'lesson', 'subject' —
  /// used only for record-keeping; the Home dashboard's average score
  /// blends all types together.
  Future<int> insertQuizAttempt({
    required String uid,
    String? subjectId,
    String? lessonId,
    String? quizType,
    required int score,
    required int totalItems,
    DateTime? dateTaken,
  }) async {
    final db = await database;
    final date = (dateTaken ?? DateTime.now()).toIso8601String();

    final localId = await db.insert(tableQuizAttempts, {
      'userId': uid,
      'subjectId': subjectId,
      'lessonId': lessonId,
      'quizType': quizType,
      'score': score,
      'totalItems': totalItems,
      'dateTaken': date,
      'synced': 0,
    });

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(uid)
          .collection('quizAttempts')
          .add({
        'subjectId': subjectId,
        'lessonId': lessonId,
        'quizType': quizType,
        'score': score,
        'totalItems': totalItems,
        'dateTaken': date,
      });
      await db.update(
        tableQuizAttempts,
        {'firestoreId': docRef.id, 'synced': 1},
        where: 'id = ?',
        whereArgs: [localId],
      );
    } catch (_) {
      // Offline or write failed — local copy is safe, will retry later.
    }

    return localId;
  }

  Future<List<Map<String, dynamic>>> getQuizAttempts({
    required String uid,
    String? subjectId,
    String? lessonId,
  }) async {
    final db = await database;
    final where = <String>['userId = ?'];
    final whereArgs = <Object?>[uid];

    if (subjectId != null) {
      where.add('subjectId = ?');
      whereArgs.add(subjectId);
    }
    if (lessonId != null) {
      where.add('lessonId = ?');
      whereArgs.add(lessonId);
    }

    return db.query(
      tableQuizAttempts,
      where: where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'dateTaken DESC',
    );
  }

  /// Average score across every quiz attempt (competency, lesson, and
  /// subject quizzes combined), as a whole-number percentage. Returns
  /// 0 if the user hasn't taken any quizzes yet.
  Future<int> getAverageScorePercent(String uid) async {
    final db = await database;
    final rows = await db.query(
      tableQuizAttempts,
      columns: ['score', 'totalItems'],
      where: 'userId = ?',
      whereArgs: [uid],
    );
    if (rows.isEmpty) return 0;

    double totalPercent = 0;
    int counted = 0;
    for (final row in rows) {
      final total = row['totalItems'] as int? ?? 0;
      if (total <= 0) continue;
      final score = row['score'] as int? ?? 0;
      totalPercent += (score / total) * 100;
      counted++;
    }
    if (counted == 0) return 0;
    return (totalPercent / counted).round();
  }

  Future<int> clearQuizAttempts(String uid) async {
    final db = await database;
    return db.delete(tableQuizAttempts, where: 'userId = ?', whereArgs: [uid]);
  }

  // =================================================================
  // BOOKMARKS — per account, mirrored to Firestore
  // =================================================================

  Future<bool> isBookmarked(String uid, String questionId) async {
    final db = await database;
    final rows = await db.query(
      tableBookmarks,
      where: 'userId = ? AND questionId = ?',
      whereArgs: [uid, questionId],
    );
    return rows.isNotEmpty;
  }

  Future<bool> toggleBookmark(String uid, String questionId) async {
    final db = await database;
    final alreadyBookmarked = await isBookmarked(uid, questionId);
    final bookmarkDoc = _firestore
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .doc(questionId);

    if (alreadyBookmarked) {
      await db.delete(
        tableBookmarks,
        where: 'userId = ? AND questionId = ?',
        whereArgs: [uid, questionId],
      );
      try {
        await bookmarkDoc.delete();
      } catch (_) {}
      return false;
    } else {
      final date = DateTime.now().toIso8601String();
      await db.insert(tableBookmarks, {
        'userId': uid,
        'questionId': questionId,
        'dateBookmarked': date,
        'synced': 0,
      });
      try {
        await bookmarkDoc.set({'dateBookmarked': date});
        await db.update(
          tableBookmarks,
          {'synced': 1},
          where: 'userId = ? AND questionId = ?',
          whereArgs: [uid, questionId],
        );
      } catch (_) {}
      return true;
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarkedQuestions(
      String uid) async {
    final db = await database;
    return db.rawQuery('''
      SELECT q.*
      FROM $tableQuizQuestions q
      INNER JOIN $tableBookmarks b ON b.questionId = q.id
      WHERE b.userId = ?
      ORDER BY b.dateBookmarked DESC
    ''', [uid]);
  }

  // =================================================================
  // LESSON PROGRESS — drives "Continue by Subject" + overall progress
  // =================================================================

  /// Call this whenever the user opens a lesson. Marks it as the most
  /// recently opened lesson for that subject (and overall).
  Future<void> recordLessonOpened({
    required String uid,
    required String subjectId,
    required String lessonId,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      tableLessonProgress,
      where: 'userId = ? AND lessonId = ?',
      whereArgs: [uid, lessonId],
    );

    if (existing.isEmpty) {
      await db.insert(tableLessonProgress, {
        'userId': uid,
        'subjectId': subjectId,
        'lessonId': lessonId,
        'isCompleted': 0,
        'lastOpenedAt': now,
        'synced': 0,
      });
    } else {
      await db.update(
        tableLessonProgress,
        {'lastOpenedAt': now, 'synced': 0},
        where: 'userId = ? AND lessonId = ?',
        whereArgs: [uid, lessonId],
      );
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('lessonProgress')
          .doc(lessonId)
          .set({'subjectId': subjectId, 'lastOpenedAt': now},
              SetOptions(merge: true));
      await db.update(
        tableLessonProgress,
        {'synced': 1},
        where: 'userId = ? AND lessonId = ?',
        whereArgs: [uid, lessonId],
      );
    } catch (_) {
      // Offline — retried by pushPendingSyncs.
    }
  }

  /// Call this when the user finishes a lesson (e.g. passes its quiz).
  Future<void> markLessonCompleted({
    required String uid,
    required String subjectId,
    required String lessonId,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      tableLessonProgress,
      where: 'userId = ? AND lessonId = ?',
      whereArgs: [uid, lessonId],
    );

    if (existing.isEmpty) {
      await db.insert(tableLessonProgress, {
        'userId': uid,
        'subjectId': subjectId,
        'lessonId': lessonId,
        'isCompleted': 1,
        'lastOpenedAt': now,
        'completedAt': now,
        'synced': 0,
      });
    } else {
      await db.update(
        tableLessonProgress,
        {'isCompleted': 1, 'completedAt': now, 'synced': 0},
        where: 'userId = ? AND lessonId = ?',
        whereArgs: [uid, lessonId],
      );
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('lessonProgress')
          .doc(lessonId)
          .set({
        'subjectId': subjectId,
        'isCompleted': true,
        'completedAt': now,
      }, SetOptions(merge: true));
      await db.update(
        tableLessonProgress,
        {'synced': 1},
        where: 'userId = ? AND lessonId = ?',
        whereArgs: [uid, lessonId],
      );
    } catch (_) {}
  }

  /// Number of lessons the user has completed across ALL subjects.
  Future<int> getCompletedLessonCount(String uid) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableLessonProgress WHERE userId = ? AND isCompleted = 1',
      [uid],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getCompletedLessonCountForSubject(
      String uid, String subjectId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableLessonProgress WHERE userId = ? AND subjectId = ? AND isCompleted = 1',
      [uid, subjectId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// The set of lessonIds within [subjectId] that [uid] has completed —
  /// used by the Subject Detail screen to show a filled vs. outline
  /// circle next to each lesson.
  Future<Set<String>> getCompletedLessonIdsForSubject(
      String uid, String subjectId) async {
    final db = await database;
    final rows = await db.query(
      tableLessonProgress,
      columns: ['lessonId'],
      where: 'userId = ? AND subjectId = ? AND isCompleted = 1',
      whereArgs: [uid, subjectId],
    );
    return rows.map((r) => r['lessonId'] as String).toSet();
  }

  /// Overall progress across GenEd + ProfEd + Specialization combined,
  /// as a whole-number percentage of lessons completed vs. total
  /// lessons that exist.
  Future<int> getOverallProgressPercent(String uid) async {
    final total = await getTotalLessonCount();
    if (total == 0) return 0;
    final completed = await getCompletedLessonCount(uid);
    return ((completed / total) * 100).round();
  }

  Future<int> getSubjectProgressPercent(String uid, String subjectId) async {
    final total = await getLessonCountForSubject(subjectId);
    if (total == 0) return 0;
    final completed = await getCompletedLessonCountForSubject(uid, subjectId);
    return ((completed / total) * 100).round();
  }

  /// For each subject, the last lesson the user opened (title + id),
  /// plus that subject's completion percentage. Subjects with no
  /// activity yet come back with a null lesson.
  Future<List<Map<String, dynamic>>> getContinueBySubject(String uid) async {
    final subjects = await getSubjects();
    final results = <Map<String, dynamic>>[];

    for (final subject in subjects) {
      final subjectId = subject['id'] as String;
      final db = await database;

      final lastOpened = await db.rawQuery('''
        SELECT l.id AS lessonId, l.title AS lessonTitle, p.lastOpenedAt
        FROM $tableLessonProgress p
        INNER JOIN $tableLessons l ON l.id = p.lessonId
        WHERE p.userId = ? AND p.subjectId = ?
        ORDER BY p.lastOpenedAt DESC
        LIMIT 1
      ''', [uid, subjectId]);

      final progressPercent =
          await getSubjectProgressPercent(uid, subjectId);

      results.add({
        'subject': subject,
        'lastLessonId': lastOpened.isEmpty ? null : lastOpened.first['lessonId'],
        'lastLessonTitle':
            lastOpened.isEmpty ? null : lastOpened.first['lessonTitle'],
        'progressPercent': progressPercent,
      });
    }

    return results;
  }

  /// The single most recently opened lesson across every subject —
  /// this is what powers the "Do you wish to continue?" card.
  Future<Map<String, dynamic>?> getLastOpenedLessonOverall(
      String uid) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT l.id AS lessonId, l.title AS lessonTitle,
             s.id AS subjectId, s.name AS subjectName, s.code AS subjectCode,
             p.lastOpenedAt
      FROM $tableLessonProgress p
      INNER JOIN $tableLessons l ON l.id = p.lessonId
      INNER JOIN $tableSubjects s ON s.id = p.subjectId
      WHERE p.userId = ?
      ORDER BY p.lastOpenedAt DESC
      LIMIT 1
    ''', [uid]);

    if (rows.isEmpty) return null;

    final row = rows.first;
    final subjectId = row['subjectId'] as String;
    final progressPercent = await getSubjectProgressPercent(uid, subjectId);

    return {
      ...row,
      'progressPercent': progressPercent,
    };
  }

  // =================================================================
  // ANALYTICS — per-category progress and competency rankings
  // =================================================================

  /// Progress across just the subjects tagged with [categoryCode]
  /// ('GE', 'PE', 'SP', ...), as a whole-number percentage of lessons
  /// completed vs. total lessons that exist in that category.
  Future<int> getCategoryProgressPercent(
      String uid, String categoryCode) async {
    final subjects = await getSubjects();
    final categorySubjects =
        subjects.where((s) => (s['code'] as String?) == categoryCode);

    var total = 0;
    var completed = 0;
    for (final subject in categorySubjects) {
      final subjectId = subject['id'] as String;
      total += await getLessonCountForSubject(subjectId);
      completed += await getCompletedLessonCountForSubject(uid, subjectId);
    }
    if (total == 0) return 0;
    return ((completed / total) * 100).round();
  }

  /// Every lesson ("competency") the user has taken at least one quiz
  /// on, with their average score, ranked best-first. Feeds the
  /// "Strongest Competency" / "Weakest Competency" lists on the
  /// Analytics screen — take the first few for strongest and the
  /// last few (reversed) for weakest.
  Future<List<Map<String, dynamic>>> getCompetencyRankings(
      String uid) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        l.id AS lessonId,
        l.title AS lessonTitle,
        s.name AS subjectName,
        s.code AS subjectCode,
        AVG(
          CASE WHEN a.totalItems > 0
            THEN (a.score * 100.0 / a.totalItems)
            ELSE 0
          END
        ) AS avgScore,
        COUNT(a.id) AS attemptCount
      FROM $tableQuizAttempts a
      INNER JOIN $tableLessons l ON l.id = a.lessonId
      INNER JOIN $tableSubjects s ON s.id = l.subjectId
      WHERE a.userId = ? AND a.lessonId IS NOT NULL
      GROUP BY l.id
      ORDER BY avgScore DESC
    ''', [uid]);
  }

  // =================================================================
  // LEADERBOARD — global ranking, lives on the users/{uid} doc in
  // Firestore (a 'points' field, alongside username/email/createdAt).
  // =================================================================

  /// Top [limit] users by points, ranked 1..limit.
  Future<List<Map<String, dynamic>>> getLeaderboardTop({int limit = 5}) async {
    final snapshot = await _firestore
        .collection('users')
        .orderBy('points', descending: true)
        .limit(limit)
        .get();

    return [
      for (var i = 0; i < snapshot.docs.length; i++)
        {
          'rank': i + 1,
          'uid': snapshot.docs[i].id,
          'username': snapshot.docs[i].data()['username'] ?? 'Student',
          'points': (snapshot.docs[i].data()['points'] ?? 0) as int,
        },
    ];
  }

  /// This user's own points and rank (1-based) among all users, even
  /// if they're outside the top of [getLeaderboardTop].
  Future<Map<String, dynamic>> getUserPointsAndRank(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    final points = (data?['points'] ?? 0) as int;

    final higherCount = await _firestore
        .collection('users')
        .where('points', isGreaterThan: points)
        .count()
        .get();

    return {
      'username': data?['username'] ?? 'You',
      'points': points,
      'rank': (higherCount.count ?? 0) + 1,
    };
  }

  /// Adds [delta] points to this user's leaderboard total. Call this
  /// wherever points should be awarded (e.g. after a passed quiz) —
  /// not wired up to anything yet.
  Future<void> incrementUserPoints(String uid, int delta) async {
    await _firestore.collection('users').doc(uid).set(
      {'points': FieldValue.increment(delta)},
      SetOptions(merge: true),
    );
  }

  // =================================================================
  // APP USAGE LOG — drives the day streak
  // =================================================================

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Call this once per app session (e.g. in the Home screen's
  /// initState, or right after login) to log today as a used day.
  Future<void> recordAppOpenedToday(String uid) async {
    final db = await database;
    final today = _todayString();

    await db.insert(
      tableAppUsage,
      {'userId': uid, 'dateString': today, 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('appUsage')
          .doc(today)
          .set({'openedAt': DateTime.now().toIso8601String()},
              SetOptions(merge: true));
      await db.update(
        tableAppUsage,
        {'synced': 1},
        where: 'userId = ? AND dateString = ?',
        whereArgs: [uid, today],
      );
    } catch (_) {
      // Offline — retried by pushPendingSyncs.
    }
  }

  /// Consecutive days used, counting back from today. If the app
  /// hasn't been opened yet today, the streak still counts as long as
  /// yesterday was used (today just hasn't broken it yet).
  Future<int> getDayStreak(String uid) async {
    final db = await database;
    final rows = await db.query(
      tableAppUsage,
      columns: ['dateString'],
      where: 'userId = ?',
      whereArgs: [uid],
    );
    final usedDates =
        rows.map((r) => r['dateString'] as String).toSet();

    if (usedDates.isEmpty) return 0;

    DateTime cursor = DateTime.now();
    String cursorString() => '${cursor.year.toString().padLeft(4, '0')}-'
        '${cursor.month.toString().padLeft(2, '0')}-'
        '${cursor.day.toString().padLeft(2, '0')}';

    // If today isn't logged yet, start checking from yesterday instead
    // (today not having a record yet shouldn't zero out the streak).
    if (!usedDates.contains(cursorString())) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (usedDates.contains(cursorString())) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // =================================================================
  // ACCOUNT SYNC — call after login and whenever reconnecting
  // =================================================================

  /// Pulls this user's quiz attempts, bookmarks, lesson progress, and
  /// usage log down from Firestore into the local cache. Call this
  /// right after login — it's what restores progress on a fresh
  /// install or new device.
  Future<void> syncUserDataFromFirestore(String uid) async {
    await NotesDbService.instance.syncFromFirestore(uid);
    final db = await database;

    final attemptsSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('quizAttempts')
        .get();
    for (final doc in attemptsSnapshot.docs) {
      final existing = await db.query(
        tableQuizAttempts,
        where: 'firestoreId = ?',
        whereArgs: [doc.id],
      );
      if (existing.isNotEmpty) continue;

      final data = doc.data();
      await db.insert(tableQuizAttempts, {
        'userId': uid,
        'subjectId': data['subjectId'],
        'lessonId': data['lessonId'],
        'quizType': data['quizType'],
        'score': data['score'] ?? 0,
        'totalItems': data['totalItems'] ?? 0,
        'dateTaken': data['dateTaken'] ?? DateTime.now().toIso8601String(),
        'firestoreId': doc.id,
        'synced': 1,
      });
    }

    final bookmarksSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .get();
    for (final doc in bookmarksSnapshot.docs) {
      final data = doc.data();
      await db.insert(
        tableBookmarks,
        {
          'userId': uid,
          'questionId': doc.id,
          'dateBookmarked':
              data['dateBookmarked'] ?? DateTime.now().toIso8601String(),
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final progressSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('lessonProgress')
        .get();
    for (final doc in progressSnapshot.docs) {
      final data = doc.data();
      final existing = await db.query(
        tableLessonProgress,
        where: 'userId = ? AND lessonId = ?',
        whereArgs: [uid, doc.id],
      );
      final row = {
        'userId': uid,
        'subjectId': data['subjectId'] ?? '',
        'lessonId': doc.id,
        'isCompleted': (data['isCompleted'] == true) ? 1 : 0,
        'lastOpenedAt': data['lastOpenedAt'],
        'completedAt': data['completedAt'],
        'synced': 1,
      };
      if (existing.isEmpty) {
        await db.insert(tableLessonProgress, row);
      } else {
        await db.update(
          tableLessonProgress,
          row,
          where: 'userId = ? AND lessonId = ?',
          whereArgs: [uid, doc.id],
        );
      }
    }

    final usageSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('appUsage')
        .get();
    for (final doc in usageSnapshot.docs) {
      await db.insert(
        tableAppUsage,
        {'userId': uid, 'dateString': doc.id, 'synced': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

  }

  /// Retries pushing any local rows that couldn't reach Firestore
  /// earlier (e.g. created while offline). Call opportunistically —
  /// e.g. when connectivity is restored, or on app resume.
  Future<void> pushPendingSyncs(String uid) async {
    final db = await database;

    final pendingAttempts = await db.query(
      tableQuizAttempts,
      where: 'userId = ? AND synced = 0',
      whereArgs: [uid],
    );
    for (final row in pendingAttempts) {
      try {
        final docRef = await _firestore
            .collection('users')
            .doc(uid)
            .collection('quizAttempts')
            .add({
          'subjectId': row['subjectId'],
          'lessonId': row['lessonId'],
          'quizType': row['quizType'],
          'score': row['score'],
          'totalItems': row['totalItems'],
          'dateTaken': row['dateTaken'],
        });
        await db.update(
          tableQuizAttempts,
          {'firestoreId': docRef.id, 'synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (_) {}
    }

    final pendingBookmarks = await db.query(
      tableBookmarks,
      where: 'userId = ? AND synced = 0',
      whereArgs: [uid],
    );
    for (final row in pendingBookmarks) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('bookmarks')
            .doc(row['questionId'] as String)
            .set({'dateBookmarked': row['dateBookmarked']});
        await db.update(
          tableBookmarks,
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (_) {}
    }

    final pendingProgress = await db.query(
      tableLessonProgress,
      where: 'userId = ? AND synced = 0',
      whereArgs: [uid],
    );
    for (final row in pendingProgress) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('lessonProgress')
            .doc(row['lessonId'] as String)
            .set({
          'subjectId': row['subjectId'],
          'isCompleted': row['isCompleted'] == 1,
          'lastOpenedAt': row['lastOpenedAt'],
          'completedAt': row['completedAt'],
        }, SetOptions(merge: true));
        await db.update(
          tableLessonProgress,
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (_) {}
    }

    final pendingUsage = await db.query(
      tableAppUsage,
      where: 'userId = ? AND synced = 0',
      whereArgs: [uid],
    );
    for (final row in pendingUsage) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('appUsage')
            .doc(row['dateString'] as String)
            .set({'openedAt': DateTime.now().toIso8601String()},
                SetOptions(merge: true));
        await db.update(
          tableAppUsage,
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (_) {}
    }
  }

  // =================================================================
  // MAINTENANCE
  // =================================================================

  /// Wipes cached reviewer content plus all local per-account rows for
  /// every user. Does not touch Firestore.
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(tableAppUsage);
    await db.delete(tableLessonProgress);
    await db.delete(tableBookmarks);
    await db.delete(tableQuizAttempts);
    await db.delete(tableQuizQuestions);
    await db.delete(tableLessons);
    await db.delete(tableSubjects);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
