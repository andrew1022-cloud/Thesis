import 'package:flutter/material.dart';

import '../services/notes_db_service.dart';

/// Holds all state for the Notes screen. The UI only reads from this
/// controller — it does not touch NotesDbService directly.
///
/// Can be scoped to one subject (pass [subjectId]/[initialSubjectName])
/// — e.g. opened from a Subject Detail screen — or left unscoped to
/// browse every note the user has across all subjects (e.g. from a
/// "My Notes" entry in Profile).
class NotesController extends ChangeNotifier {
  final NotesDbService _db = NotesDbService.instance;
  final String uid;

  /// If set, this controller only shows/creates notes for this
  /// subject. If null, it shows notes across all subjects.
  final String? subjectId;
  final String? initialSubjectName;

  NotesController({
    required this.uid,
    this.subjectId,
    this.initialSubjectName,
  });

  bool isLoading = true;
  List<NoteItem> notes = [];

  /// Subjects that currently have at least one note — used to build
  /// a filter chip row when browsing unscoped.
  List<Map<String, String>> subjectsWithNotes = [];

  /// Selected filter when unscoped (null = "All").
  String? filterSubjectId;

  String searchQuery = '';

  Future<void> loadNotes() async {
    isLoading = true;
    notifyListeners();

    await _db.pushPendingSyncs(uid);

    if (subjectId != null) {
      notes = await _db.getNotesForSubject(uid, subjectId!);
    } else {
      subjectsWithNotes = await _db.getSubjectsWithNotes(uid);
      notes = searchQuery.trim().isEmpty
          ? await _db.getAllNotes(uid)
          : await _db.searchNotes(uid: uid, query: searchQuery);
      if (filterSubjectId != null) {
        notes = notes.where((n) => n.subjectId == filterSubjectId).toList();
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadNotes();

  Future<void> setSearchQuery(String query) async {
    searchQuery = query;
    await loadNotes();
  }

  Future<void> setFilterSubject(String? id) async {
    filterSubjectId = id;
    await loadNotes();
  }

  Future<void> addNote({
    required String subjectId,
    required String subjectName,
    String topic = '',
    required String title,
    String content = '',
  }) async {
    await _db.createNote(
      uid: uid,
      subjectId: subjectId,
      subjectName: subjectName,
      topic: topic,
      title: title,
      content: content,
    );
    await loadNotes();
  }

  Future<void> updateNote({
    required String noteId,
    String? topic,
    String? title,
    String? content,
  }) async {
    await _db.updateNote(
      uid: uid,
      noteId: noteId,
      topic: topic,
      title: title,
      content: content,
    );
    await loadNotes();
  }

  Future<void> deleteNote(String noteId) async {
    await _db.deleteNote(uid: uid, noteId: noteId);
    await loadNotes();
  }
}
