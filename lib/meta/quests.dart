import 'dart:math' as math;

/// Things the game counts, both per day (for quests) and lifetime.
enum Stat {
  levelsCleared,
  noHintClears,
  starsEarned,
  fastClears,
  threeStarLevels,
  dailyPlayed,
  blocksPlaced,
  chaptersCompleted,
  bestStreak,
}

class QuestDef {
  final String id;
  final Stat stat;
  final int target;
  final int reward;
  final String title;
  const QuestDef(this.id, this.stat, this.target, this.reward, this.title);
}

class AchievementDef {
  final String id;
  final Stat stat;
  final List<int> tiers;
  final List<int> rewards;
  final String Function(int target) title;
  const AchievementDef(this.id, this.stat, this.tiers, this.rewards, this.title);
}

class Quests {
  /// Daily quests are drawn from this pool, three a day, one per stat.
  static final pool = <QuestDef>[
    const QuestDef('clear3', Stat.levelsCleared, 3, 15, 'Clear 3 new levels'),
    const QuestDef('clear6', Stat.levelsCleared, 6, 30, 'Clear 6 new levels'),
    const QuestDef('nohint2', Stat.noHintClears, 2, 20, 'Clear 2 levels without hints'),
    const QuestDef('nohint4', Stat.noHintClears, 4, 35, 'Clear 4 levels without hints'),
    const QuestDef('stars5', Stat.starsEarned, 5, 20, 'Earn 5 stars'),
    const QuestDef('stars9', Stat.starsEarned, 9, 35, 'Earn 9 stars'),
    const QuestDef('fast2', Stat.fastClears, 2, 25, 'Beat the target time twice'),
    const QuestDef('three2', Stat.threeStarLevels, 2, 30, 'Get 3 stars on 2 levels'),
    const QuestDef('daily1', Stat.dailyPlayed, 1, 20, 'Solve the Daily Puzzle'),
    const QuestDef('blocks40', Stat.blocksPlaced, 40, 15, 'Place 40 blocks'),
    const QuestDef('blocks90', Stat.blocksPlaced, 90, 30, 'Place 90 blocks'),
  ];

  /// Bonus for finishing all three of the day's quests.
  static const allDoneBonus = 40;

  static List<QuestDef> forDay(int dayKey) {
    final rng = math.Random(dayKey * 7919 + 13);
    final shuffled = [...pool]..shuffle(rng);
    final picked = <QuestDef>[];
    final stats = <Stat>{};
    for (final q in shuffled) {
      if (stats.add(q.stat)) picked.add(q);
      if (picked.length == 3) break;
    }
    return picked;
  }

  static final achievements = <AchievementDef>[
    AchievementDef('levels', Stat.levelsCleared, const [10, 50, 100, 250, 500, 1000],
        const [20, 50, 100, 200, 400, 800], (t) => 'Clear $t levels'),
    AchievementDef('stars', Stat.starsEarned, const [30, 150, 500, 1500, 3000],
        const [25, 75, 150, 300, 600], (t) => 'Collect $t stars'),
    AchievementDef('streak', Stat.bestStreak, const [3, 7, 30, 100, 365],
        const [30, 75, 300, 800, 2000], (t) => 'Reach a $t-day streak'),
    AchievementDef('daily', Stat.dailyPlayed, const [5, 20, 50, 100, 365],
        const [25, 75, 150, 300, 800], (t) => 'Solve $t Daily Puzzles'),
    AchievementDef('nohint', Stat.noHintClears, const [10, 50, 200, 500],
        const [30, 100, 250, 500], (t) => 'Clear $t levels without hints'),
    AchievementDef('perfect', Stat.threeStarLevels, const [10, 50, 150, 400],
        const [30, 100, 250, 500], (t) => 'Get 3 stars on $t levels'),
    AchievementDef('blocks', Stat.blocksPlaced, const [100, 1000, 5000, 20000],
        const [20, 80, 200, 500], (t) => 'Place $t blocks'),
    AchievementDef('chapters', Stat.chaptersCompleted, const [1, 3, 6, 10],
        const [50, 150, 300, 600], (t) => 'Complete $t chapter${t == 1 ? '' : 's'}'),
  ];
}
