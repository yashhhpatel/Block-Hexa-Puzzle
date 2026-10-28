import 'dart:math' as math;

import '../l10n/l10n.dart';

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
  questsCompleted,
  loginDays,
  chestsOpened,
  itemsUnlocked,
  dailyPerfect,
}

class QuestDef {
  final String id;
  final Stat stat;
  final int target;
  final int reward;
  final String titleKey;
  const QuestDef(this.id, this.stat, this.target, this.reward, this.titleKey);

  String get title => tr(titleKey, {'n': target});
}

class AchievementDef {
  final String id;
  final Stat stat;
  final List<int> tiers;
  final List<int> rewards;

  /// Key of the description, e.g. "Clear {n} levels".
  final String descKey;
  const AchievementDef(
    this.id,
    this.stat,
    this.tiers,
    this.rewards,
    this.descKey,
  );

  /// Unique name, e.g. "Level Climber".
  String get name => tr('ach_$id');

  /// What to do for the tier with this [target].
  String title(int target) => tr(descKey, {'n': target});
}

class Quests {
  /// Daily quests are drawn from this pool, three a day, one per stat.
  static const pool = <QuestDef>[
    QuestDef('clear3', Stat.levelsCleared, 3, 15, 'q_clear'),
    QuestDef('clear6', Stat.levelsCleared, 6, 30, 'q_clear'),
    QuestDef('nohint2', Stat.noHintClears, 2, 20, 'q_nohint'),
    QuestDef('nohint4', Stat.noHintClears, 4, 35, 'q_nohint'),
    QuestDef('stars5', Stat.starsEarned, 5, 20, 'q_stars'),
    QuestDef('stars9', Stat.starsEarned, 9, 35, 'q_stars'),
    QuestDef('fast2', Stat.fastClears, 2, 25, 'q_fast'),
    QuestDef('three2', Stat.threeStarLevels, 2, 30, 'q_three'),
    QuestDef('daily1', Stat.dailyPlayed, 1, 20, 'q_daily'),
    QuestDef('blocks40', Stat.blocksPlaced, 40, 15, 'q_blocks'),
    QuestDef('blocks90', Stat.blocksPlaced, 90, 30, 'q_blocks'),
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

  static const achievements = <AchievementDef>[
    AchievementDef(
      'levels',
      Stat.levelsCleared,
      [10, 50, 100, 250, 500, 1000],
      [20, 50, 100, 200, 400, 800],
      'a_levels',
    ),
    AchievementDef(
      'stars',
      Stat.starsEarned,
      [30, 150, 500, 1500, 3000],
      [25, 75, 150, 300, 600],
      'a_stars',
    ),
    AchievementDef(
      'streak',
      Stat.bestStreak,
      [3, 7, 30, 100, 365],
      [30, 75, 300, 800, 2000],
      'a_streak',
    ),
    AchievementDef(
      'daily',
      Stat.dailyPlayed,
      [5, 20, 50, 100, 365],
      [25, 75, 150, 300, 800],
      'a_daily',
    ),
    AchievementDef(
      'nohint',
      Stat.noHintClears,
      [10, 50, 200, 500],
      [30, 100, 250, 500],
      'q_nohint',
    ),
    AchievementDef(
      'perfect',
      Stat.threeStarLevels,
      [10, 50, 150, 400],
      [30, 100, 250, 500],
      'q_three',
    ),
    AchievementDef(
      'blocks',
      Stat.blocksPlaced,
      [100, 1000, 5000, 20000],
      [20, 80, 200, 500],
      'q_blocks',
    ),
    AchievementDef(
      'chapters',
      Stat.chaptersCompleted,
      [1, 3, 6, 10],
      [50, 150, 300, 600],
      'a_chapters',
    ),
    AchievementDef(
      'speed',
      Stat.fastClears,
      [5, 25, 100, 300],
      [25, 75, 200, 400],
      'q_fast',
    ),
    AchievementDef(
      'quests',
      Stat.questsCompleted,
      [5, 25, 100, 365],
      [25, 75, 200, 500],
      'a_quests',
    ),
    AchievementDef(
      'loyal',
      Stat.loginDays,
      [7, 30, 100, 365],
      [30, 100, 300, 800],
      'a_login',
    ),
    AchievementDef(
      'chests',
      Stat.chestsOpened,
      [1, 10, 50, 100],
      [20, 60, 200, 400],
      'a_chests',
    ),
    AchievementDef(
      'collector',
      Stat.itemsUnlocked,
      [1, 3, 5, 8],
      [20, 50, 100, 250],
      'a_items',
    ),
    AchievementDef(
      'dailystar',
      Stat.dailyPerfect,
      [1, 10, 50, 100],
      [25, 75, 200, 400],
      'a_daily_perfect',
    ),
  ];
}
