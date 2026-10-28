import 'package:block_hexa_puzzle/game/game_state.dart';
import 'package:block_hexa_puzzle/game/generator.dart';
import 'package:block_hexa_puzzle/game/hex.dart';
import 'package:block_hexa_puzzle/game/level.dart';
import 'package:flutter_test/flutter_test.dart';

Level _tinyLevel() {
  // A 4-cell board filled by two dominoes, plus one spare decoy single.
  final board = {const Hex(0, 0), const Hex(0, 1), const Hex(1, 0), const Hex(1, 1)};
  return Level(
    number: 99,
    board: board,
    pieces: [
      Piece([const Hex(0, 0), const Hex(0, 1)], 0),
      Piece([const Hex(0, 0), const Hex(0, 1)], 1),
      Piece([const Hex(0, 0)], 2),
    ],
    solution: [const Hex(0, 0), const Hex(1, 0), null],
  );
}

void main() {
  test('placing blocks fills the board and completes the level', () {
    final g = GameState(_tinyLevel());
    expect(g.place(0, const Hex(0, 0)), isTrue);
    expect(g.isComplete, isFalse);
    expect(g.place(1, const Hex(1, 0)), isTrue);
    expect(g.isComplete, isTrue);
    expect(g.isPlaced(2), isFalse, reason: 'spare block is not needed');
  });

  test('blocks cannot overlap or hang off the board', () {
    final g = GameState(_tinyLevel());
    expect(g.place(0, const Hex(0, 0)), isTrue);
    expect(g.place(1, const Hex(0, 1)), isFalse); // overlaps
    expect(g.place(1, const Hex(5, 5)), isFalse); // off board
    expect(g.place(1, const Hex(1, 1)), isFalse); // half off board
  });

  test('blocks can be moved and returned to the tray', () {
    final g = GameState(_tinyLevel());
    g.place(0, const Hex(0, 0));
    expect(g.place(0, const Hex(1, 0)), isTrue, reason: 'move in place');
    expect(g.occupantAt(const Hex(0, 0)), isNull);
    g.remove(0);
    expect(g.isPlaced(0), isFalse);
    expect(g.occupantAt(const Hex(1, 0)), isNull);
  });

  test('restart clears the board', () {
    final g = GameState(_tinyLevel());
    g.place(0, const Hex(0, 0));
    g.applyHint();
    g.reset();
    expect(g.placements.every((p) => p == null), isTrue);
    expect(g.hinted, isEmpty);
  });

  test('hints clear blocking pieces and lock the solution block', () {
    final g = GameState(_tinyLevel());
    // Wrong spot: the single decoy blocks a solution cell.
    g.place(2, const Hex(0, 0));
    final hinted = g.applyHint();
    expect(hinted, isNotNull);
    expect(g.placements[hinted!], g.level.solution[hinted]);
    expect(g.hinted.contains(hinted), isTrue);
    g.remove(hinted);
    expect(g.isPlaced(hinted), isTrue, reason: 'hinted blocks stay locked');
    g.applyHint();
    expect(g.isComplete, isTrue);
  });

  test('hints can finish any generated level', () {
    for (final n in [1, 5, 20, 77, 300]) {
      final g = GameState(LevelGenerator.generate(n));
      var guard = 0;
      while (!g.isComplete && guard++ < 50) {
        g.applyHint();
      }
      expect(g.isComplete, isTrue, reason: 'level $n');
    }
  });

  test('in-progress board survives a save/restore round trip', () {
    final g = GameState(_tinyLevel());
    g.place(0, const Hex(0, 0));
    final json = g.toJson();
    final g2 = GameState(_tinyLevel())..restore(json);
    expect(g2.placements, g.placements);
  });

  test('hex pixel conversion round-trips', () {
    for (var q = -5; q <= 5; q++) {
      for (var r = -5; r <= 5; r++) {
        final h = Hex(q, r);
        expect(Hex.fromPixel(h.toPixel(30), 30), h);
      }
    }
  });
}
