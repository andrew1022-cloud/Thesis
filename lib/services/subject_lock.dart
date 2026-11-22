import '../data/curriculum_data.dart';
import 'local_db_fast.dart';
import 'local_db_service.dart';

/// Categories whose subjects must be finished in order: a subject
/// stays locked until the one before it is fully completed.
const Set<String> kSequentialCategories = {'PE'};

/// Returns the name of the previous subject that still has to be
/// finished before [subjectId] can be opened, or null if [subjectId]
/// is open (not in a sequential category, the first subject, or its
/// predecessor is complete).
Future<String?> lockedByPrerequisite(String uid, String subjectId) async {
  for (final category in kFixedCurriculum) {
    if (!kSequentialCategories.contains(category.code)) continue;
    for (var i = 1; i < category.subjects.length; i++) {
      if (curriculumSubjectId(category.code, i) != subjectId) continue;

      final db = LocalDbService.instance;
      final prevId = curriculumSubjectId(category.code, i - 1);
      final lessonCounts = await db.getLessonCountsBySubject();
      final completedCounts = await db.getCompletedCountsBySubject(uid);

      final prev = category.subjects[i - 1];
      final published = lessonCounts[prevId] ?? 0;
      final total = published > 0 ? published : prev.competencies.length;
      final completed = completedCounts[prevId] ?? 0;

      return completed >= total ? null : prev.name;
    }
  }
  return null;
}
