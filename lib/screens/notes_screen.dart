import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/notes_controller.dart';
import '../services/notes_db_service.dart';
import '../widgets/home_widgets.dart';
import '../widgets/notes_widgets.dart';

/// Notes screen. Two modes:
/// - Scoped: pass [subjectId] + [subjectName] (e.g. from a Subject
///   Detail screen) to show/create notes for just that subject.
/// - Unscoped: leave them null (e.g. from a "My Notes" profile entry)
///   to browse every note across all subjects, with a subject filter
///   and search.
class NotesScreen extends StatefulWidget {
  final String? subjectId;
  final String? subjectName;

  const NotesScreen({super.key, this.subjectId, this.subjectName});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final NotesController _controller;
  final TextEditingController _searchController = TextEditingController();

  bool get _isScoped => widget.subjectId != null;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = NotesController(
      uid: uid,
      subjectId: widget.subjectId,
      initialSubjectName: widget.subjectName,
    );
    _controller.loadNotes();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor({NoteItem? existing}) async {
    final subjectNameForEditor = _isScoped
        ? (widget.subjectName ?? '')
        : (existing?.subjectName ?? 'General');

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NoteEditorSheet(
        subjectName: subjectNameForEditor,
        initialTitle: existing?.title,
        initialTopic: existing?.topic,
        initialContent: existing?.content,
      ),
    );

    if (result == null) return;

    if (existing != null) {
      await _controller.updateNote(
        noteId: existing.id,
        title: result['title'],
        topic: result['topic'],
        content: result['content'],
      );
    } else {
      // Unscoped "new note" without a subject picker yet defaults to
      // a general bucket — wire a subject picker in here if your app
      // wants notes to always require a subject.
      await _controller.addNote(
        subjectId: widget.subjectId ?? 'general',
        subjectName: widget.subjectName ?? 'General',
        title: result['title'] ?? '',
        topic: result['topic'] ?? '',
        content: result['content'] ?? '',
      );
    }
  }

  Future<void> _confirmDelete(NoteItem note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete note?',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: primaryTextColor(context))),
        content: Text(
          note.title.isEmpty
              ? 'This note will be permanently removed.'
              : '"${note.title}" will be permanently removed.',
          style: TextStyle(color: primaryTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: secondaryTextColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: kMaroon, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.deleteNote(note.id);
    }
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
                      : RefreshIndicator(
                          color: kMaroon,
                          onRefresh: _controller.refresh,
                          child: _buildBody(),
                        ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openEditor(),
          backgroundColor: kMaroon,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add_rounded, size: 28),
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
            child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 6),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_note_rounded, color: kGold, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RevEduc',
                style: TextStyle(
                  color: kGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _isScoped ? (widget.subjectName ?? 'Notes') : 'My Notes',
                style: const TextStyle(
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isScoped) ...[
            TextField(
              controller: _searchController,
              onChanged: _controller.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search notes',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_controller.subjectsWithNotes.isNotEmpty) ...[
              SubjectFilterChips(
                subjects: _controller.subjectsWithNotes,
                selectedSubjectId: _controller.filterSubjectId,
                onSelect: _controller.setFilterSubject,
              ),
              const SizedBox(height: 16),
            ],
          ],
          if (_controller.notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _isScoped
                      ? 'No notes yet for this subject.\nTap "+" to add one.'
                      : 'No notes yet. Tap "+" to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryTextColor(context)),
                ),
              ),
            )
          else
            ..._controller.notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NoteCard(
                  note: note,
                  showSubjectLabel: !_isScoped,
                  onTap: () => _openEditor(existing: note),
                  onDelete: () => _confirmDelete(note),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
