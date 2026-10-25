import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/curriculum_data.dart';
import '../services/local_db_service.dart';
import 'quiz_controller.dart' show QuizController;

/// One row in the "All Users" list on the Admin dashboard.
class AdminUserSummary {
  final String uid;
  final String name;
  final String email;
  final int genEdPercent;
  final int profEdPercent;
  final int specializationPercent;
  final int overallPercent;
  final String lastActiveLabel;

  AdminUserSummary({
    required this.uid,
    required this.name,
    required this.email,
    required this.genEdPercent,
    required this.profEdPercent,
    required this.specializationPercent,
    required this.overallPercent,
    required this.lastActiveLabel,
  });
}

/// Holds all state for the Admin dashboard. The UI only reads from
/// this controller — it does not touch Firestore or LocalDbService
/// directly.
///
/// Reviewer content (subjects/lessons) is shared and already cached
/// locally via [LocalDbService], so category totals are read from
/// there. Per-user completion has to be aggregated straight from
/// Firestore's `users/{uid}/lessonProgress` subcollections, since
/// that's per-account data for every registered user, not just the
/// signed-in one.
class AdminController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDbService _localDb = LocalDbService.instance;

  bool isLoading = true;
  bool isExporting = false;

  int registeredUserCount = 0;
  int averagePreparednessPercent = 0;
  int completedUserCount = 0;

  List<AdminUserSummary> users = [];

  Future<void> loadAdminData() async {
    isLoading = true;
    notifyListeners();

    try {
      // Make sure reviewer content is cached locally, then read the
      // category → lesson-count breakdown from it.
      final subjects = await _localDb.getSubjects();

      final Map<String, String> subjectCodeById = {};
      final Map<String, int> totalByCode = {};
      var totalLessons = 0;

      for (final subject in subjects) {
        final id = subject['id'] as String;
        final code = (subject['code'] as String?) ?? '';
        subjectCodeById[id] = code;
        final count = await _localDb.getLessonCountForSubject(id);
        totalByCode[code] = (totalByCode[code] ?? 0) + count;
        totalLessons += count;
      }

      final usersSnapshot = await _firestore.collection('users').get();

      final summaries = <AdminUserSummary>[];
      var completedCount = 0;
      var preparednessSum = 0;

      for (final userDoc in usersSnapshot.docs) {
        final uid = userDoc.id;
        final data = userDoc.data();
        final name = (data['username'] as String?)?.isNotEmpty == true
            ? data['username'] as String
            : 'Student';
        final email = (data['email'] as String?) ?? '';

        final progressSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('lessonProgress')
            .where('isCompleted', isEqualTo: true)
            .get();

        final Map<String, int> completedByCode = {};
        var completedTotal = 0;
        for (final doc in progressSnap.docs) {
          final subjectId = doc.data()['subjectId'] as String? ?? '';
          final code = subjectCodeById[subjectId] ?? '';
          completedByCode[code] = (completedByCode[code] ?? 0) + 1;
          completedTotal++;
        }

        int percentFor(String code) {
          final total = totalByCode[code] ?? 0;
          if (total == 0) return 0;
          return ((completedByCode[code] ?? 0) / total * 100).round();
        }

        final overallPercent = totalLessons == 0
            ? 0
            : ((completedTotal / totalLessons) * 100).round();

        if (totalLessons > 0 && overallPercent >= 100) completedCount++;
        preparednessSum += overallPercent;

        final lastActiveLabel = await _fetchLastActiveLabel(uid);

        summaries.add(AdminUserSummary(
          uid: uid,
          name: name,
          email: email,
          genEdPercent: percentFor('GE'),
          profEdPercent: percentFor('PE'),
          specializationPercent: percentFor('SP'),
          overallPercent: overallPercent,
          lastActiveLabel: lastActiveLabel,
        ));
      }

      users = summaries;
      registeredUserCount = summaries.length;
      completedUserCount = completedCount;
      averagePreparednessPercent = summaries.isEmpty
          ? 0
          : (preparednessSum / summaries.length).round();
    } catch (e) {
      debugPrint('AdminController: failed to load admin data: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  /// Reads this user's most recent `appUsage` doc (each doc id is a
  /// yyyy-mm-dd date string, with an `openedAt` ISO timestamp field)
  /// and formats it as "Today, HH:mm" or "MMM d, HH:mm".
  Future<String> _fetchLastActiveLabel(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('appUsage')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return 'No activity yet';

      final data = snap.docs.first.data();
      final openedAtRaw = data['openedAt'] as String?;
      final openedAt =
          openedAtRaw != null ? DateTime.tryParse(openedAtRaw) : null;
      if (openedAt == null) return snap.docs.first.id;

      final now = DateTime.now();
      final isToday = openedAt.year == now.year &&
          openedAt.month == now.month &&
          openedAt.day == now.day;
      final timeLabel = DateFormat('HH:mm').format(openedAt);

      return isToday
          ? 'Today, $timeLabel'
          : '${DateFormat('MMM d').format(openedAt)}, $timeLabel';
    } catch (_) {
      return 'Unknown';
    }
  }

  // ---------------------------------------------------------------
  // EXPORT
  // ---------------------------------------------------------------

  Map<String, String>? _subjectNames; // subjectId -> subject name
  Map<String, String>? _lessonTitles; // lessonId  -> competency title
  Map<String, String>? _categoryLabels; // 'GE' -> 'General Education'

  void _buildLookups() {
    if (_subjectNames != null) return;
    final subjects = <String, String>{};
    final lessons = <String, String>{};
    final categories = <String, String>{};

    for (final category in kFixedCurriculum) {
      categories[category.code] = category.label;
      for (var s = 0; s < category.subjects.length; s++) {
        final subject = category.subjects[s];
        final subjectId = curriculumSubjectId(category.code, s);
        subjects[subjectId] = subject.name;
        for (var c = 0; c < subject.competencies.length; c++) {
          lessons[curriculumLessonId(subjectId, c)] =
              subject.competencies[c].title;
        }
      }
    }
    _subjectNames = subjects;
    _lessonTitles = lessons;
    _categoryLabels = categories;
  }

  /// Older attempts may say 'lesson' / 'subject'.
  String _normalizeQuizType(String raw) {
    switch (raw) {
      case 'lesson':
        return 'competency';
      case 'subject':
        return 'topic';
      default:
        return raw;
    }
  }

  String _quizTypeLabel(String type) {
    switch (type) {
      case 'competency':
        return 'Competency Quiz';
      case 'topic':
        return 'Topic Quiz';
      case 'subject_exam':
        return 'Subject Exam';
      case 'mock_exam':
        return 'Mock Exam';
      default:
        return type.isEmpty ? 'Unknown' : type;
    }
  }

  /// Exports every user's progress AND every assessment attempt they
  /// have taken (one row per attempt) as a CSV. Users with no attempts
  /// still get one row, with the assessment columns blank. Returns a
  /// message for the UI to show.
  Future<String> exportUsers() async {
    if (users.isEmpty) return 'No user data to export.';
    if (isExporting) return 'An export is already in progress.';

    isExporting = true;
    notifyListeners();

    try {
      _buildLookups();

      final rows = <List<dynamic>>[
        [
          'Name',
          'Email',
          'General Education %',
          'Professional Education %',
          'Specialization %',
          'Overall Completion %',
          'Last Active',
          'Assessment Type',
          'Category',
          'Subject',
          'Assessment',
          'Attempt #',
          'Date Taken',
          'Score',
          'Total Items',
          'Score %',
          'Result',
        ],
      ];

      var attemptTotal = 0;

      for (final u in users) {
        final userCols = <dynamic>[
          _csvSafe(u.name),
          _csvSafe(u.email),
          u.genEdPercent,
          u.profEdPercent,
          u.specializationPercent,
          u.overallPercent,
          _csvSafe(u.lastActiveLabel),
        ];

        final snap = await _firestore
            .collection('users')
            .doc(u.uid)
            .collection('quizAttempts')
            .get();

        final attempts = snap.docs.map((d) => d.data()).toList()
          ..sort((a, b) => (a['dateTaken'] ?? '')
              .toString()
              .compareTo((b['dateTaken'] ?? '').toString()));

        if (attempts.isEmpty) {
          rows.add([...userCols, ...List.filled(10, '')]);
          continue;
        }

        // Counts attempts per assessment (oldest = #1).
        final attemptCounter = <String, int>{};

        for (final a in attempts) {
          final type = _normalizeQuizType((a['quizType'] as String?) ?? '');
          final subjectId = (a['subjectId'] as String?) ?? '';
          final lessonId = (a['lessonId'] as String?) ?? '';
          final score = (a['score'] as num?)?.toInt() ?? 0;
          final total = (a['totalItems'] as num?)?.toInt() ?? 0;
          final percent = total <= 0 ? 0 : ((score / total) * 100).round();

          // Subject exams store the category code ('GE'...) in subjectId.
          final categoryCode = subjectId.split('_').first.toUpperCase();
          final category = _categoryLabels![categoryCode] ??
              (type == 'mock_exam' ? 'All Categories' : '');

          final subjectName = type == 'subject_exam' || type == 'mock_exam'
              ? ''
              : (_subjectNames![subjectId] ?? subjectId);

          final String assessment;
          switch (type) {
            case 'competency':
              assessment = _lessonTitles![lessonId] ?? lessonId;
              break;
            case 'topic':
              assessment = subjectName;
              break;
            case 'subject_exam':
              assessment =
                  '${_categoryLabels![categoryCode] ?? subjectId} Exam';
              break;
            case 'mock_exam':
              assessment = 'Mock Exam';
              break;
            default:
              assessment = lessonId.isNotEmpty ? lessonId : subjectId;
          }

          final key = '$type|$subjectId|$lessonId';
          final attemptNo = (attemptCounter[key] ?? 0) + 1;
          attemptCounter[key] = attemptNo;

          final date = DateTime.tryParse((a['dateTaken'] ?? '').toString());

          rows.add([
            ...userCols,
            _quizTypeLabel(type),
            _csvSafe(category),
            _csvSafe(subjectName),
            _csvSafe(assessment),
            attemptNo,
            date == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(date),
            score,
            total,
            percent,
            percent >= QuizController.passingPercent ? 'Passed' : 'Retake',
          ]);
          attemptTotal++;
        }
      }

      // UTF-8 BOM so Excel opens non-ASCII names correctly.
      final bytes = Uint8List.fromList(
          [0xEF, 0xBB, 0xBF, ...utf8.encode(csv.encode(rows))]);
      final fileName =
          'reveduc_results_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export user progress & results',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      // On web the download starts immediately and no path is returned.
      if (savedPath == null && !kIsWeb) return 'Export cancelled.';
      return 'Exported ${users.length} users and $attemptTotal assessment '
          'attempts to $fileName';
    } catch (e) {
      debugPrint('AdminController: export failed: $e');
      return 'Export failed. Please try again.';
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  /// Prevents spreadsheet apps from treating text as a formula.
  String _csvSafe(String value) {
    if (value.isNotEmpty && '=+-@'.contains(value[0])) return "'$value";
    return value;
  }

  Future<void> refresh() => loadAdminData();
}
