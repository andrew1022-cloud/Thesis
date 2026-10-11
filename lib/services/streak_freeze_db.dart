import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/level_data.dart';
import '../data/unlockable_data.dart';
import 'local_db_service.dart';

/// Day streak with the level-based "streak freeze" perk (see
/// unlockable_data.dart). Added as an extension so local_db_service.dart
/// doesn't need to change.
///
/// Same rules as LocalDbService.getDayStreak — consecutive days the app
/// was opened, ending today (or yesterday if today isn't logged yet) —
/// except that each calendar week (Mon–Sun) up to [streakFreezesPerWeek]
/// missed days are bridged instead of ending the streak. Bridged days
/// don't add to the count; they just don't break it.
extension StreakFreezeDb on LocalDbService {
  Future<int> getDayStreakWithFreeze(String uid) async {
    final db = await database;
    final rows = await db.query(
      LocalDbService.tableAppUsage,
      columns: ['dateString'],
      where: 'userId = ?',
      whereArgs: [uid],
    );
    final used = rows.map((r) => r['dateString'] as String).toSet();
    if (used.isEmpty) return 0;

    // Freezes depend on the user's level (total points). If Firestore
    // can't be reached, fall back to no freezes rather than failing.
    var allowance = 0;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final points = ((doc.data()?['points'] ?? 0) as num).toInt();
      allowance = streakFreezesPerWeek(levelForPoints(points).number);
    } catch (_) {}

    String fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final earliest = used.reduce((a, b) => a.compareTo(b) < 0 ? a : b);

    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    // Today not logged yet doesn't break the streak (and costs no freeze).
    if (!used.contains(fmt(cursor))) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    final freezesUsedInWeek = <String, int>{};
    var streak = 0;

    while (true) {
      final key = fmt(cursor);
      if (key.compareTo(earliest) < 0) break;

      if (used.contains(key)) {
        streak++;
      } else {
        final week = LocalDbService.weekKeyFor(cursor);
        final spent = freezesUsedInWeek[week] ?? 0;
        if (spent >= allowance) break;
        freezesUsedInWeek[week] = spent + 1;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }
}
