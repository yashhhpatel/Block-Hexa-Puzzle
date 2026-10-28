import 'package:block_hexa_puzzle/game/generator.dart';
import 'package:block_hexa_puzzle/game/hex.dart';
import 'package:block_hexa_puzzle/game/level.dart';
import 'package:block_hexa_puzzle/meta/chapters.dart';
import 'package:block_hexa_puzzle/meta/cosmetics.dart';
import 'package:block_hexa_puzzle/meta/quests.dart';
import 'package:block_hexa_puzzle/services/progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Level _level(int n) => Level(
      number: n,
      board: {const Hex(0, 0)},
      pieces: [Piece([const Hex(0, 0)], 0)],
      solution: [const Hex(0, 0)],
    );

void main() {
  late DateTime clock;
  late Progress p;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 28, 10);
    p = await Progress.load(clock: () => clock);
  });

  group('stars and level rewards', () {
    test('stars reflect hints and target time', () async {
      final w = await p.recordLevelWin(_level(1), seconds: 5, hintsUsed: 0);
      expect(w.stars, 3);
      expect(w.firstClear, isTrue);
      expect(p.starsFor(1), 3);
      expect(p.unlockedLevel, 2);

      final w2 = await p.recordLevelWin(_level(2), seconds: 999, hintsUsed: 1);
      expect(w2.stars, 1);
      expect(w2.noHints, isFalse);
      expect(w2.underPar, isFalse);
    });

    test('replays only pay for improvements', () async {
      final start = p.coins;
      await p.recordLevelWin(_level(1), seconds: 999, hintsUsed: 1); // 1 star
      final afterFirst = p.coins;
      expect(afterFirst - start,
          Progress.firstClearReward + Progress.coinsPerNewStar);

      final same = await p.recordLevelWin(_level(1), seconds: 999, hintsUsed: 1);
      expect(same.coins, 0, reason: 'no improvement, no coins');
      expect(p.stat(Stat.levelsCleared), 1);

      final better = await p.recordLevelWin(_level(1), seconds: 1, hintsUsed: 0);
      expect(better.coins, 2 * Progress.coinsPerNewStar);
      expect(better.newBest, isTrue);
      expect(p.totalStars, 3);
    });

    test('a chest opens every 10 new levels', () async {
      WinSummary? last;
      for (var n = 1; n <= 10; n++) {
        last = await p.recordLevelWin(_level(n), seconds: 1, hintsUsed: 0);
      }
      expect(last!.chestReward, isNotNull);
      expect(last.chestReward, inInclusiveRange(30, 80));
      expect(p.chestProgress, 0);
    });

    test('finishing a chapter pays its reward once', () async {
      final beginner = Chapters.at(0);
      for (var n = 1; n < beginner.last; n++) {
        await p.recordLevelWin(_level(n), seconds: 1, hintsUsed: 0);
      }
      final w = await p.recordLevelWin(_level(beginner.last), seconds: 1, hintsUsed: 0);
      expect(w.chapterCompleted?.name, 'Beginner');
      expect(p.stat(Stat.chaptersCompleted), 1);
    });
  });

  group('daily puzzle and streaks', () {
    Future<WinSummary> solveToday() => p.recordDailyWin(
        LevelGenerator.generateDaily(clock), seconds: 30, hintsUsed: 0);

    test('streak grows on consecutive days and resets after a gap', () async {
      expect((await solveToday()).dailyStreak, 1);
      clock = clock.add(const Duration(days: 1));
      expect((await solveToday()).dailyStreak, 2);
      clock = clock.add(const Duration(days: 1));
      final third = await solveToday();
      expect(third.dailyStreak, 3);
      expect(third.streakBonus, 30);
      expect(p.streak, 3);

      clock = clock.add(const Duration(days: 2)); // missed a day
      expect(p.streak, 0);
      expect((await solveToday()).dailyStreak, 1);
      expect(p.stat(Stat.bestStreak), 3);
    });

    test('solving the same daily twice pays once', () async {
      final a = await solveToday();
      final b = await solveToday();
      expect(a.coins, greaterThan(0));
      expect(b.coins, 0);
    });

    test('catching up an older day does not extend the streak', () async {
      final yesterday = clock.subtract(const Duration(days: 1));
      final w = await p.recordDailyWin(LevelGenerator.generateDaily(yesterday),
          seconds: 30, hintsUsed: 0);
      expect(w.dailyStreak, isNull);
      expect(p.streak, 0);
      expect(p.isDailySolved(dayKeyOf(yesterday)), isTrue);
    });

    test('daily puzzles are the same for everyone and differ by day', () {
      final a = LevelGenerator.generateDaily(DateTime(2026, 1, 5));
      final b = LevelGenerator.generateDaily(DateTime(2026, 1, 5));
      final c = LevelGenerator.generateDaily(DateTime(2026, 1, 6));
      expect(a.board, b.board);
      expect(a.board == c.board, isFalse);
      expect(a.verifySolution(), isTrue);
      expect(a.isDaily, isTrue);
    });
  });

  group('quests and achievements', () {
    test('quests track progress, claim once, and roll over at midnight', () async {
      final quests = p.todayQuests;
      expect(quests.length, 3);
      expect(quests.map((q) => q.def.stat).toSet().length, 3);

      // Satisfy every stat the pool can ask for.
      for (var n = 1; n <= 9; n++) {
        await p.recordLevelWin(_level(n), seconds: 1, hintsUsed: 0);
      }
      await p.recordBlocksPlaced(100);
      await p.recordDailyWin(LevelGenerator.generateDaily(clock),
          seconds: 1, hintsUsed: 0);

      for (final q in p.todayQuests) {
        expect(q.claimable, isTrue, reason: q.def.id);
        final before = p.coins;
        expect(await p.claimQuest(q.def.id), q.def.reward);
        expect(p.coins, before + q.def.reward);
        expect(await p.claimQuest(q.def.id), 0, reason: 'no double claim');
      }
      expect(p.allQuestsBonusClaimable, isTrue);
      expect(await p.claimQuest('all'), Quests.allDoneBonus);

      clock = clock.add(const Duration(days: 1));
      expect(p.todayQuests.every((q) => q.progress == 0 && !q.claimed), isTrue);
    });

    test('achievements unlock tier by tier', () async {
      for (var n = 1; n <= 10; n++) {
        await p.recordLevelWin(_level(n), seconds: 1, hintsUsed: 0);
      }
      final levels = p.achievements.firstWhere((a) => a.def.id == 'levels');
      expect(levels.claimable, isTrue);
      expect(await p.claimAchievement('levels'), levels.reward);
      final next = p.achievements.firstWhere((a) => a.def.id == 'levels');
      expect(next.claimedTiers, 1);
      expect(next.target, 50);
      expect(next.claimable, isFalse);
    });
  });

  group('login bonus', () {
    test('cycles through 7 days and restarts after a missed day', () async {
      expect(p.pendingLoginDay, 0);
      expect(await p.claimLoginBonus(), Progress.loginRewards[0]);
      expect(p.pendingLoginDay, isNull, reason: 'once per day');
      clock = clock.add(const Duration(days: 1));
      expect(p.pendingLoginDay, 1);
      await p.claimLoginBonus();
      clock = clock.add(const Duration(days: 3));
      expect(p.pendingLoginDay, 0);
    });
  });

  group('shop', () {
    test('coin items cost coins; star items unlock with stars', () async {
      final matte = Cosmetics.skins.firstWhere((s) => s.id == 'flat');
      final crystal = Cosmetics.skins.firstWhere((s) => s.id == 'crystal');
      await p.setCoins(100);
      expect(await p.unlock(matte), isFalse, reason: 'too expensive');
      await p.setCoins(matte.price);
      expect(await p.unlock(matte), isTrue);
      expect(p.coins, 0);
      await p.equip(matte);
      expect(p.skinId, 'flat');

      expect(p.isUnlocked(crystal), isFalse);
      for (var n = 1; n <= 30; n++) {
        await p.recordLevelWin(_level(n), seconds: 1, hintsUsed: 0);
      }
      expect(p.totalStars, 90);
      expect(p.isUnlocked(crystal), isTrue);
    });
  });

  test('chapters are contiguous and endless', () {
    var expected = 1;
    for (var i = 0; i < 12; i++) {
      final c = Chapters.at(i);
      expect(c.first, expected);
      expect(Chapters.forLevel(c.first).index, i);
      expect(Chapters.forLevel(c.last).index, i);
      expected = c.last + 1;
    }
    expect(Chapters.forLevel(5000).name, startsWith('Grandmaster'));
  });
}
