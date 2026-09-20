import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../controllers/lesson_controller.dart';
import '../controllers/quiz_controller.dart' show QuizMode;
import '../widgets/home_widgets.dart';
import '../widgets/subject_widgets.dart';
import 'pdf_viewer_screen.dart';
import 'quiz_screen.dart';

/// Shown when a lesson row is tapped from the Subject Detail screen.
///
/// If the admin published the lesson from a PDF, that PDF is rendered
/// directly — real pages, real layout, images, headings — instead of
/// the plain-text extraction. The PDF is stored in Firestore as chunks
/// (see LessonPdfService) and reassembled by LessonController. The
/// extracted `content` text is only shown as a fallback for lessons
/// with no source PDF (e.g. published from a Word file).
class LessonScreen extends StatefulWidget {
  final String subjectId;
  final String lessonId;

  const LessonScreen({
    super.key,
    required this.subjectId,
    required this.lessonId,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final LessonController _controller;
  final PdfViewerController _pdfController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = LessonController(
      uid: uid,
      subjectId: widget.subjectId,
      lessonId: widget.lessonId,
    );
    _controller.loadLesson();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openQuiz() async {
    // Returning true tells the Subject Detail screen behind this one
    // to refresh, since completing the quiz may have marked the
    // lesson complete.
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          mode: QuizMode.competency,
          subjectId: widget.subjectId,
          lessonId: widget.lessonId,
          title: (_controller.lesson?['title'] as String?) ?? 'Quiz',
        ),
      ),
    );
    if (result == true) {
      await _controller.loadLesson();
    }
  }

  /// Opens the PDF in its own full-screen viewer (more room to read
  /// and zoom) — reachable from the "Full Screen" action.
  void _openPdfFullScreen(Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          bytes: bytes,
          title: (_controller.lesson?['title'] as String?) ?? 'Lesson PDF',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: kMaroon,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              children: [
                Container(
                  color: kMaroon,
                  height: MediaQuery.of(context).padding.top,
                ),
                _buildHeader(),
                Expanded(
                  child: _controller.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: kMaroon))
                      : _buildBody(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: kMaroon,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.chevron_left,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 6),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.menu_book_rounded, color: kGold, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RevEduc',
                  style: TextStyle(
                    color: kGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Lesson',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final lesson = _controller.lesson;

    if (lesson == null) {
      return Center(
        child: Text(
          'Lesson not found.',
          style: TextStyle(color: secondaryTextColor(context)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLessonInfo(lesson),
        Expanded(
          child: _controller.hasPdf
              ? _buildPdfSection()
              : _buildTextOnlyBody(lesson),
        ),
      ],
    );
  }

  /// Title + completion badge — shown above whichever content area
  /// (PDF or fallback text) is rendered below it.
  Widget _buildLessonInfo(Map<String, dynamic> lesson) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson['title'] as String,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _controller.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 16,
                color: _controller.isCompleted
                    ? Colors.green
                    : secondaryTextColor(context),
              ),
              const SizedBox(width: 6),
              Text(
                _controller.isCompleted ? 'Completed' : 'Not completed yet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _controller.isCompleted
                      ? Colors.green
                      : secondaryTextColor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The PDF area itself: spinner while the chunks download, an error
  /// with "Try again" if that failed, otherwise the rendered document.
  Widget _buildPdfViewerArea() {
    if (_controller.isPdfLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: kMaroon),
            const SizedBox(height: 12),
            Text(
              'Loading PDF…',
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor(context),
              ),
            ),
          ],
        ),
      );
    }

    final bytes = _controller.pdfBytes;
    if (bytes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_rounded,
                  size: 36, color: secondaryTextColor(context)),
              const SizedBox(height: 10),
              Text(
                "Couldn't load the PDF. Check your connection and try again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _controller.loadPdf,
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    color: kMaroon,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SfPdfViewer.memory(
      bytes,
      controller: _pdfController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
    );
  }

  /// Primary reading experience for a lesson published from a PDF:
  /// the real document, rendered page-by-page in its original format.
  /// Actions (full screen, mark complete, quiz) are pinned in a bar
  /// underneath so they're always reachable.
  Widget _buildPdfSection() {
    final bytes = _controller.pdfBytes;

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildPdfViewerArea(),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      bytes == null ? null : () => _openPdfFullScreen(bytes),
                  icon: const Icon(Icons.fullscreen_rounded, color: kMaroon),
                  label: const Text(
                    'Full Screen',
                    style: TextStyle(
                      color: kMaroon,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kMaroon, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _controller.isCompleted
                      ? null
                      : _controller.markComplete,
                  icon: Icon(_controller.isCompleted
                      ? Icons.check
                      : Icons.check_circle_outline),
                  label: Text(
                    _controller.isCompleted ? 'Completed' : 'Mark Complete',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _controller.isCompleted
                        ? Colors.grey.shade400
                        : kMaroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ExamActionButton(
            label: _controller.hasQuiz
                ? 'Take Competency Quiz'
                : 'No Quiz Available Yet',
            onPressed: _controller.hasQuiz ? _openQuiz : null,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Fallback for lessons published without a source PDF (e.g. a
  /// Word upload) — the only case where the plain-text `content`
  /// field is shown at all.
  Widget _buildTextOnlyBody(Map<String, dynamic> lesson) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              (lesson['content'] as String?)?.isNotEmpty == true
                  ? lesson['content'] as String
                  : 'No content added for this lesson yet.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: primaryTextColor(context),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed:
                  _controller.isCompleted ? null : _controller.markComplete,
              icon: Icon(_controller.isCompleted
                  ? Icons.check
                  : Icons.check_circle_outline),
              label: Text(
                _controller.isCompleted
                    ? 'Marked as Complete'
                    : 'Mark as Complete',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _controller.isCompleted ? Colors.grey.shade400 : kMaroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const ActionDivider(),
          ExamActionButton(
            label: _controller.hasQuiz
                ? 'Take Competency Quiz'
                : 'No Quiz Available Yet',
            onPressed: _controller.hasQuiz ? _openQuiz : null,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
