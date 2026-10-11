/// Reviewee levels, based on a user's TOTAL points (users/{uid}.points).
/// Edit thresholds/titles here — nothing else needs to change.
class UserLevel {
  final int number;
  final String title;
  final int minPoints;

  const UserLevel(this.number, this.title, this.minPoints);
}

const List<UserLevel> kLevels = [
  UserLevel(1, 'Aspirant Reviewee', 0),
  UserLevel(2, 'Eager Reviewee', 50),
  UserLevel(3, 'Competent Reviewee', 150),
  UserLevel(4, 'Capable Reviewee', 300),
  UserLevel(5, 'Dedicated Reviewee', 500),
  UserLevel(6, 'Proficient Reviewee', 800),
  UserLevel(7, 'Exemplary Reviewee', 1200),
  UserLevel(8, 'Distinguished Reviewee', 1800),
  UserLevel(9, 'Board-Ready Reviewee', 2500),
];

UserLevel levelForPoints(int points) {
  var current = kLevels.first;
  for (final level in kLevels) {
    if (points >= level.minPoints) {
      current = level;
    } else {
      break;
    }
  }
  return current;
}

/// The next level up, or null if [level] is already the highest.
UserLevel? nextLevelAfter(UserLevel level) {
  final index = kLevels.indexWhere((l) => l.number == level.number);
  if (index == -1 || index == kLevels.length - 1) return null;
  return kLevels[index + 1];
}

/// 0.0–1.0 progress through the current level toward the next one.
double levelProgress(int points) {
  final current = levelForPoints(points);
  final next = nextLevelAfter(current);
  if (next == null) return 1.0;
  final span = next.minPoints - current.minPoints;
  if (span <= 0) return 1.0;
  return ((points - current.minPoints) / span).clamp(0.0, 1.0);
}
