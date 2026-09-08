import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../controllers/content_controller.dart';
import 'home_widgets.dart'
    show kMaroon, primaryTextColor, secondaryTextColor, labelColorFor;

/// The "Lessons" / "Assessment" pill toggle at the top of the
/// Contents tab.
class ContentTabToggle extends StatelessWidget {
  final ContentTab activeTab;
  final ValueChanged<ContentTab> onChanged;

  const ContentTabToggle({
    super.key,
    required this.activeTab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _TogglePill(
              label: 'Lessons',
              selected: activeTab == ContentTab.lessons,
              onTap: () => onChanged(ContentTab.lessons),
            ),
          ),
          Expanded(
            child: _TogglePill(
              label: 'Assessment',
              selected: activeTab == ContentTab.assessment,
              onTap: () => onChanged(ContentTab.assessment),
            ),
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kMaroon : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : primaryTextColor(context),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// White bordered card wrapper used for both the "Upload New ..."
/// form and could be reused elsewhere on the Contents tab.
class ContentFormCard extends StatelessWidget {
  final Widget child;

  const ContentFormCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

/// Dashed-style upload zone. Shows the picked file's name once one is
/// chosen, with a "Change File" / "Remove file" affordance.
class UploadDropzone extends StatelessWidget {
  final String hintText; // e.g. "Upload a .pdf or Word file"
  final PlatformFile? pickedFile;
  final VoidCallback onChooseFile;
  final VoidCallback onClearFile;

  const UploadDropzone({
    super.key,
    required this.hintText,
    required this.pickedFile,
    required this.onChooseFile,
    required this.onClearFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: secondaryTextColor(context).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: kMaroon, shape: BoxShape.circle),
            child: const Icon(Icons.file_upload_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            pickedFile == null ? hintText : pickedFile!.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: pickedFile == null ? FontWeight.w500 : FontWeight.w700,
              color: pickedFile == null
                  ? secondaryTextColor(context)
                  : primaryTextColor(context),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: onChooseFile,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).dividerColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(
                pickedFile == null ? 'Choose File' : 'Change File',
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (pickedFile != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onClearFile,
              child: const Text(
                'Remove file',
                style: TextStyle(color: kMaroon, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bordered, labeled dropdown field (Category / Subject), styled the
/// same way as the role dropdown in AddAdminDialog.
class ContentDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const ContentDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primaryTextColor(context),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: Text(hint, style: TextStyle(fontSize: 13, color: secondaryTextColor(context))),
              icon: Icon(Icons.expand_more_rounded, color: labelColorFor(context)),
              style: TextStyle(fontSize: 14, color: primaryTextColor(context)),
              dropdownColor: Theme.of(context).cardColor,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Competency picker: a dropdown to jump to an existing competency
/// (to edit its content/quiz) or "+ Add New Competency", plus a text
/// field the admin types/edits the actual competency name in. Typing
/// a brand-new name here is what creates a new lesson doc on publish
/// — which is also what makes it show up under the subject on the
/// user-facing Subject Detail screen.
class CompetencyField extends StatelessWidget {
  final List<Map<String, dynamic>> existingLessons;
  final String? selectedLessonId;
  final ValueChanged<String?> onSelect;
  final TextEditingController textController;
  final bool enabled;

  const CompetencyField({
    super.key,
    required this.existingLessons,
    required this.selectedLessonId,
    required this.onSelect,
    required this.textController,
    required this.enabled,
  });

  static const String _addNewValue = '__add_new__';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Competency',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primaryTextColor(context),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedLessonId ?? _addNewValue,
              isExpanded: true,
              icon: Icon(Icons.expand_more_rounded, color: labelColorFor(context)),
              style: TextStyle(fontSize: 14, color: primaryTextColor(context)),
              dropdownColor: Theme.of(context).cardColor,
              items: [
                ...existingLessons.map((l) => DropdownMenuItem(
                      value: l['id'] as String,
                      child: Text(
                        (l['title'] as String?) ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                const DropdownMenuItem(
                  value: _addNewValue,
                  child: Text(
                    '+ Add New Competency',
                    style: TextStyle(fontWeight: FontWeight.w700, color: kMaroon),
                  ),
                ),
              ],
              onChanged: !enabled
                  ? null
                  : (value) => onSelect(value == _addNewValue ? null : value),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: textController,
          enabled: enabled,
          maxLines: 2,
          minLines: 1,
          style: TextStyle(fontSize: 14, color: primaryTextColor(context)),
          decoration: InputDecoration(
            hintText: selectedLessonId == null
                ? 'Type the new competency name'
                : 'Edit competency name',
            hintStyle: TextStyle(fontSize: 12, color: secondaryTextColor(context)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// One row in "Existing Lessons" / "Existing Assessment": subject
/// name + category tag on top, the competency title, and either a
/// read-time caption (lessons) or an item-count "Quiz" tag
/// (assessment).
class ExistingContentCard extends StatelessWidget {
  final String subjectName;
  final String categoryLabel;
  final String competencyTitle;
  final bool isAssessment;
  final int estimatedMinutes;
  final int questionCount;

  const ExistingContentCard({
    super.key,
    required this.subjectName,
    required this.categoryLabel,
    required this.competencyTitle,
    required this.isAssessment,
    this.estimatedMinutes = 0,
    this.questionCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subjectName,
                  style: const TextStyle(
                    color: kMaroon,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                categoryLabel,
                style: TextStyle(
                  color: labelColorFor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            competencyTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: primaryTextColor(context),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: isAssessment
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: kMaroon.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$questionCount item${questionCount == 1 ? '' : 's'} · Quiz',
                      style: const TextStyle(
                        color: kMaroon,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  )
                : Text(
                    '$estimatedMinutes min read',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor(context),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
