import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/curriculum_data.dart';

/// CurriculumSeedService
/// ----------------------
/// Pushes the fixed curriculum defined in `curriculum_data.dart` into
/// Firestore, using the exact schema `LocalDbService` already expects:
///   subjects/{id}                — name, code, colorHex, order
///   subjects/{id}/lessons/{id}   — title, content, order
///
/// Doc ids and the subject "order" field come from the shared
/// `curriculumSubjectId` / `curriculumLessonId` /
/// `curriculumGlobalSubjectOrder` helpers in `curriculum_data.dart` —
/// the same ones `ContentController` uses when an admin publishes a
/// lesson or assessment straight from the Contents tab. That keeps
/// both flows writing to the exact same docs whether or not this
/// seeder has ever been run.
///
/// This makes `kFixedCurriculum` the single source of truth for
/// subjects and competencies. Call [resetAndSeedFixedCurriculum] once
/// (e.g. from the dev-only button on the Profile screen), then run
/// `LocalDbService.instance.syncAll()` to pull it into the local
/// SQLite cache — SubjectScreen, SubjectDetailScreen, and AdminScreen
/// all read through that cache already, so nothing else needs to
/// change.
///
/// [resetAndSeedFixedCurriculum] deletes every existing subject (and
/// its lessons + any quiz questions under them) first, so the result
/// is exactly `kFixedCurriculum` — nothing left over from previous
/// admin uploads or test seeds.
class CurriculumSeedService {
  CurriculumSeedService._internal();
  static final CurriculumSeedService instance =
      CurriculumSeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> resetAndSeedFixedCurriculum() async {
    await _clearExistingSubjects();
    await _seedFixedCurriculum();
  }

  Future<void> _clearExistingSubjects() async {
    final subjectsSnap = await _firestore.collection('subjects').get();

    for (final subjectDoc in subjectsSnap.docs) {
      final lessonsSnap =
          await subjectDoc.reference.collection('lessons').get();

      for (final lessonDoc in lessonsSnap.docs) {
        final quizSnap = await lessonDoc.reference.collection('quiz').get();
        for (final quizDoc in quizSnap.docs) {
          await quizDoc.reference.delete();
        }
        await lessonDoc.reference.delete();
      }

      await subjectDoc.reference.delete();
    }

    debugPrint(
      'CurriculumSeedService: cleared ${subjectsSnap.docs.length} existing subjects.',
    );
  }

  Future<void> _seedFixedCurriculum() async {
    final now = FieldValue.serverTimestamp();
    var subjectCount = 0;

    for (final category in kFixedCurriculum) {
      for (var s = 0; s < category.subjects.length; s++) {
        final subject = category.subjects[s];
        final subjectId = curriculumSubjectId(category.code, s);

        await _firestore.collection('subjects').doc(subjectId).set({
          'name': subject.name,
          'description': '',
          'code': category.code,
          // Left blank on purpose — subjectColorFor() falls back to
          // kSubjectFallbackColors[code] when colorHex is empty, which
          // already matches GE/PE/SP everywhere else in the app.
          'colorHex': '',
          'order': curriculumGlobalSubjectOrder(subjectId),
          'updatedAt': now,
        });
        subjectCount++;

        final lessonsCollection = _firestore
            .collection('subjects')
            .doc(subjectId)
            .collection('lessons');
        final batch = _firestore.batch();

        for (var c = 0; c < subject.competencies.length; c++) {
          final competency = subject.competencies[c];
          final lessonId = curriculumLessonId(subjectId, c);
          batch.set(lessonsCollection.doc(lessonId), {
            'title': competency.title,
            'content': '',
            'order': c,
            'updatedAt': now,
          });
        }
        await batch.commit();
      }
    }

    debugPrint('CurriculumSeedService: seeded $subjectCount subjects.');
  }
}
