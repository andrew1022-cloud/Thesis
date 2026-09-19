import 'package:flutter/material.dart';

import '../services/local_db_service.dart';

/// One subject row on the Subjects screen, with its competency
/// (lesson) completion count.
class SubjectProgressItem {
  final Map<String, dynamic> subject;
  final int completedCount;
  final int totalCount;
  final int progressPercent;

  SubjectProgressItem({
    required this.subject,
    required this.completedCount,
    required this.totalCount,
    required this.progressPercent,
  });
}

/// A category section on the Subjects screen (General Education,
/// Professional Education, Specialization, ...).
class SubjectGroup {
  final String code;
  final String title;
  final List<SubjectProgressItem> subjects;

  SubjectGroup({
    required this.code,
    required this.title,
    required this.subjects,
  });
}

/// Holds all state for the Subjects screen. The UI only reads from
/// this controller — it does not group or compute progress itself.
class SubjectController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;

  SubjectController({required this.uid});

  bool isLoading = true;

  List<SubjectGroup> groups = [];

  // Known category codes, in display order. Any subject whose code
  // isn't one of these falls into its own group at the end, titled
  // after its raw code.
  static const List<String> _categoryOrder = ['GE', 'PE', 'SP'];
  static const Map<String, String> _categoryTitles = {
    'GE': 'General Education',
    'PE': 'Professional Education',
    'SP': 'Specialization',
  };

  Future<void> loadSubjects() async {
    isLoading = true;
    notifyListeners();

    final subjects = await _db.getSubjects();

    final Map<String, List<Map<String, dynamic>>> byCode = {};
    for (final subject in subjects) {
      final code = (subject['code'] as String?) ?? '';
      byCode.putIfAbsent(code, () => []).add(subject);
    }

    final orderedCodes = [
      ..._categoryOrder.where(byCode.containsKey),
      ...byCode.keys.where((c) => !_categoryOrder.contains(c)),
    ];

    final newGroups = <SubjectGroup>[];
    for (final code in orderedCodes) {
      final items = await Future.wait(byCode[code]!.map((subject) async {
        final subjectId = subject['id'] as String;

        // The local cache may not have this subject's lessons synced
        // yet — LocalDbService.syncAll() (kicked off in the
        // background from Home) walks subjects/lessons/quiz
        // sequentially, so a subject visited early can still show
        // 0 lessons locally even though Firestore has them. Rather
        // than showing a stale "0 out of 0" until the user happens
        // to pull-to-refresh, sync just this subject's lessons on
        // demand whenever the local count comes back empty.
        var total = await _db.getLessonCountForSubject(subjectId);
        if (total == 0) {
          await _db.syncLessonsForSubject(subjectId);
          total = await _db.getLessonCountForSubject(subjectId);
        }

        final completed =
            await _db.getCompletedLessonCountForSubject(uid, subjectId);
        final percent = total == 0 ? 0 : ((completed / total) * 100).round();
        return SubjectProgressItem(
          subject: subject,
          completedCount: completed,
          totalCount: total,
          progressPercent: percent,
        );
      }));

      newGroups.add(SubjectGroup(
        code: code,
        title: _categoryTitles[code] ?? (code.isEmpty ? 'Other' : code),
        subjects: items,
      ));
    }

    groups = newGroups;
    isLoading = false;
    notifyListeners();
  }

  /// Pull-to-refresh: sync fresh content from Firestore first, then
  /// rebuild the subject list from the updated local cache.
  Future<void> refresh() async {
    await _db.syncAll();
    await loadSubjects();
  }

  // ---- Actions (hook these up once the exam flows exist) ----
  Future<void> takeSubjectExam(String categoryCode) async {
    // TODO: navigate to the subject-exam flow for this category.
    debugPrint('Take a Subject Exam tapped for "$categoryCode"');
  }

  Future<void> takeMockExam() async {
    // TODO: navigate to the mock-exam flow.
    debugPrint('Take a Mock Exam tapped');
  }
}
