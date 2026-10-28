import 'package:block_hexa_puzzle/game/generator.dart';
import 'package:block_hexa_puzzle/game/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bench', () {
    for (final range in [[15, 40], [40, 100], [100, 200], [300, 340]]) {
      var unique = 0, worst = 0, total = 0;
      for (var n = range[0]; n < range[1]; n++) {
        final sw = Stopwatch()..start();
        final l = LevelGenerator.generate(n);
        final ms = sw.elapsedMilliseconds;
        total += ms;
        if (ms > worst) worst = ms;
        if (Solver(l.board, l.pieces, nodeLimit: 12000).countSolutions() == 1) unique++;
      }
      print('levels $range: unique $unique/${range[1] - range[0]}, avg ${total / (range[1] - range[0])}ms, worst ${worst}ms');
    }
  });
}
