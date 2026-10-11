import 'package:cloud_firestore/cloud_firestore.dart';

import 'local_db_service.dart';

/// Weekly leaderboard queries that ALSO return each user's lifetime
/// points (`totalPoints`), because levels are based on total points,
/// not on this week's points. Added as an extension so
/// local_db_service.dart doesn't need to change.
extension WeeklyLeaderboardDb on LocalDbService {
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboardTopWithTotals(
      {int limit = 5}) async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('leaderboards')
        .doc(LocalDbService.weekKeyFor(DateTime.now()))
        .collection('entries')
        .orderBy('points', descending: true)
        .limit(limit)
        .get();

    final totals = await Future.wait([
      for (final d in snapshot.docs)
        firestore
            .collection('users')
            .doc(d.id)
            .get()
            .then((u) => ((u.data()?['points'] ?? 0) as num).toInt())
            .catchError((_) => 0),
    ]);

    return [
      for (var i = 0; i < snapshot.docs.length; i++)
        () {
          final weekly =
              ((snapshot.docs[i].data()['points'] ?? 0) as num).toInt();
          return <String, dynamic>{
            'rank': i + 1,
            'uid': snapshot.docs[i].id,
            'username': snapshot.docs[i].data()['username'] ?? 'Student',
            'points': weekly,
            'totalPoints': totals[i] > weekly ? totals[i] : weekly,
          };
        }(),
    ];
  }

  Future<Map<String, dynamic>> getUserWeeklyPointsAndRankWithTotal(
      String uid) async {
    final firestore = FirebaseFirestore.instance;
    final entries = firestore
        .collection('leaderboards')
        .doc(LocalDbService.weekKeyFor(DateTime.now()))
        .collection('entries');

    final doc = await entries.doc(uid).get();
    final points = ((doc.data()?['points'] ?? 0) as num).toInt();

    final u = await firestore.collection('users').doc(uid).get();
    final totalPoints = ((u.data()?['points'] ?? 0) as num).toInt();
    final username = (doc.data()?['username'] as String?) ??
        (u.data()?['username'] as String?) ??
        'You';

    final higherCount =
        await entries.where('points', isGreaterThan: points).count().get();

    return {
      'uid': uid,
      'username': username,
      'points': points,
      'totalPoints': totalPoints,
      'rank': (higherCount.count ?? 0) + 1,
    };
  }
}
