import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// SeedService
/// -----------
/// Dev-only helper that pushes a small, self-contained test dataset
/// into Firestore — one subject, one lesson, and a 3-question quiz —
/// using the exact field names LocalDbService's `_subjectFromDoc`,
/// `_lessonFromDoc`, and `_quizFromDoc` expect.
///
/// Usage (see wiring instructions at the bottom of this file):
///   await SeedService.instance.seedTestData();
///   await LocalDbService.instance.syncAll();   // pulls it into SQLite
///
/// All docs use fixed, recognizable IDs (prefixed "test_") so you can
/// find them easily in the Firestore console and safely remove them
/// later with `clearTestData()`.
class SeedService {
  SeedService._internal();
  static final SeedService instance = SeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String testSubjectId = 'test_subject_ge';
  static const String testLessonId = 'test_lesson_reading';
  static const List<String> testQuestionIds = [
    'test_q1',
    'test_q2',
    'test_q3',
  ];

  /// Writes the subject, lesson, and quiz questions. Safe to call more
  /// than once — uses `set()`, so it just overwrites the same docs.
  Future<void> seedTestData() async {
    final now = FieldValue.serverTimestamp();

    // ---- Subject ----
    await _firestore.collection('subjects').doc(testSubjectId).set({
      'name': 'Test Subject: General Education',
      'description': 'Temporary subject created for testing the lesson '
          'and quiz flow. Safe to delete.',
      'code': 'GE',
      'colorHex': '3E5C76',
      'order': 999, // pushed to the end so it doesn't disturb real ordering
      'updatedAt': now,
    });

    // ---- Lesson ----
    await _firestore
        .collection('subjects')
        .doc(testSubjectId)
        .collection('lessons')
        .doc(testLessonId)
        .set({
      'title': 'Test Lesson: Reading Comprehension Basics',
      'content': 'This is placeholder lesson content used for testing. '
          'Reading comprehension is the ability to process text, '
          'understand its meaning, and integrate it with what the '
          'reader already knows. It involves both decoding words and '
          'making sense of the ideas they represent.\n\n'
          'Key strategies include: previewing the text, identifying '
          'the main idea, making inferences, and summarizing what '
          'was read.',
      'order': 0,
      'updatedAt': now,
    });

    // ---- Quiz questions ----
    final questions = [
      {
        'id': testQuestionIds[0],
        'questionText':
            'What is the primary goal of reading comprehension?',
        'optionA': 'Reading as fast as possible',
        'optionB': 'Understanding and integrating meaning from text',
        'optionC': 'Memorizing every word',
        'optionD': 'Counting the number of paragraphs',
        'correctOption': 'B',
        'explanation':
            'Comprehension is about understanding meaning, not speed '
                'or memorization.',
        'order': 0,
      },
      {
        'id': testQuestionIds[1],
        'questionText':
            'Which of the following is a reading comprehension strategy?',
        'optionA': 'Skipping the title',
        'optionB': 'Ignoring unfamiliar words',
        'optionC': 'Making inferences from context',
        'optionD': 'Reading only the last paragraph',
        'correctOption': 'C',
        'explanation':
            'Making inferences helps readers fill in meaning not '
                'explicitly stated in the text.',
        'order': 1,
      },
      {
        'id': testQuestionIds[2],
        'questionText': 'Summarizing a text means...',
        'optionA': 'Copying it word for word',
        'optionB': 'Restating the main ideas in your own words',
        'optionC': 'Reading it out loud',
        'optionD': 'Translating it into another language',
        'correctOption': 'B',
        'explanation':
            'A summary captures the key ideas concisely, in the '
                'reader\'s own words.',
        'order': 2,
      },
    ];

    final batch = _firestore.batch();
    final quizCollection = _firestore
        .collection('subjects')
        .doc(testSubjectId)
        .collection('lessons')
        .doc(testLessonId)
        .collection('quiz');

    for (final q in questions) {
      final id = q['id'] as String;
      final data = Map<String, dynamic>.from(q)..remove('id');
      data['updatedAt'] = now;
      batch.set(quizCollection.doc(id), data);
    }
    await batch.commit();

    debugPrint('SeedService: test subject/lesson/quiz seeded.');
  }

  /// Removes everything created by [seedTestData]. Call this once
  /// you're done testing so the test content doesn't linger in
  /// Firestore or show up for real users.
  Future<void> clearTestData() async {
    final lessonRef = _firestore
        .collection('subjects')
        .doc(testSubjectId)
        .collection('lessons')
        .doc(testLessonId);

    // Delete quiz questions first (subcollection docs aren't removed
    // automatically when the parent doc is deleted).
    final quizSnap = await lessonRef.collection('quiz').get();
    for (final doc in quizSnap.docs) {
      await doc.reference.delete();
    }

    await lessonRef.delete();
    await _firestore.collection('subjects').doc(testSubjectId).delete();

    debugPrint('SeedService: test data cleared.');
  }
}
