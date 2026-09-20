import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../controllers/content_controller.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/content_widgets.dart';
import '../widgets/home_widgets.dart';
import 'admin_management_screen.dart';
import 'admin_screen.dart';

/// The "Contents" tab: lets an admin publish new lesson material or
/// quiz question banks under a Category → Subject → Competency, and
/// browse everything that's already published.
class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  late final ContentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ContentController();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
        break;
      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminManagementScreen()),
        );
        break;
      case 2:
        // Already on Contents.
        break;
    }
  }

  Future<void> _publish() async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await _controller.publish();
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(_controller.successMessage ?? 'Published.')),
      );
    }
  }

  /// Renders the currently picked PDF (still just sitting in memory,
  /// not yet published) so the admin can check it looks right before
  /// publishing — an actual paginated view, not the extracted text.
  void _previewPdf() {
    final bytes = _controller.pickedPdfBytes;
    if (bytes == null) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Container(
                color: kMaroon,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'PDF Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SfPdfViewer.memory(
                  bytes,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                ),
              ),
            ],
          ),
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
        bottomNavigationBar: AdminBottomNavBar(
          currentIndex: 2,
          onTap: _handleNavTap,
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
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_book_rounded, color: kGold, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
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
                'Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final isLessons = _controller.activeTab == ContentTab.lessons;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentTabToggle(
            activeTab: _controller.activeTab,
            onChanged: _controller.switchTab,
          ),
          const SizedBox(height: 18),

          ContentFormCard(
            child: isLessons ? _buildLessonForm() : _buildAssessmentForm(),
          ),

          const SizedBox(height: 24),
          Text(
            isLessons ? 'Existing Lessons:' : 'Existing Assessment:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 12),
          _buildExistingList(isLessons),
        ],
      ),
    );
  }

  Widget _buildLessonForm() {
    return _buildForm(
      title: 'Upload New Lessons:',
      subtitle: 'Add content for a specific subject topic',
      uploadHint: 'Upload a .pdf or Word file',
      allowPdfPreview: true,
    );
  }

  Widget _buildAssessmentForm() {
    return _buildForm(
      title: 'Upload New Assessments:',
      subtitle: 'Add assessment for a specific subject topic',
      uploadHint: 'Upload a .csv file',
      allowPdfPreview: false,
    );
  }

  Widget _buildForm({
    required String title,
    required String subtitle,
    required String uploadHint,
    required bool allowPdfPreview,
  }) {
    final categoryItems = kContentCategories
        .map((c) => DropdownMenuItem(value: c.code, child: Text(c.label)))
        .toList();

    // Only the selected category's subjects ever appear here — e.g.
    // picking "General Education" only offers GenEd subjects.
    final subjectItems = _controller.subjectsForSelectedCategory
        .map((e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value.name, overflow: TextOverflow.ellipsis),
            ))
        .toList();

    // Only the selected subject's competencies ever appear here — e.g.
    // picking "Purposive Communication in English" only offers that
    // subject's own competencies.
    final competencyItems = _controller.competenciesForSelectedSubject
        .map((e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value.title, overflow: TextOverflow.ellipsis),
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: primaryTextColor(context),
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: secondaryTextColor(context)),
        ),
        const SizedBox(height: 16),

        UploadDropzone(
          hintText: uploadHint,
          pickedFile: _controller.pickedFile,
          onChooseFile: _controller.pickFile,
          onClearFile: _controller.clearFile,
          onPreview: (allowPdfPreview && _controller.canPreviewPickedPdf)
              ? _previewPdf
              : null,
        ),
        const SizedBox(height: 18),

        ContentDropdownField<String>(
          label: 'Category',
          hint: 'Select category',
          value: _controller.selectedCategoryCode,
          items: categoryItems,
          onChanged: (v) {
            if (v != null) _controller.selectCategory(v);
          },
        ),
        const SizedBox(height: 14),

        ContentDropdownField<String>(
          label: 'Subject',
          hint: _controller.selectedCategoryCode == null
              ? 'Select a category first'
              : 'Select subject',
          value: _controller.selectedSubjectId,
          items: subjectItems,
          onChanged: _controller.selectedCategoryCode == null
              ? null
              : (v) {
                  if (v != null) _controller.selectSubject(v);
                },
        ),
        const SizedBox(height: 14),

        ContentDropdownField<String>(
          label: 'Competency',
          hint: _controller.selectedSubjectId == null
              ? 'Select a subject first'
              : 'Select competency',
          value: _controller.selectedCompetencyLessonId,
          items: competencyItems,
          onChanged: _controller.selectedSubjectId == null
              ? null
              : (v) {
                  if (v != null) _controller.selectCompetency(v);
                },
        ),

        if (_controller.formError != null) ...[
          const SizedBox(height: 12),
          Text(
            _controller.formError!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],

        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _controller.isPublishing ? null : _publish,
            style: ElevatedButton.styleFrom(
              backgroundColor: kMaroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 2,
            ),
            child: _controller.isPublishing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Publish',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingList(bool isLessons) {
    final items =
        isLessons ? _controller.existingLessons : _controller.existingAssessments;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          isLessons ? 'No lessons published yet.' : 'No assessments published yet.',
          style: TextStyle(color: secondaryTextColor(context)),
        ),
      );
    }

    return Column(
      children: items
          .map((item) => ExistingContentCard(
                subjectName: item.subjectName,
                categoryLabel: item.categoryLabel,
                competencyTitle: item.competencyTitle,
                isAssessment: !isLessons,
                estimatedMinutes: item.estimatedMinutes,
                questionCount: item.questionCount,
              ))
          .toList(),
    );
  }
}
