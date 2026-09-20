import 'dart:math';

import '../data/assessment_config.dart';

/// A quiz question row as returned by LocalDbService.
typedef QuestionRow = Map<String, dynamic>;

/// A pool of questions that should receive [weight] share of a quiz.
class WeightedPool {
  final double weight;
  final List<QuestionRow> questions;

  const WeightedPool(this.weight, this.questions);
}

/// Pure-Dart question picker (no Firebase / SQLite), so it's easy to
/// unit test. Two steps:
///  1. Split the total across pools by weight   -> [buildWeighted]
///  2. Inside each pool, pick 30/50/20 Easy/Moderate/Difficult
///                                              -> [pickByDifficulty]
/// If a pool doesn't have enough questions (or enough of one
/// difficulty), the gap is filled from whatever is left over, so the
/// quiz is only ever short when the whole bank is too small.
class QuizBuilder {
  QuizBuilder._();

  static final Random _rng = Random();

  /// Largest-remainder apportionment: splits [total] into whole numbers
  /// proportional to [weights] (which don't need to add up to 100).
  /// The result always sums to [total].
  static List<int> apportion(int total, List<num> weights) {
    final sum = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0 || sum <= 0) return List<int>.filled(weights.length, 0);

    final exact = [for (final w in weights) total * w / sum];
    final result = [for (final e in exact) e.floor()];
    var remaining = total - result.fold<int>(0, (a, b) => a + b);

    // Hand out the leftover units to the biggest fractional parts,
    // breaking ties in favour of the larger weight.
    final order = List<int>.generate(weights.length, (i) => i)
      ..sort((a, b) {
        final byFraction =
            (exact[b] - result[b]).compareTo(exact[a] - result[a]);
        return byFraction != 0 ? byFraction : weights[b].compareTo(weights[a]);
      });

    var i = 0;
    while (remaining > 0) {
      result[order[i % order.length]]++;
      remaining--;
      i++;
    }
    return result;
  }

  /// Picks up to [count] questions from [pool] following [kDifficultyMix].
  static List<QuestionRow> pickByDifficulty(List<QuestionRow> pool, int count) {
    final target = min(count, pool.length);
    if (target <= 0) return [];

    final buckets = {
      for (final d in Difficulty.values) d: <QuestionRow>[],
    };
    for (final q in pool) {
      buckets[parseDifficulty(q['difficulty'] as String?)]!.add(q);
    }
    for (final bucket in buckets.values) {
      bucket.shuffle(_rng);
    }

    final quotas = apportion(
      target,
      [for (final d in Difficulty.values) kDifficultyMix[d]!],
    );

    final picked = <QuestionRow>[];
    for (var i = 0; i < Difficulty.values.length; i++) {
      final bucket = buckets[Difficulty.values[i]]!;
      final take = min(quotas[i], bucket.length);
      picked.addAll(bucket.take(take));
      bucket.removeRange(0, take);
    }

    // A difficulty ran short (or questions are untagged): fill the gap
    // from what's left, moderate first, since it's the biggest share.
    var missing = target - picked.length;
    for (final d in [
      Difficulty.moderate,
      Difficulty.easy,
      Difficulty.difficult,
    ]) {
      if (missing <= 0) break;
      final bucket = buckets[d]!;
      final take = min(missing, bucket.length);
      picked.addAll(bucket.take(take));
      bucket.removeRange(0, take);
      missing -= take;
    }
    return picked;
  }

  /// Builds a [total]-question set from several weighted pools.
  /// Empty pools are ignored (their share flows to the others in
  /// proportion), and any remaining shortfall is filled from leftover
  /// questions. The result is shuffled.
  static List<QuestionRow> buildWeighted(int total, List<WeightedPool> slots) {
    final active =
        slots.where((s) => s.weight > 0 && s.questions.isNotEmpty).toList();
    if (total <= 0 || active.isEmpty) return [];

    final quotas = apportion(total, [for (final s in active) s.weight]);

    final picked = <QuestionRow>[];
    final pickedIds = <Object?>{};
    for (var i = 0; i < active.length; i++) {
      for (final q in pickByDifficulty(active[i].questions, quotas[i])) {
        picked.add(q);
        pickedIds.add(q['id']);
      }
    }

    if (picked.length < total) {
      final leftovers = [
        for (final s in active)
          for (final q in s.questions)
            if (!pickedIds.contains(q['id'])) q,
      ];
      picked.addAll(pickByDifficulty(leftovers, total - picked.length));
    }

    picked.shuffle(_rng);
    return picked;
  }
}
