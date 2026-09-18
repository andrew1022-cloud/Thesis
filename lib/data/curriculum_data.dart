/// The fixed RevEduc curriculum: three categories (General Education,
/// Professional Education, Specialization/Major), each with a fixed
/// list of subjects and their competencies.
///
/// This is the single source of truth for subjects/competencies.
/// `CurriculumSeedService` pushes it into Firestore's `subjects` /
/// `subjects/{id}/lessons` collections using the exact schema
/// `LocalDbService` already syncs down into SQLite — so nothing else
/// in the app (SubjectScreen, SubjectDetailScreen, AdminScreen,
/// quizzes) needs to change.
library;

class CurriculumCompetency {
  final String code; // e.g. "1.1"
  final String description;

  const CurriculumCompetency(this.code, this.description);

  /// What gets stored as the lesson's title, e.g.
  /// "1.1 Manifest understanding and application of basic concepts...".
  String get title => '$code $description';
}

class CurriculumSubject {
  final String name;
  final List<CurriculumCompetency> competencies;

  const CurriculumSubject({required this.name, required this.competencies});
}

class CurriculumCategory {
  /// Matches the codes already used across the app —
  /// `kSubjectFallbackColors`, `kContentCategories`, `_categoryTitles`,
  /// etc. — so colors/labels/grouping all line up automatically.
  final String code; // 'GE' | 'PE' | 'SP'
  final String label;
  final List<CurriculumSubject> subjects;

  const CurriculumCategory({
    required this.code,
    required this.label,
    required this.subjects,
  });
}

const List<CurriculumCategory> kFixedCurriculum = [
  CurriculumCategory(
    code: 'GE',
    label: 'General Education',
    subjects: [
      CurriculumSubject(
        name: 'Purposive Communication in English',
        competencies: [
          CurriculumCompetency('1.1', 'Use the English language with ease in effective communication'),
          CurriculumCompetency('1.2', 'Use the English language confidently for special purposes'),
        ],
      ),
      CurriculumSubject(
        name: 'Malayuning Komunikasyon sa Wikang Filipino',
        competencies: [
          CurriculumCompetency('2.1', 'Nagagamit ang wikang Filipino sa larangang akademiko'),
          CurriculumCompetency('2.2', "Nagagamit ang wikang Filipino sa iba't-ibang uri ng sulatin"),
        ],
      ),
      CurriculumSubject(
        name: 'Science and Technology',
        competencies: [
          CurriculumCompetency('3.1', "Use scientific knowledge to explain natural phenomena and protect Earth's resources"),
          CurriculumCompetency('3.2', 'Utilize understanding of science to illustrate how technology has become beneficial to Mankind'),
        ],
      ),
      CurriculumSubject(
        name: 'Mathematics',
        competencies: [
          CurriculumCompetency('4.1', 'Exhibit competence in Mathematical concepts and procedures'),
          CurriculumCompetency('4.2', 'Relate Mathematics with the real and the concrete through problems that occur in daily life'),
        ],
      ),
      CurriculumSubject(
        name: 'Readings in Philippine History and Society',
        competencies: [
          CurriculumCompetency('5.1', 'Demonstrate understanding of the significant periods in Philippine history'),
          CurriculumCompetency('5.2', 'Relate the significant periods of Philippine history with the transformation of society'),
        ],
      ),
      CurriculumSubject(
        name: 'The Life and Works of Rizal',
        competencies: [
          CurriculumCompetency('6.1', 'Manifest the ability to analyze how the thoughts, works and valor of Rizal influenced the nation'),
          CurriculumCompetency('6.2', "Show how Rizal's feats of valor influenced the other Philippine heroes"),
        ],
      ),
      CurriculumSubject(
        name: 'Ethics',
        competencies: [
          CurriculumCompetency('7.1', 'Demonstrate understanding of what is good for individuals and society'),
          CurriculumCompetency('7.2', 'Utilize logical inferential skills in resolving moral dilemmas'),
        ],
      ),
      CurriculumSubject(
        name: 'The Contemporary World',
        competencies: [
          CurriculumCompetency('8.1', 'Illustrate ways of relating global issues and concerns with local and global realities'),
          CurriculumCompetency('8.2', 'Identify ways by which the Philippines may participate in efforts to mitigate global problems'),
        ],
      ),
      CurriculumSubject(
        name: 'Art Appreciation',
        competencies: [
          CurriculumCompetency('9.1', 'Demonstrate the ability to interpret artistic creations as expressions of the finer things in life'),
          CurriculumCompetency('9.2', 'Manifest informed appreciation of various forms of art'),
        ],
      ),
      CurriculumSubject(
        name: 'Understanding the Self',
        competencies: [
          CurriculumCompetency('10.1', 'Show familiarity with the factors and forces that affect the development of self-identity'),
          CurriculumCompetency('10.2', 'Demonstrate the commitment to accomplish self-understanding as the means to a successful teaching career'),
        ],
      ),
    ],
  ),
  CurriculumCategory(
    code: 'PE',
    label: 'Professional Education',
    subjects: [
      CurriculumSubject(
        name: 'Foundation of teaching learning process',
        competencies: [
          CurriculumCompetency('1.1', 'Apply philosophical and sociological principles in teaching–learning situations'),
          CurriculumCompetency('1.2', 'Apply foundation theories of special and inclusive education'),
        ],
      ),
      CurriculumSubject(
        name: 'The Professional Teacher',
        competencies: [
          CurriculumCompetency('2.1', "Describe the professional teacher and the ways and means to ensure high standards of the teacher's personal and professional life"),
          CurriculumCompetency('2.2', 'Explain what teaching is and the various roles of a teacher in meeting challenges in the 21st century'),
          CurriculumCompetency('2.3', 'Demonstrate understanding of the concepts of the teacher as a school culture catalyst, transformational leader and educational resources manager with responsibilities as specified in the Code of Ethics for Professional Teachers'),
        ],
      ),
      CurriculumSubject(
        name: 'The Teacher and the School curriculum',
        competencies: [
          CurriculumCompetency('3.1', 'Demonstrate research-based knowledge of the concepts, theories and principles in curriculum planning, design, development and evaluation'),
        ],
      ),
      CurriculumSubject(
        name: 'Methods and Strategies of Teaching',
        competencies: [
          CurriculumCompetency('4.1', 'Demonstrate knowledge of teaching strategies that build and enhance new literacies inclusive of multi-cultural, social, media, financial, cyber/digital, ecological, arts and creativity new literacies across the curriculum'),
          CurriculumCompetency('4.2', 'Prepare developmentally sequenced lesson plans with well aligned learning outcomes and competencies based on K-to-12 spiral curriculum requirement'),
          CurriculumCompetency('4.3', 'Utilize the concepts of new literacies in the 21st century (globalization and multi-cultural literacy, social literacy, media literacy, financial literacy, cyber literacy, digital literacy, eco literacy, arts and creativity literacy, interdisciplinary explorations and other teaching strategies) and shared cultural practices across learning areas'),
        ],
      ),
      CurriculumSubject(
        name: 'Educational Technology',
        competencies: [
          CurriculumCompetency('5.1', 'Employ teaching strategies, methods, instructional materials and technology, classroom management techniques appropriate to subject areas and inclusive of learners from indigenous groups'),
          CurriculumCompetency('5.2', 'Demonstrate skills in developing and using a variety of conventional and non-conventional resources including Information and Communication Technology to address learning goals and needs of various learners'),
        ],
      ),
      CurriculumSubject(
        name: 'Headstart for Toddlers, Child and Adolescent',
        competencies: [
          CurriculumCompetency('6.1', 'Apply pedagogical approaches to the student centered teaching and learning process that is metacognitive, innovative, inclusive and developmentally appropriate for child and adolescent learners'),
          CurriculumCompetency('6.2', 'Appraise a learning environment that is responsive to learners from various family background, economic level groupings, and socio-cultural affiliation'),
          CurriculumCompetency('6.3', "Demonstrate understanding of differentiated teaching to suit the learner's gender, strengths, interests, experiences and needs"),
          CurriculumCompetency('6.4', 'Draw implications of research findings related to child development along biological, cognitive, linguistic, socio-cultural dimensions'),
        ],
      ),
      CurriculumSubject(
        name: 'Validating theoretical knowledge in the actual assessment of learning',
        competencies: [
          CurriculumCompetency('7.1', 'Demonstrate understanding of principles in constructing traditional, alternative/authentic forms of high quality assessment'),
          CurriculumCompetency('7.2', 'Apply knowledge and skills in the development and use of assessment tools for formative and summative purposes'),
          CurriculumCompetency('7.3', 'Apply rules in test construction and use of authentic assessment tools for product and process assessment'),
          CurriculumCompetency('7.4', 'Demonstrate skills in interpreting assessment results to improve learning'),
          CurriculumCompetency('7.5', 'Comprehend and apply basic concepts of statistics in educational assessment and evaluation'),
          CurriculumCompetency('7.6', 'Demonstrate knowledge of providing timely, accurate and constructive feedback to learners and parents'),
        ],
      ),
      CurriculumSubject(
        name: 'Documentation of Experiential Learning',
        competencies: [
          CurriculumCompetency('8.1', 'Describe authentic experiential learning from field study and actual classroom immersion as a prospective teacher'),
          CurriculumCompetency('8.2', 'Demonstrate skills in teaching assistantship and guided mentored classroom teaching'),
          CurriculumCompetency('8.3', 'Prepare portfolio on process of learning behavior, motivation, classroom management and assessment from direct observation of teaching learning episodes in an actual school environment'),
          CurriculumCompetency('8.4', 'Demonstrate reflective thinking and teaching'),
        ],
      ),
      CurriculumSubject(
        name: 'Action Research',
        competencies: [
          CurriculumCompetency('9.1', 'Demonstrate ability to identify teaching/learning problems and offer recommendations based on research'),
        ],
      ),
    ],
  ),
  CurriculumCategory(
    code: 'SP',
    label: 'Specialization',
    subjects: [
      CurriculumSubject(
        name: 'Industrial Arts I and II',
        competencies: [
          CurriculumCompetency('1.1', 'Manifest understanding and application of basic concepts, theories, and principles related to Industrial Arts'),
          CurriculumCompetency('1.2', 'Apply appropriate teaching strategies in exploratory Industrial Art Courses'),
        ],
      ),
      CurriculumSubject(
        name: 'Home Economics Literacy, Family, and Consumer Life Skills',
        competencies: [
          CurriculumCompetency('2.1', 'Demonstrate understanding of Home Economics literacy'),
          CurriculumCompetency('2.2', 'Demonstrate understanding of family and consumer life skills'),
        ],
      ),
      CurriculumSubject(
        name: 'Introduction to ICT',
        competencies: [
          CurriculumCompetency('3.1', 'Demonstrate understanding of introductory concepts in ICT'),
          CurriculumCompetency('3.2', 'Demonstrate foundational digital skills in creating, utilizing, and managing documents using productivity software (e.g., word processors, spreadsheets, and presentation tools)'),
        ],
      ),
      CurriculumSubject(
        name: 'Agriculture and Fishery Arts (Part 1 and Part 2)',
        competencies: [
          CurriculumCompetency('4.1', 'Demonstrate understanding and application of basic knowledge, skills, and principles in Agriculture and Fishery Arts (AFA)'),
        ],
      ),
      CurriculumSubject(
        name: 'Common Competencies',
        competencies: [
          CurriculumCompetency('5.1', 'Select, use, and maintain tools and equipment properly'),
          CurriculumCompetency('5.2', 'Perform basic mensuration and calculations'),
          CurriculumCompetency('5.3', 'Read and interpret plans and drawings'),
          CurriculumCompetency('5.4', 'Practice occupational health, safety, and ethical values in the workplace'),
          CurriculumCompetency('5.5', 'Apply foundational knowledge and skills with emphasis on communication, teamwork, work ethics, and problem solving'),
        ],
      ),
      CurriculumSubject(
        name: 'Entrepreneurship',
        competencies: [
          CurriculumCompetency('6.1', 'Evaluate potential business opportunities based on market needs and trends'),
          CurriculumCompetency('6.2', 'Analyze financial statements, manage budgets, and assess funding sources for startups'),
          CurriculumCompetency('6.3', 'Demonstrate understanding and apply ethical business practices, corporate social responsibility, and sustainability principles'),
        ],
      ),
      CurriculumSubject(
        name: 'Technology for Teaching and Learning',
        competencies: [
          CurriculumCompetency('7.1', 'Apply and integrate effectively various educational technologies to support teaching and learning strategies'),
          CurriculumCompetency('7.2', 'Evaluate online resources, use search engines efficiently, and manage digital content responsibly'),
          CurriculumCompetency('7.3', 'Design engaging lessons using multimedia, gamification, and adaptive learning platforms to cater to diverse student needs'),
        ],
      ),
      CurriculumSubject(
        name: 'Animation',
        competencies: [
          CurriculumCompetency('8.1', 'Apply the processes involved in Pre-Project Planning, including script writing and storyboarding'),
          CurriculumCompetency('8.2', 'Apply traditional drawing techniques for animation'),
          CurriculumCompetency('8.3', 'Produce key drawings for animation'),
          CurriculumCompetency('8.4', 'Produce cleaned-up and in-between drawings'),
          CurriculumCompetency('8.5', 'Follow the procedure in 2D digital animation'),
          CurriculumCompetency('8.6', 'Use an authoring tool to create an instructive sequence'),
          CurriculumCompetency('8.7', 'Integrate audio elements such as voiceovers, sound effects, and background music to enhance animation'),
        ],
      ),
      CurriculumSubject(
        name: 'Computer Programming',
        competencies: [
          CurriculumCompetency('9.1', 'Identify and define the different components of a computer system'),
          CurriculumCompetency('9.2', 'Compare and understand the different number systems, such as binary, octal, decimal, and hexadecimal number systems'),
          CurriculumCompetency('9.3', 'Perform number conversion, fixed-point, and floating-point number representation'),
          CurriculumCompetency('9.4', 'Manifest understanding of the basics of the digital logic system'),
          CurriculumCompetency('9.5', 'Identify the different levels of programming'),
          CurriculumCompetency('9.6', 'Demonstrate understanding of important social and ethical concerns related to the use of computing technologies'),
          CurriculumCompetency('9.7', 'Evaluate tools and technologies to identify best practices in computing development'),
          CurriculumCompetency('9.8', 'Design, implement, test, and debug a program based on a given specification using fundamental programming components (variables, data types, and operators; basic computation; simple I/O; flowcharts and other diagramming tools; conditional and iterative structures; definition of array, function, and parameter)'),
        ],
      ),
      CurriculumSubject(
        name: 'Computer Hardware Servicing',
        competencies: [
          CurriculumCompetency('10.1', 'Observe the procedure for assembling a computer with occupational health and safety precautions'),
          CurriculumCompetency('10.2', 'Identify tools and equipment in computer system sourcing'),
          CurriculumCompetency('10.3', 'Compare the parts and functions of the computer system unit'),
          CurriculumCompetency('10.4', 'Identify the different types of software and their functions'),
          CurriculumCompetency('10.5', 'Follow the procedure in computer assembly with safety precautions'),
          CurriculumCompetency('10.6', 'Follow the procedure for testing, updating, and checking peripheral drivers and application software with safety precautions'),
          CurriculumCompetency('10.7', 'Demonstrate skill in computer maintenance'),
          CurriculumCompetency('10.8', 'Diagnose hardware problems and determine appropriate solutions using diagnostic tools and procedures'),
          CurriculumCompetency('10.9', 'Perform basic troubleshooting and repair procedures on computer peripherals (keyboard, mouse, cables)'),
          CurriculumCompetency('10.10', 'Follow ethical practices in handling client data, hardware components, and licensed software'),
        ],
      ),
      CurriculumSubject(
        name: 'Visual Graphic Design',
        competencies: [
          CurriculumCompetency('11.1', 'Apply design principles and drawing techniques such as balance, contrast, alignment, hierarchy, and proximity'),
          CurriculumCompetency('11.2', 'Apply drawing rendering techniques'),
          CurriculumCompetency('11.3', 'Discuss the basics of animation, clean-up and in-between drawing, and simple drawings'),
          CurriculumCompetency('11.4', 'Navigate illustration software'),
          CurriculumCompetency('11.5', 'Apply techniques in digitized drawing using illustration software'),
          CurriculumCompetency('11.6', 'Follow the procedure for vectorized drawing using illustration software'),
          CurriculumCompetency('11.7', 'Follow ethical standards in design practices, including respect for intellectual property and responsible content creation'),
          CurriculumCompetency('11.8', 'Discuss and apply the principles and elements of design and layout'),
        ],
      ),
      CurriculumSubject(
        name: 'Assessment and Evaluation',
        competencies: [
          CurriculumCompetency('12.1', 'Demonstrate understanding of theories and principles of assessment and evaluation applied in ICT'),
        ],
      ),
      CurriculumSubject(
        name: 'Research',
        competencies: [
          CurriculumCompetency('13.1', 'Apply basic research understanding and skills in ICT'),
        ],
      ),
    ],
  ),
];

// =================================================================
// DETERMINISTIC IDS
// =================================================================
//
// Both the admin "Contents" publishing flow (ContentController) and
// the dev-only curriculum seeder (CurriculumSeedService) need the
// exact same Firestore doc ids for a given (category, subject index)
// and (subject, competency index) pair — otherwise publishing a
// lesson from the admin form could write to a different doc than the
// one the seeder created (or vice versa). These three helpers are the
// single source of truth for that scheme.

String _curriculumPad(int oneBasedIndex) =>
    oneBasedIndex.toString().padLeft(2, '0');

/// Deterministic `subjects/{id}` doc id for the [index]-th (0-based)
/// subject under the category with [categoryCode].
String curriculumSubjectId(String categoryCode, int index) =>
    '${categoryCode.toLowerCase()}_${_curriculumPad(index + 1)}';

/// Deterministic `subjects/{subjectId}/lessons/{id}` doc id for the
/// [index]-th (0-based) competency under [subjectId].
String curriculumLessonId(String subjectId, int index) =>
    '${subjectId}_c${_curriculumPad(index + 1)}';

/// The running "order" index (0-based) a subject should be written
/// with, counting across every category in [kFixedCurriculum] in
/// order — matches the "order" field subjects are sorted by
/// everywhere else in the app (SubjectScreen, LocalDbService, ...).
int curriculumGlobalSubjectOrder(String subjectId) {
  var order = 0;
  for (final category in kFixedCurriculum) {
    for (var i = 0; i < category.subjects.length; i++) {
      if (curriculumSubjectId(category.code, i) == subjectId) return order;
      order++;
    }
  }
  return 0;
}