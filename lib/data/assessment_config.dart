// Assessment rules for RevEduc: how many questions each assessment has,
// the Easy/Moderate/Difficult mix, and how much of each exam each
// subject covers. Change numbers here — nothing else needs to be touched.

/// Difficulty tag on a quiz question (stored lowercase in Firestore /
/// SQLite as `difficulty`).
enum Difficulty { easy, moderate, difficult }

/// Forgiving parser: 'Easy', 'hard', 'Medium', blank, etc. Anything
/// that isn't clearly easy or difficult counts as moderate.
Difficulty parseDifficulty(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'easy':
      return Difficulty.easy;
    case 'difficult':
    case 'hard':
      return Difficulty.difficult;
    default:
      return Difficulty.moderate;
  }
}

// ── Sizes ─────────────────────────────────────────────────────────

const int kCompetencyQuizCount = 5; // one competency (lesson)
const int kTopicQuizCount = 15; // all competencies of one topic (subject)
const int kSubjectExamCount = 150; // one category: GE / PE / SP

/// Mock exam questions per category. Edit the split here if the mock
/// exam should weigh categories differently (e.g. 90 / 180 / 180).
const Map<String, int> kMockExamCategoryCounts = {
  'GE': 150,
  'PE': 150,
  'SP': 150,
};

final int kMockExamCount =
    kMockExamCategoryCounts.values.fold(0, (a, b) => a + b);

// ── Difficulty mix (percent) ──────────────────────────────────────

const Map<Difficulty, int> kDifficultyMix = {
  Difficulty.easy: 30,
  Difficulty.moderate: 50,
  Difficulty.difficult: 20,
};

// ── Exam blueprints ───────────────────────────────────────────────

/// One line of an exam blueprint: a percentage of the exam shared by
/// one or more subjects. [subjectIndices] are 0-based positions of the
/// subjects inside that category in `kFixedCurriculum`. Subjects in
/// the same group split the group's percentage evenly.
class ExamGroup {
  final String label;
  final List<int> subjectIndices;
  final double percent;

  const ExamGroup(this.label, this.subjectIndices, this.percent);
}

const Map<String, List<ExamGroup>> kExamBlueprint = {
  // ── General Education ───────────────────────────────────────────
  // 0 Purposive Communication in English
  // 1 Malayuning Komunikasyon sa Wikang Filipino
  // 2 Science and Technology
  // 3 Mathematics
  // 4 Readings in Philippine History and Society
  // 5 The Life and Works of Rizal
  // 6 Ethics
  // 7 The Contemporary World
  // 8 Art Appreciation
  // 9 Understanding the Self
  'GE': [
    ExamGroup('Communication, Science & Math', [0, 1, 2, 3], 40),
    ExamGroup('History, Rizal & Ethics', [4, 5, 6], 30),
    ExamGroup('Contemporary World, Art & Self', [7, 8, 9], 30),
  ],

  // ── Professional Education ──────────────────────────────────────
  // 0 The Child and Adolescent Learners and Learning Principles
  // 1 The Teaching Profession
  // 2 The Teacher and the Community, School Culture and Organizational Leadership
  // 3 Foundation of Special and Inclusive Education
  // 4 Facilitating Learner-Centered Teaching
  // 5 Assessment in Learning 1
  // 6 Assessment in Learning 2
  // 7 Technology for Teaching and Learning 1
  // 8 The Teacher and the School Curriculum
  // 9 Building and Enhancing New Literacies Across the Curriculum
  // 10 Field Study 1
  // 11 Field Study 2
  // 12 Teaching Internship
  'PE': [
    ExamGroup('Learners & Learning Principles', [0, 3], 20),
    ExamGroup('Teaching Profession & Community', [1, 2], 15),
    ExamGroup('Teaching, Curriculum, Technology & Literacies', [4, 7, 8, 9], 30),
    ExamGroup('Assessment in Learning', [5, 6], 15),
    ExamGroup('Field Study & Teaching Internship', [10, 11, 12], 20),
  ],

  // ── Specialization ──────────────────────────────────────────────
  // 0 Industrial Arts I and II
  // 1 Home Economics Literacy, Family, and Consumer Life Skills
  // 2 Introduction to ICT
  // 3 Agriculture and Fishery Arts (Part 1 and Part 2)
  // 4 Common Competencies
  // 5 Entrepreneurship
  // 6 Technology for Teaching and Learning
  // 7 Animation
  // 8 Computer Programming
  // 9 Computer Hardware Servicing
  // 10 Visual Graphic Design
  // 11 Assessment and Evaluation
  // 12 Research
  //
  // NOTE: these percentages add up to 78, not 100. QuizBuilder
  // normalizes them (each share is scaled by 100/78), so the exam still
  // has exactly 150 questions and the relative weights are preserved.
  'SP': [
    ExamGroup('Industrial Arts I and II', [0], 7),
    ExamGroup('Home Economics Literacy', [1], 7),
    ExamGroup('Introduction to ICT', [2], 7),
    ExamGroup('Agriculture and Fishery Arts', [3], 7),
    ExamGroup('Common Competencies', [4], 4),
    ExamGroup('Entrepreneurship', [5], 2),
    ExamGroup('Technology for Teaching and Learning', [6], 2),
    ExamGroup('Animation', [7], 7),
    ExamGroup('Computer Programming', [8], 7),
    ExamGroup('Computer Hardware Servicing', [9], 7),
    ExamGroup('Visual Graphic Design', [10], 7),
    ExamGroup('Assessment and Evaluation in ICT', [11], 9),
    ExamGroup('Research in ICT', [12], 5),
  ],
};
