import 'package:block_hexa_puzzle/game/generator.dart';
import 'package:block_hexa_puzzle/game/solver.dart';
import 'package:block_hexa_puzzle/l10n/l10n.dart';
import 'package:block_hexa_puzzle/meta/chapters.dart';
import 'package:block_hexa_puzzle/ui/board_view.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => appLang.value = AppLang.en);

  test('levels 1-400 are exactly the same as before the new chapters', () {
    // Fingerprint of every board and block of levels 1-400, recorded before
    // the hard chapters were added. Players' saved progress depends on it.
    var h = 0;
    for (var n = 1; n <= 400; n++) {
      final l = LevelGenerator.generate(n);
      final cells = l.board.map((c) => '${c.q},${c.r}').toList()..sort();
      final key =
          '$n|${cells.join(';')}|${l.pieces.map((p) => p.shapeKey).join('/')}';
      for (final u in key.codeUnits) {
        h = (h * 31 + u) & 0x3fffffff;
      }
    }
    expect(h, 953614956);
  });

  test('chapter ranges', () {
    final expected = {
      'Beginner': (1, 20),
      'Easy': (21, 100),
      'Normal': (101, 250),
      'Hard': (251, 400),
      'Expert': (401, 550),
      'Master': (551, 700),
      'Insane': (701, 800),
      'Nightmare': (801, 900),
      'Legendary': (901, 1000),
      'Impossible': (1001, 1200),
    };
    var i = 0;
    for (final e in expected.entries) {
      final c = Chapters.at(i++);
      expect(c.name, e.key);
      expect((c.first, c.last), e.value, reason: e.key);
    }
    expect(Chapters.fixedCount, 10);
    expect(Chapters.forLevel(1200).name, 'Impossible');
    expect(Chapters.forLevel(1201).name, 'Grandmaster I');
    expect(Chapters.forLevel(1300).name, 'Grandmaster I');
    expect(Chapters.forLevel(1634).name, 'Grandmaster V');
  });

  test('difficulty tiers start exactly at the hard chapters', () {
    final hard = [for (var i = 4; i < Chapters.fixedCount; i++) Chapters.at(i)];
    expect(Difficulty.hardStarts, [
      ...hard.map((c) => c.first),
      Chapters.at(Chapters.fixedCount).first,
    ]);
    expect(Difficulty.hardTier(400), 0);
    for (var i = 0; i < hard.length; i++) {
      expect(Difficulty.hardTier(hard[i].first), i + 1, reason: hard[i].name);
      expect(Difficulty.hardTier(hard[i].last), i + 1, reason: hard[i].name);
    }
    expect(Difficulty.hardTier(5000), Difficulty.hardStarts.length);
  });

  test('every named chapter has its own emoji and colour', () {
    final chapters = [for (var i = 0; i < 10; i++) Chapters.at(i)];
    expect(chapters.map((c) => c.emoji).toSet().length, 10);
    expect(chapters.map((c) => c.color).toSet().length, 10);
    expect(Chapters.at(4).emoji, '🔴');
    expect(Chapters.at(5).emoji, '🟣');
    expect(Chapters.at(6).emoji, '⚡');
    expect(Chapters.at(7).emoji, '💀');
    expect(Chapters.at(8).emoji, '👑');
    expect(Chapters.at(9).emoji, '🔥');
    expect(Chapters.at(6).title, '⚡ Insane');
  });

  test('new chapters get harder step by step and stay solvable', () {
    double avgPieces(int from) {
      var t = 0;
      for (var n = from; n < from + 15; n++) {
        final l = LevelGenerator.generate(n);
        expect(l.verifySolution(), isTrue, reason: 'level $n');
        t += l.pieces.length;
      }
      return t / 15;
    }

    // Past each chapter's 20-level warm-up.
    final hard = avgPieces(321);
    final steps = [
      for (final start in Difficulty.hardStarts) avgPieces(start + 25),
    ];
    expect(steps.first, greaterThan(hard));
    // Expert < Master < Insane < Nightmare < Legendary < Impossible; the
    // endless Grandmaster chapters match Impossible's size with more decoys.
    for (var i = 1; i < steps.length - 1; i++) {
      expect(steps[i], greaterThan(steps[i - 1]), reason: 'tier ${i + 1}');
    }
  });

  test('hard chapters use look-alike spare blocks', () {
    for (final n in [450, 650, 750, 850, 950, 1100, 1300]) {
      final l = LevelGenerator.generate(n);
      expect(l.decoyCount, greaterThanOrEqualTo(1), reason: 'level $n');
      // An independent solver still finds a solution.
      expect(Solver(l.board, l.pieces, nodeLimit: 3000000).solve(), isNotNull);
    }
  });

  test('the busiest boards still fit on a small phone', () {
    // Play area of a small 360x720 phone, between the header and the
    // control bar + banner.
    const area = Size(360, 520);
    for (final n in [700, 800, 1000, 1150, 1200, 1250, 1500]) {
      final l = LevelGenerator.generate(n);
      final layout = BoardLayout.compute(area, l);
      expect(layout.cell, greaterThan(10), reason: 'level $n board cells');
      expect(layout.trayCell, greaterThan(7), reason: 'level $n tray blocks');
      for (var i = 0; i < l.pieces.length; i++) {
        final b = l.pieces[i].unitBounds;
        final rect = Rect.fromCenter(
          center: layout.traySlots[i],
          width: b.width * layout.trayCell,
          height: b.height * layout.trayCell,
        );
        expect(
          layout.trayRect.inflate(1).contains(rect.topLeft),
          isTrue,
          reason: 'level $n block $i',
        );
        expect(
          layout.trayRect.inflate(1).contains(rect.bottomRight),
          isTrue,
          reason: 'level $n block $i',
        );
      }
    }
  });
}
