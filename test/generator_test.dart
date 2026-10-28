import 'package:block_hexa_puzzle/game/generator.dart';
import 'package:block_hexa_puzzle/game/hex.dart';
import 'package:block_hexa_puzzle/game/level.dart';
import 'package:block_hexa_puzzle/game/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('levels are deterministic', () {
    for (final n in [1, 7, 42, 500]) {
      final a = LevelGenerator.generate(n);
      final b = LevelGenerator.generate(n);
      expect(a.board, b.board);
      expect(a.pieces.map((p) => p.shapeKey), b.pieces.map((p) => p.shapeKey));
    }
  });

  test('every generated level has a valid stored solution', () {
    for (var n = 1; n <= 400; n++) {
      final level = LevelGenerator.generate(n);
      expect(level.verifySolution(), isTrue, reason: 'level $n');
      expect(level.pieces.length, greaterThanOrEqualTo(2));
      for (final p in level.pieces) {
        expect(_connected(p.cells.toSet()), isTrue, reason: 'level $n piece');
      }
    }
  });

  test('independent solver confirms solvability', () {
    for (var n = 1; n <= 80; n++) {
      final level = LevelGenerator.generate(n);
      final solver = Solver(level.board, level.pieces, nodeLimit: 3000000);
      final result = solver.solve();
      expect(result, isNotNull, reason: 'level $n (${solver.nodes} nodes)');
    }
  });

  test('harder levels prefer a single solution', () {
    var unique = 0;
    for (var n = 20; n < 60; n++) {
      final l = LevelGenerator.generate(n);
      if (Solver(l.board, l.pieces, nodeLimit: 200000).countSolutions() == 1) {
        unique++;
      }
    }
    expect(unique, greaterThanOrEqualTo(36), reason: '$unique/40 unique');
  });

  test('solution counter sees multiple solutions', () {
    // A 2-cell board fits either the domino, or both single cells.
    final board = {const Hex(0, 0), const Hex(0, 1)};
    final pieces = [
      Piece([const Hex(0, 0), const Hex(0, 1)], 0),
      Piece([const Hex(0, 0)], 1),
      Piece([const Hex(0, 0)], 2),
    ];
    expect(Solver(board, pieces).countSolutions(limit: 5), 2);
    expect(Solver(board, pieces.sublist(0, 1)).countSolutions(), 1);
  });

  test('very high levels still generate quickly', () {
    final sw = Stopwatch()..start();
    for (final n in [1000, 25000, 999999]) {
      expect(LevelGenerator.generate(n).verifySolution(), isTrue);
    }
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });

  test('difficulty grows with level number', () {
    double avgPieces(int from, int to) {
      var t = 0;
      for (var n = from; n < to; n++) {
        t += LevelGenerator.generate(n).pieces.length;
      }
      return t / (to - from);
    }

    expect(avgPieces(1, 10), lessThan(avgPieces(50, 60)));
    expect(avgPieces(50, 60), lessThan(avgPieces(150, 160)));
  });
}

bool _connected(Set<Hex> cells) {
  final seen = <Hex>{cells.first};
  final stack = [cells.first];
  while (stack.isNotEmpty) {
    final c = stack.removeLast();
    for (final n in c.neighbors) {
      if (cells.contains(n) && seen.add(n)) stack.add(n);
    }
  }
  return seen.length == cells.length;
}
