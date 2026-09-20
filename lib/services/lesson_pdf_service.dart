import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// LessonPdfService
/// ----------------
/// Stores and loads lesson PDFs using Firestore only (no Firebase
/// Storage, which needs the paid Blaze plan).
///
/// A Firestore document can't exceed 1 MiB, so a PDF is split into
/// ~700 KB chunks, each saved as its own doc:
///
///   subjects/{subjectId}/lessons/{lessonId}/pdfChunks/{version}_{index}
///     - index: int
///     - data:  Blob (raw bytes of that slice)
///
/// The lesson doc itself only carries two small fields that point at
/// the current PDF:
///   - pdfVersion:    int (millisecondsSinceEpoch of the upload)
///   - pdfChunkCount: int
///
/// Because the version is part of every chunk's doc id, re-publishing
/// a lesson can never mix old and new chunks, and any copy cached on
/// the device for an older version is simply never asked for again.
class LessonPdfService {
  LessonPdfService._internal();
  static final LessonPdfService instance = LessonPdfService._internal();

  /// Per-chunk size. Stays safely under Firestore's 1 MiB doc limit.
  static const int chunkSizeBytes = 700 * 1024;

  /// Upper bound for one lesson PDF. Keeps a single upload from eating
  /// the free plan's daily writes / 1 GiB storage. Raise if needed.
  static const int maxPdfBytes = 10 * 1024 * 1024;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Recently opened PDFs, so re-opening a lesson (or coming back from
  /// the quiz) doesn't hit Firestore again.
  final Map<String, Uint8List> _memoryCache = {};
  static const int _memoryCacheLimit = 3;

  static String chunkId(int version, int index) =>
      '${version}_${index.toString().padLeft(3, '0')}';

  CollectionReference<Map<String, dynamic>> _chunks(
    String subjectId,
    String lessonId,
  ) =>
      _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('lessons')
          .doc(lessonId)
          .collection('pdfChunks');

  // =================================================================
  // ADMIN SIDE — save
  // =================================================================

  /// Splits [bytes] into chunks and writes them. Returns the new
  /// version + chunk count; the caller must save those two values on
  /// the lesson doc (that's what "switches" the lesson to the new PDF)
  /// and then call [deleteStaleChunks].
  Future<({int version, int chunkCount})> savePdf({
    required String subjectId,
    required String lessonId,
    required Uint8List bytes,
  }) async {
    final version = DateTime.now().millisecondsSinceEpoch;
    final chunkCount = (bytes.length / chunkSizeBytes).ceil();
    final chunks = _chunks(subjectId, lessonId);

    for (var i = 0; i < chunkCount; i++) {
      final start = i * chunkSizeBytes;
      final end = math.min(start + chunkSizeBytes, bytes.length);
      await chunks.doc(chunkId(version, i)).set({
        'index': i,
        'data': Blob(Uint8List.sublistView(bytes, start, end)),
      });
    }

    return (version: version, chunkCount: chunkCount);
  }

  /// Deletes every chunk that doesn't belong to [keepVersion]. Pass
  /// null to delete all of them (e.g. lesson re-published without a PDF).
  Future<void> deleteStaleChunks({
    required String subjectId,
    required String lessonId,
    int? keepVersion,
  }) async {
    final snap = await _chunks(subjectId, lessonId).get();
    for (final doc in snap.docs) {
      if (keepVersion != null && doc.id.startsWith('${keepVersion}_')) {
        continue;
      }
      await doc.reference.delete();
    }
  }

  // =================================================================
  // USER SIDE — load
  // =================================================================

  /// Downloads and reassembles the PDF. Returns null if any chunk is
  /// missing/unreadable (e.g. offline and never opened before).
  Future<Uint8List?> loadPdf({
    required String subjectId,
    required String lessonId,
    required int version,
    required int chunkCount,
  }) async {
    if (version <= 0 || chunkCount <= 0) return null;

    final cacheKey = '$lessonId:$version';
    final cached = _memoryCache[cacheKey];
    if (cached != null) return cached;

    final parts = await Future.wait([
      for (var i = 0; i < chunkCount; i++)
        _fetchChunk(subjectId, lessonId, version, i),
    ]);
    if (parts.any((p) => p == null)) return null;

    final builder = BytesBuilder(copy: false);
    for (final part in parts) {
      builder.add(part!);
    }
    final bytes = builder.takeBytes();

    _memoryCache[cacheKey] = bytes;
    while (_memoryCache.length > _memoryCacheLimit) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    return bytes;
  }

  /// Tries Firestore's on-device cache first (free, instant, works
  /// offline), then falls back to the server. Only the server fetch
  /// counts against the free plan's daily read quota.
  Future<Uint8List?> _fetchChunk(
    String subjectId,
    String lessonId,
    int version,
    int index,
  ) async {
    final ref = _chunks(subjectId, lessonId).doc(chunkId(version, index));

    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      final fromCache = await ref.get(const GetOptions(source: Source.cache));
      if (fromCache.exists) snap = fromCache;
    } catch (_) {
      // Not in the local cache — fall through to the server.
    }

    if (snap == null) {
      try {
        snap = await ref.get();
      } catch (e) {
        debugPrint('LessonPdfService: failed to fetch chunk $index: $e');
        return null;
      }
    }

    final data = snap.data()?['data'];
    return data is Blob ? data.bytes : null;
  }
}
