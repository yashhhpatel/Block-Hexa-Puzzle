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

  test('original chapter ranges are unchanged; new chapters follow', () {
    final expected = {
      'Beginner': (1, 20),
      'Easy': (21, 60),
      'Normal': (61, 120),
      'Hard': (121, 200),
      'Expert': (201, 300),
      'Master': (301, 400),
      'Insane': (401, 500),
      'Nightmare': (501, 600),
      'Legendary': (601, 700),
      'Impossible': (701, 800),
    };
    var i = 0;
    for (final e in expected.entries) {
      final c = Chapters.at(i++);
      expect(c.name, e.key);
      expect((c.first, c.last), e.value, reason: e.key);
    }
    expect(Chapters.fixedCount, 10);
    expect(Chapters.forLevel(801).name, 'Grandmaster I');
    expect(Chapters.forLevel(1234).name, 'Grandmaster V');
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

    final master = avgPieces(301);
    final insane = avgPieces(401);
    final nightmare = avgPieces(501);
    final legendary = avgPieces(601);
    final impossible = avgPieces(701);
    expect(insane, greaterThan(master));
    expect(nightmare, greaterThan(insane));
    expect(legendary, greaterThan(nightmare));
    expect(impossible, greaterThan(legendary));
  });

  test('hard chapters use look-alike spare blocks', () {
    for (final n in [450, 550, 650, 750]) {
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
    for (final n in [700, 750, 799, 800, 1000]) {
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
        expect(layout.trayRect.inflate(1).contains(rect.topLeft), isTrue,
            reason: 'level $n block $i');
        expect(layout.trayRect.inflate(1).contains(rect.bottomRight), isTrue,
            reason: 'level $n block $i');
      }
    }
  });
}
