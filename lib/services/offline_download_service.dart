import 'package:cloud_firestore/cloud_firestore.dart';

import 'lesson_pdf_service.dart';
import 'local_db_service.dart';
import 'offline_pdf_store.dart';

/// Thrown when the user cancels a download in progress.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
}

/// OfflineDownloadService
/// ----------------------
/// Downloads everything a subject needs to work with no connection:
///   1. lessons (text)       -> LocalDbService (SQLite)
///   2. quiz questions       -> LocalDbService (SQLite)
///   3. lesson PDFs          -> OfflinePdfStore (SQLite, permanent)
/// and records when it finished, so the UI can show sync status.
class OfflineDownloadService {
  OfflineDownloadService._internal();
  static final OfflineDownloadService instance =
      OfflineDownloadService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDbService _local = LocalDbService.instance;
  final OfflinePdfStore _store = OfflinePdfStore.instance;

  static const int _concurrency = 4;

  /// Downloads one subject. [onProgress] gets 0.0–1.0 for this subject.
  /// Throws [DownloadCancelledException] if [isCancelled] turns true,
  /// or any network error as-is.
  Future<void> downloadSubject(
    String subjectId, {
    void Function(double fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    void checkCancelled() {
      if (isCancelled?.call() ?? false) throw const DownloadCancelledException();
    }

    checkCancelled();

    // 1) Lessons (also refreshes this subject's lesson rows locally).
    final lessons = await _local.syncLessonsForSubject(subjectId);
    final pdfFields = await _readPdfFields(subjectId);

    final totalSteps = lessons.length + pdfFields.length;
    var done = 0;
    void tick() {
      done++;
      onProgress?.call(totalSteps == 0 ? 1 : done / totalSteps);
    }

    if (totalSteps == 0) onProgress?.call(1);

    // 2) Quiz questions, a few lessons at a time.
    for (var i = 0; i < lessons.length; i += _concurrency) {
      checkCancelled();
      final batch = lessons.skip(i).take(_concurrency).toList();
      await Future.wait([
        for (final l in batch)
          _local
              .syncQuizForLesson(subjectId, l['id'] as String)
              .then((_) => tick()),
      ]);
    }

    // 3) PDFs (skip any that are already saved at the current version).
    final saved = {
      for (final p in await _store.getSavedPdfs()) p.lessonId: p,
    };
    for (final entry in pdfFields.entries) {
      checkCancelled();
      final lessonId = entry.key;
      final info = entry.value;

      final existing = saved[lessonId];
      final upToDate = existing != null &&
          existing.version == info.version &&
          existing.chunks >= info.chunks;

      if (!upToDate) {
        final bytes = await LessonPdfService.instance.downloadFromServer(
          subjectId: subjectId,
          lessonId: lessonId,
          version: info.version,
          chunkCount: info.chunks,
        );
        if (bytes == null) {
          throw Exception('Could not download the PDF for lesson $lessonId.');
        }
        await _store.savePdf(
          subjectId: subjectId,
          lessonId: lessonId,
          version: info.version,
          bytes: bytes,
        );
      }
      tick();
    }

    // 4) Drop saved PDFs for lessons that no longer have one.
    await _store.pruneSubject(subjectId, pdfFields.keys);

    await _store.recordDownload(
      subjectId: subjectId,
      lessonCount: lessons.length,
      pdfExpected: pdfFields.length,
    );
  }

  /// lessonId -> current PDF version/chunk count, for lessons that
  /// have a PDF published. Reads the Firestore on-device cache first
  /// (just filled by the lesson sync above), then falls back to the
  /// server.
  Future<Map<String, ({int version, int chunks})>> _readPdfFields(
      String subjectId) async {
    final ref = _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('lessons');

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref.get(const GetOptions(source: Source.cache));
      if (snap.docs.isEmpty) snap = await ref.get();
    } catch (_) {
      snap = await ref.get();
    }

    final result = <String, ({int version, int chunks})>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final version = (data['pdfVersion'] as num?)?.toInt() ?? 0;
      final chunks = (data['pdfChunkCount'] as num?)?.toInt() ?? 0;
      if (version > 0 && chunks > 0) {
        result[doc.id] = (version: version, chunks: chunks);
      }
    }
    return result;
  }
}
