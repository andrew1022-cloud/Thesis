import 'package:flutter/material.dart';

import '../data/curriculum_data.dart';
import '../services/local_db_fast.dart';
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

/// Holds all state for the Subjects screen.
///
/// The subject list is built from [kFixedCurriculum]. Progress is read
/// with three grouped SQLite queries (lesson counts, completed counts,
/// subject metadata) instead of several queries — and a Firestore call
/// for every unpublished subject — per subject, which is what made this
/// screen slow.
class SubjectController extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  final String uid;

  SubjectController({required this.uid});

  bool _disposed = false;

  bool isLoading = true;

  List<SubjectGroup> groups = [];

  Future<void> loadSubjects() async {
    isLoading = true;
    notifyListeners();

    var lessonCounts = await _db.getLessonCountsBySubject();

    // Fresh install / cleared cache: nothing local yet, so do ONE sync
    // (not one per subject). After that, local reads are instant.
    if (lessonCounts.isEmpty) {
      try {
        await _db.syncAllFast(force: true);
        lessonCounts = await _db.getLessonCountsBySubject();
      } catch (e) {
        debugPrint('SubjectController: initial sync failed: $e');
      }
    }

    groups = await _buildGroups(lessonCounts);
    isLoading = false;
    notifyListeners();

    // Quietly pick up newly published content (throttled), and rebuild
    // only if something actually changed.
    _backgroundRefresh(lessonCounts);
  }

  Future<List<SubjectGroup>> _buildGroups(
      Map<String, int> lessonCounts) async {
    final completedCounts = await _db.getCompletedCountsBySubject(uid);
    final cachedSubjects = await _db.getSubjectsById();

    final newGroups = <SubjectGroup>[];

    for (final category in kFixedCurriculum) {
      final items = <SubjectProgressItem>[];

      for (var s = 0; s < category.subjects.length; s++) {
        final curriculumSubject = category.subjects[s];
        final subjectId = curriculumSubjectId(category.code, s);

        final total = lessonCounts[subjectId] ?? 0;
        // Nothing published for this subject yet: use the curriculum's
        // own competency count so it reads "0 out of 13", not "0 out of 0".
        final totalCount =
            total > 0 ? total : curriculumSubject.competencies.length;

        final completed = completedCounts[subjectId] ?? 0;
        final percent =
            totalCount == 0 ? 0 : ((completed / totalCount) * 100).round();

        final subjectMap = cachedSubjects[subjectId] ??
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

    return newGroups;
  }

  Future<void> _backgroundRefresh(Map<String, int> before) async {
    try {
      await _db.syncAllFast();
      if (_disposed) return;
      final after = await _db.getLessonCountsBySubject();
      if (after.toString() == before.toString()) return;
      groups = await _buildGroups(after);
      notifyListeners();
    } catch (e) {
      debugPrint('SubjectController: background sync failed: $e');
    }
  }

  /// Pull-to-refresh: force a real sync, then rebuild from the cache.
  Future<void> refresh() async {
    try {
      await _db.syncAllFast(force: true);
    } catch (e) {
      debugPrint('SubjectController: refresh sync failed: $e');
    }
    groups = await _buildGroups(await _db.getLessonCountsBySubject());
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
