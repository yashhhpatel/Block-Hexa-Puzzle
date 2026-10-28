import 'dart:math' as math;

import 'package:block_hexa_puzzle/game/generator.dart';
import 'package:block_hexa_puzzle/game/solver.dart';
import 'package:block_hexa_puzzle/l10n/l10n.dart';
import 'package:block_hexa_puzzle/services/progress.dart';
import 'package:block_hexa_puzzle/services/reminders.dart';
import 'package:block_hexa_puzzle/services/services.dart';
import 'package:block_hexa_puzzle/ui/board_view.dart';
import 'package:block_hexa_puzzle/ui/time_attack_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => appLang.value = AppLang.en);

  group('tray paging', () {
    test('small levels fit on one page', () {
      final l = BoardLayout.compute(
        const Size(360, 640),
        LevelGenerator.generate(30),
      );
      expect(l.pageCount, 1);
      expect(l.pageOf.every((p) => p == 0), isTrue);
    });

    test('busy levels page instead of shrinking blocks', () {
      const size = Size(360, 640);
      for (final n in [650, 900, 1100, 1300]) {
        final level = LevelGenerator.generate(n);
        final l = BoardLayout.compute(size, level);
        expect(l.pageOf.length, level.pieces.length);
        expect(
          l.trayCell,
          greaterThanOrEqualTo(BoardLayout.minTrayCell(size) * 0.999),
          reason: 'level $n',
        );
        expect(l.pageOf.toSet().length, l.pageCount, reason: 'level $n');
        // Every slot lies inside the tray of its own page.
        for (var i = 0; i < level.pieces.length; i++) {
          expect(
            l.trayRect.contains(l.traySlots[i]),
            isTrue,
            reason: 'level $n piece $i',
          );
        }
      }
    });
  });

  test('first levels of a hard chapter are a little lighter', () {
    double avgPieces(Iterable<int> levels) {
      var sum = 0;
      for (final n in levels) {
        sum += Difficulty.forLevel(n, math.Random(n)).pieceCount;
      }
      return sum / levels.length;
    }

    for (final start in Difficulty.hardStarts.take(6)) {
      final early = avgPieces(List.generate(10, (i) => start + i));
      final later = avgPieces(List.generate(10, (i) => start + 30 + i));
      expect(early, lessThan(later), reason: 'chapter at $start');
    }
    // Endless chapters keep full strength.
    expect(
      Difficulty.forLevel(1201, math.Random(1)).pieceCount,
      greaterThanOrEqualTo(16),
    );
  });

  group('time attack', () {
    test('difficulty rises and caps', () {
      expect(TimeAttackScreen.difficultyFor(0), 6);
      expect(
        TimeAttackScreen.difficultyFor(4),
        greaterThan(TimeAttackScreen.difficultyFor(1)),
      );
      expect(TimeAttackScreen.difficultyFor(500), 140);
    });

    test('free puzzles are solvable and vary by seed', () {
      final a = LevelGenerator.generateFree(1, 20);
      final b = LevelGenerator.generateFree(2, 20);
      expect(a.number, 0);
      expect(Solver(a.board, a.pieces).solve(), isNotNull);
      expect(Solver(b.board, b.pieces).solve(), isNotNull);
      expect(
        a.board.length == b.board.length && a.board.containsAll(b.board),
        isFalse,
      );
      // Same seed, same puzzle.
      expect(LevelGenerator.generateFree(1, 20).board, equals(a.board));
    });

    test('best score only goes up', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await Progress.load();
      expect(await p.recordTimeAttack(4), isTrue);
      expect(await p.recordTimeAttack(3), isFalse);
      expect(await p.recordTimeAttack(7), isTrue);
      expect(p.timeAttackBest, 7);
    });

    testWidgets('intro and play screens fit on a small phone', (tester) async {
      SharedPreferences.setMockInitialValues({'bgfx': false});
      final services = Services.offline(await Progress.load());
      await tester.binding.setSurfaceSize(const Size(360, 640));
      for (final lang in AppLang.values) {
        appLang.value = lang;
        await tester.pumpWidget(
          MaterialApp(
            locale: lang.locale,
            supportedLocales: [for (final l in AppLang.values) l.locale],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: TimeAttackScreen(services: services),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'intro ${lang.name}');
        await tester.tap(find.text(tr('ta_start')));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull, reason: 'play ${lang.name}');
        expect(find.byType(BoardView), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('settings', () {
    test('coin hints cost coins and fail when short', () async {
      SharedPreferences.setMockInitialValues({'coins': 70});
      final p = await Progress.load();
      expect(p.spendCoins(Progress.hintCoinCost), isTrue);
      expect(p.coins, 70 - Progress.hintCoinCost);
      expect(p.spendCoins(Progress.hintCoinCost), isFalse);
      expect(p.coins, 70 - Progress.hintCoinCost);
    });

    test('old sound switches map to volumes', () async {
      SharedPreferences.setMockInitialValues({'sound': false, 'music': true});
      final p = await Progress.load();
      expect(p.soundVolume, 0);
      expect(p.soundOn, isFalse);
      expect(p.musicVolume, 1);
      await p.setMusicVolume(0.4);
      expect(p.musicVolume, closeTo(0.4, 1e-9));
      expect(p.musicOn, isTrue);
      await p.setMusicVolume(0);
      expect(p.musicOn, isFalse);
    });

    test('reset wipes progress but keeps settings and purchases', () async {
      SharedPreferences.setMockInitialValues({
        'coins': 900,
        'unlocked': 120,
        'current': 118,
        'taBest': 9,
        'musicVol': 0.3,
        'lang': 'fr',
        'colorBlind': true,
        'reduceMotion': true,
        'premium': true,
      });
      final p = await Progress.load();
      await p.resetProgress();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('unlocked'), isNull);
      expect(p.timeAttackBest, 0);
      expect(p.coins, Progress.startingCoins);
      expect(p.musicVolume, closeTo(0.3, 1e-9));
      expect(p.languageCode, 'fr');
      expect(p.colorBlind, isTrue);
      expect(p.reduceMotion, isTrue);
      expect(prefs.getBool('premium'), isTrue);
    });

    test('reduce motion is live', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await Progress.load();
      var heard = false;
      p.motion.addListener(() => heard = true);
      await p.setReduceMotion(true);
      expect(heard, isTrue);
      expect(p.motion.value, isTrue);
    });
  });

  group('daily reminder plan', () {
    test('today is skipped once solved or past reminder time', () {
      final morning = DateTime(2026, 3, 10, 9);
      expect(
        Reminders.plan(morning, solvedToday: false).first,
        DateTime(2026, 3, 10),
      );
      expect(
        Reminders.plan(morning, solvedToday: true).first,
        DateTime(2026, 3, 11),
      );
      final evening = DateTime(2026, 3, 10, 20);
      final days = Reminders.plan(evening, solvedToday: false);
      expect(days.first, DateTime(2026, 3, 11));
      expect(days.length, Reminders.daysAhead - 1);
    });

    test('crosses month ends', () {
      final days = Reminders.plan(DateTime(2026, 1, 31, 8), solvedToday: true);
      expect(days, [DateTime(2026, 2, 1), DateTime(2026, 2, 2)]);
    });
  });
}
