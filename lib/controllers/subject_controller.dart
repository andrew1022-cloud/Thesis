import 'package:flutter/material.dart';

import '../data/curriculum_data.dart';
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
///
/// The subject *list* itself is always built from [kFixedCurriculum]
/// (the app's single source of truth for what subjects/competencies
/// exist), not from whatever happens to already be synced down from
/// Firestore. A subject only gets a Firestore doc once an admin has
/// published at least one competency for it (see
/// `ContentController._ensureSubjectDoc`) or "Seed Fixed Curriculum"
/// has been run — so relying on the synced `subjects` table alone
/// would silently hide any subject nothing has been published for
/// yet (e.g. only 3 of 13 Specialization subjects showing up). Local
/// data is still used for progress counts and for any metadata
/// (colorHex, etc.) that has actually been synced.
///
/// Subject Exam / Mock Exam navigation lives in SubjectScreen, which
/// opens QuizScreen with the matching QuizMode.
class SubjectController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;

  SubjectController({required this.uid});

  bool isLoading = true;

  List<SubjectGroup> groups = [];

  Future<void> loadSubjects() async {
    isLoading = true;
    notifyListeners();

    final newGroups = <SubjectGroup>[];

    for (final category in kFixedCurriculum) {
      final items = <SubjectProgressItem>[];

      for (var s = 0; s < category.subjects.length; s++) {
        final curriculumSubject = category.subjects[s];
        final subjectId = curriculumSubjectId(category.code, s);

        // Make sure this subject's lessons are synced locally if
        // they haven't been yet — cheap no-op once cached.
        var total = await _db.getLessonCountForSubject(subjectId);
        if (total == 0) {
          await _db.syncLessonsForSubject(subjectId);
          total = await _db.getLessonCountForSubject(subjectId);
        }

        // If nothing has been published/synced for this subject at
        // all yet, fall back to the curriculum's own competency count
        // so it reads "0 out of 13", not the misleading "0 out of 0".
        final totalCount =
            total > 0 ? total : curriculumSubject.competencies.length;

        final completed =
            await _db.getCompletedLessonCountForSubject(uid, subjectId);
        final percent =
            totalCount == 0 ? 0 : ((completed / totalCount) * 100).round();

        // Use the synced Firestore metadata if we have it (real
        // colorHex, description, etc.); otherwise build a minimal
        // stand-in straight from curriculum data so the subject still
        // renders correctly.
        final cachedSubject = await _db.getSubjectById(subjectId);
        final subjectMap = cachedSubject ??
            {
              'id': subjectId,
              'name': curriculumSubject.name,
              'code': category.code,
              'colorHex': '',
            };

        items.add(SubjectProgressItem(
          subject: subjectMap,
          completedCount: completed,
          totalCount: totalCount,
          progressPercent: percent,
        ));
      }

      newGroups.add(SubjectGroup(
        code: category.code,
        title: category.label,
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
}
