import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/notes_db_service.dart';
import 'home_widgets.dart' show kMaroon, kGold, primaryTextColor, secondaryTextColor;

/// One note card in the list: title, optional topic pill, a short
/// content preview, and the last-updated date. Tapping opens the
/// editor; a trailing delete icon removes it (with confirmation
/// handled by the caller).
class NoteCard extends StatelessWidget {
  final NoteItem note;
  final bool showSubjectLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.showSubjectLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final preview = note.content.trim();
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled note' : note.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor(context),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: kMaroon, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (showSubjectLabel || note.topic.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (showSubjectLabel && note.subjectName.isNotEmpty)
                      _Pill(text: note.subjectName, color: kMaroon),
                    if (note.topic.isNotEmpty)
                      _Pill(text: note.topic, color: kGold, dark: true),
                  ],
                ),
              ],
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor(context),
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Updated ${DateFormat('MMM d, h:mm a').format(note.updatedAt)}',
                style: TextStyle(
                  fontSize: 11,
                  color: secondaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool dark;

  const _Pill({required this.text, required this.color, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Bottom-sheet editor for creating or editing a note. Pops with a
/// map of `{title, topic, content}` on save, or nothing if cancelled.
class NoteEditorSheet extends StatefulWidget {
  final String? initialTitle;
  final String? initialTopic;
  final String? initialContent;
  final String subjectName;

  const NoteEditorSheet({
    super.key,
    required this.subjectName,
    this.initialTitle,
    this.initialTopic,
    this.initialContent,
  });

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _topicController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _topicController = TextEditingController(text: widget.initialTopic ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop({
      'title': _titleController.text.trim(),
      'topic': _topicController.text.trim(),
      'content': _contentController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.subjectName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          TextField(
            controller: _titleController,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: primaryTextColor(context),
            ),
            decoration: const InputDecoration(
              hintText: 'Note title',
              border: InputBorder.none,
            ),
          ),
          TextField(
            controller: _topicController,
            style: TextStyle(fontSize: 13, color: primaryTextColor(context)),
            decoration: InputDecoration(
              hintText: 'Topic (optional, e.g. a lesson name)',
              hintStyle: TextStyle(color: secondaryTextColor(context)),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
              isDense: true,
            ),
          ),
          const Divider(height: 20),
          TextField(
            controller: _contentController,
            maxLines: 8,
            minLines: 4,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: primaryTextColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'Write your notes here...',
              hintStyle: TextStyle(color: secondaryTextColor(context)),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kMaroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 2,
              ),
              child: const Text('Save Note',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple horizontally-scrolling filter chip row for the "All Notes"
/// view: "All" plus one chip per subject that has notes.
class SubjectFilterChips extends StatelessWidget {
  final List<Map<String, String>> subjects;
  final String? selectedSubjectId;
  final ValueChanged<String?> onSelect;

  const SubjectFilterChips({
    super.key,
    required this.subjects,
    required this.selectedSubjectId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: 'All',
            selected: selectedSubjectId == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          for (final s in subjects) ...[
            _Chip(
              label: s['subjectName'] ?? '',
              selected: selectedSubjectId == s['subjectId'],
              onTap: () => onSelect(s['subjectId']),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kMaroon : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kMaroon : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : primaryTextColor(context),
          ),
        ),
      ),
    );
  }
}
