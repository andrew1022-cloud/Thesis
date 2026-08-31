import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/local_db_service.dart';

/// One row in the "All Users" list on the Admin dashboard.
class AdminUserSummary {
  final String uid;
  final String name;
  final String email;
  final int genEdPercent;
  final int profEdPercent;
  final int specializationPercent;
  final int overallPercent;
  final String lastActiveLabel;

  AdminUserSummary({
    required this.uid,
    required this.name,
    required this.email,
    required this.genEdPercent,
    required this.profEdPercent,
    required this.specializationPercent,
    required this.overallPercent,
    required this.lastActiveLabel,
  });
}

/// Holds all state for the Admin dashboard. The UI only reads from
/// this controller — it does not touch Firestore or LocalDbService
/// directly.
///
/// Reviewer content (subjects/lessons) is shared and already cached
/// locally via [LocalDbService], so category totals are read from
/// there. Per-user completion has to be aggregated straight from
/// Firestore's `users/{uid}/lessonProgress` subcollections, since
/// that's per-account data for every registered user, not just the
/// signed-in one.
class AdminController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDbService _localDb = LocalDbService.instance;

  bool isLoading = true;

  int registeredUserCount = 0;
  int averagePreparednessPercent = 0;
  int completedUserCount = 0;

  List<AdminUserSummary> users = [];

  Future<void> loadAdminData() async {
    isLoading = true;
    notifyListeners();

    try {
      // Make sure reviewer content is cached locally, then read the
      // category → lesson-count breakdown from it.
      final subjects = await _localDb.getSubjects();

      final Map<String, String> subjectCodeById = {};
      final Map<String, int> totalByCode = {};
      var totalLessons = 0;

      for (final subject in subjects) {
        final id = subject['id'] as String;
        final code = (subject['code'] as String?) ?? '';
        subjectCodeById[id] = code;
        final count = await _localDb.getLessonCountForSubject(id);
        totalByCode[code] = (totalByCode[code] ?? 0) + count;
        totalLessons += count;
      }

      final usersSnapshot = await _firestore.collection('users').get();

      final summaries = <AdminUserSummary>[];
      var completedCount = 0;
      var preparednessSum = 0;

      for (final userDoc in usersSnapshot.docs) {
        final uid = userDoc.id;
        final data = userDoc.data();
        final name = (data['username'] as String?)?.isNotEmpty == true
            ? data['username'] as String
            : 'Student';
        final email = (data['email'] as String?) ?? '';

        final progressSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('lessonProgress')
            .where('isCompleted', isEqualTo: true)
            .get();

        final Map<String, int> completedByCode = {};
        var completedTotal = 0;
        for (final doc in progressSnap.docs) {
          final subjectId = doc.data()['subjectId'] as String? ?? '';
          final code = subjectCodeById[subjectId] ?? '';
          completedByCode[code] = (completedByCode[code] ?? 0) + 1;
          completedTotal++;
        }

        int percentFor(String code) {
          final total = totalByCode[code] ?? 0;
          if (total == 0) return 0;
          return ((completedByCode[code] ?? 0) / total * 100).round();
        }

        final overallPercent = totalLessons == 0
            ? 0
            : ((completedTotal / totalLessons) * 100).round();

        if (totalLessons > 0 && overallPercent >= 100) completedCount++;
        preparednessSum += overallPercent;

        final lastActiveLabel = await _fetchLastActiveLabel(uid);

        summaries.add(AdminUserSummary(
          uid: uid,
          name: name,
          email: email,
          genEdPercent: percentFor('GE'),
          profEdPercent: percentFor('PE'),
          specializationPercent: percentFor('SP'),
          overallPercent: overallPercent,
          lastActiveLabel: lastActiveLabel,
        ));
      }

      users = summaries;
      registeredUserCount = summaries.length;
      completedUserCount = completedCount;
      averagePreparednessPercent = summaries.isEmpty
          ? 0
          : (preparednessSum / summaries.length).round();
    } catch (e) {
      debugPrint('AdminController: failed to load admin data: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  /// Reads this user's most recent `appUsage` doc (each doc id is a
  /// yyyy-mm-dd date string, with an `openedAt` ISO timestamp field)
  /// and formats it as "Today, HH:mm" or "MMM d, HH:mm".
  Future<String> _fetchLastActiveLabel(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('appUsage')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return 'No activity yet';

      final data = snap.docs.first.data();
      final openedAtRaw = data['openedAt'] as String?;
      final openedAt =
          openedAtRaw != null ? DateTime.tryParse(openedAtRaw) : null;
      if (openedAt == null) return snap.docs.first.id;

      final now = DateTime.now();
      final isToday = openedAt.year == now.year &&
          openedAt.month == now.month &&
          openedAt.day == now.day;
      final timeLabel = DateFormat('HH:mm').format(openedAt);

      return isToday
          ? 'Today, $timeLabel'
          : '${DateFormat('MMM d').format(openedAt)}, $timeLabel';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Placeholder for the "Export" action — hook this up to a CSV/
  /// spreadsheet export once that's built out.
  void exportUsers() {
    debugPrint('Admin: Export tapped (${users.length} users)');
  }

  Future<void> refresh() => loadAdminData();
}
