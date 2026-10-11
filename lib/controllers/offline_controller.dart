import 'package:flutter/material.dart';

import '../data/curriculum_data.dart';
import '../services/connectivity_service.dart';
import '../services/local_db_service.dart';
import '../services/offline_download_service.dart';
import '../services/offline_pdf_store.dart';

/// Offline status of one subject.
class SubjectOfflineStatus {
  final String subjectId;
  final String name;
  final String categoryCode;

  /// Lessons that actually have content (text or a PDF) on this device.
  final int lessonCount;
  final int questionCount;
  final int pdfSaved;
  final int pdfExpected;
  final int pdfBytes;
  final DateTime? downloadedAt;

  const SubjectOfflineStatus({
    required this.subjectId,
    required this.name,
    required this.categoryCode,
    required this.lessonCount,
    required this.questionCount,
    required this.pdfSaved,
    required this.pdfExpected,
    required this.pdfBytes,
    required this.downloadedAt,
  });

  bool get isDownloaded => downloadedAt != null;

  /// Downloaded, and every PDF the subject has is saved.
  bool get isComplete => isDownloaded && pdfSaved >= pdfExpected;

  /// Downloaded before, but some PDFs are missing.
  bool get isPartial => isDownloaded && !isComplete;
}

class OfflineCategoryGroup {
  final String code;
  final String label;
  final List<SubjectOfflineStatus> subjects;

  const OfflineCategoryGroup({
    required this.code,
    required this.label,
    required this.subjects,
  });

  bool get allComplete => subjects.every((s) => s.isComplete);
}

/// Holds all state for the Offline Content screen.
class OfflineController extends ChangeNotifier {
  final LocalDbService _local = LocalDbService.instance;
  final OfflinePdfStore _store = OfflinePdfStore.instance;
  final OfflineDownloadService _downloader = OfflineDownloadService.instance;

  OfflineController() {
    ConnectivityService.instance.isOnline.addListener(_onConnectionChanged);
  }

  bool _disposed = false;
  bool _cancelRequested = false;

  bool isLoading = true;
  List<OfflineCategoryGroup> groups = [];

  // Download progress
  bool isDownloading = false;
  double progress = 0; // 0.0–1.0 across the whole job
  String progressLabel = '';
  String? message; // error / info text shown under the status card

  bool get isOnline => ConnectivityService.instance.isOnline.value;

  void _onConnectionChanged() => notifyListeners();

  // ---------------------------------------------------------------
  // Derived numbers for the status card
  // ---------------------------------------------------------------

  List<SubjectOfflineStatus> get _all => [
        for (final g in groups) ...g.subjects,
      ];

  int get totalSubjects => _all.length;
  int get completeSubjects => _all.where((s) => s.isComplete).length;
  int get downloadedSubjects => _all.where((s) => s.isDownloaded).length;

  /// Share of subjects fully available offline, 0–100.
  int get availablePercent => totalSubjects == 0
      ? 0
      : ((completeSubjects / totalSubjects) * 100).round();

  int get totalPdfBytes => _all.fold(0, (sum, s) => sum + s.pdfBytes);

  DateTime? get lastDownloadedAt {
    DateTime? latest;
    for (final s in _all) {
      final d = s.downloadedAt;
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    return latest;
  }

  bool get allComplete => totalSubjects > 0 && completeSubjects == totalSubjects;

  // ---------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------

  Future<void> load({bool showSpinner = true}) async {
    if (showSpinner) {
      isLoading = true;
      notifyListeners();
    }

    try {
      final db = await _local.database;

      // Which lessons have text content on this device.
      final lessonRows = await db.rawQuery(
        'SELECT id, subjectId, LENGTH(content) AS len '
        'FROM ${LocalDbService.tableLessons}',
      );
      final quizRows = await db.rawQuery(
        'SELECT subjectId, COUNT(*) AS c '
        'FROM ${LocalDbService.tableQuizQuestions} GROUP BY subjectId',
      );
      final savedPdfs = await _store.getSavedPdfs();
      final downloads = await _store.getDownloads();

      final pdfLessonIds = {for (final p in savedPdfs) p.lessonId};

      final lessonCountBySubject = <String, int>{};
      for (final r in lessonRows) {
        final hasText = ((r['len'] as num?)?.toInt() ?? 0) > 0;
        final hasPdf = pdfLessonIds.contains(r['id'] as String);
        if (hasText || hasPdf) {
          final sid = r['subjectId'] as String;
          lessonCountBySubject[sid] = (lessonCountBySubject[sid] ?? 0) + 1;
        }
      }

      final questionCountBySubject = {
        for (final r in quizRows)
          r['subjectId'] as String: (r['c'] as num).toInt(),
      };

      final pdfCountBySubject = <String, int>{};
      final pdfBytesBySubject = <String, int>{};
      for (final p in savedPdfs) {
        pdfCountBySubject[p.subjectId] =
            (pdfCountBySubject[p.subjectId] ?? 0) + 1;
        pdfBytesBySubject[p.subjectId] =
            (pdfBytesBySubject[p.subjectId] ?? 0) + p.bytes;
      }

      final newGroups = <OfflineCategoryGroup>[];
      for (final category in kFixedCurriculum) {
        final subjects = <SubjectOfflineStatus>[];
        for (var s = 0; s < category.subjects.length; s++) {
          final id = curriculumSubjectId(category.code, s);
          final record = downloads[id];
          subjects.add(SubjectOfflineStatus(
            subjectId: id,
            name: category.subjects[s].name,
            categoryCode: category.code,
            lessonCount: lessonCountBySubject[id] ?? 0,
            questionCount: questionCountBySubject[id] ?? 0,
            pdfSaved: pdfCountBySubject[id] ?? 0,
            pdfExpected: record?.pdfExpected ?? 0,
            pdfBytes: pdfBytesBySubject[id] ?? 0,
            downloadedAt: record?.downloadedAt,
          ));
        }
        newGroups.add(OfflineCategoryGroup(
          code: category.code,
          label: category.label,
          subjects: subjects,
        ));
      }
      groups = newGroups;
    } catch (e) {
      debugPrint('OfflineController: load failed: $e');
      message = "Couldn't read offline status.";
    }

    isLoading = false;
    notifyListeners();
  }

  /// Pull-to-refresh: re-check the connection, then reload.
  Future<void> refresh() async {
    await ConnectivityService.instance.checkNow();
    await load(showSpinner: false);
  }

  // ---------------------------------------------------------------
  // Download actions
  // ---------------------------------------------------------------

  /// Downloads everything that isn't fully available offline yet, or
  /// refreshes everything if it already is.
  Future<void> downloadAll() => _download(
        allComplete ? _all : _all.where((s) => !s.isComplete).toList(),
      );

  /// Re-downloads only the subjects that were downloaded before.
  Future<void> updateDownloaded() =>
      _download(_all.where((s) => s.isDownloaded).toList());

  Future<void> downloadCategory(String code) {
    final group = groups.firstWhere((g) => g.code == code);
    return _download(
      group.allComplete
          ? group.subjects
          : group.subjects.where((s) => !s.isComplete).toList(),
    );
  }

  Future<void> downloadSubject(String subjectId) =>
      _download(_all.where((s) => s.subjectId == subjectId).toList());

  void cancelDownload() {
    if (isDownloading) _cancelRequested = true;
  }

  Future<void> _download(List<SubjectOfflineStatus> targets) async {
    if (isDownloading || targets.isEmpty) return;

    message = null;
    final online = await ConnectivityService.instance.checkNow();
    if (!online) {
      message = "You're offline. Connect to the internet to download content.";
      notifyListeners();
      return;
    }

    isDownloading = true;
    _cancelRequested = false;
    progress = 0;
    notifyListeners();

    try {
      for (var i = 0; i < targets.length; i++) {
        if (_cancelRequested) throw const DownloadCancelledException();
        final target = targets[i];
        progressLabel =
            'Downloading ${target.name} (${i + 1} of ${targets.length})';
        notifyListeners();

        await _downloader.downloadSubject(
          target.subjectId,
          isCancelled: () => _cancelRequested,
          onProgress: (f) {
            progress = (i + f) / targets.length;
            notifyListeners();
          },
        );
      }
      message = 'Download complete.';
    } on DownloadCancelledException {
      message = 'Download cancelled. Subjects already finished are kept.';
    } catch (e) {
      debugPrint('OfflineController: download failed: $e');
      message = 'Download failed. Check your connection and try again.';
    }

    isDownloading = false;
    progress = 0;
    progressLabel = '';
    await load(showSpinner: false);
  }

  // ---------------------------------------------------------------
  // Remove actions
  // ---------------------------------------------------------------

  /// Removes the saved PDFs and the "downloaded" mark for one subject.
  /// Lesson text and quiz questions stay cached, because the rest of
  /// the app uses that cache for progress.
  Future<void> removeSubject(String subjectId) async {
    if (isDownloading) return;
    await _store.removeSubject(subjectId);
    message = 'Download removed.';
    await load(showSpinner: false);
  }

  Future<void> removeAll() async {
    if (isDownloading) return;
    await _store.removeAll();
    message = 'All downloads removed.';
    await load(showSpinner: false);
  }

  // ---------------------------------------------------------------

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ConnectivityService.instance.isOnline.removeListener(_onConnectionChanged);
    super.dispose();
  }
}
