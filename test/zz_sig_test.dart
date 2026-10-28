import 'package:block_hexa_puzzle/game/generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sig', () {
    var h = 0;
    for (var n = 1; n <= 400; n++) {
      final l = LevelGenerator.generate(n);
      final cells = l.board.map((c) => '${c.q},${c.r}').toList()..sort();
      final key = '$n|${cells.join(';')}|${l.pieces.map((p) => p.shapeKey).join('/')}';
      for (final u in key.codeUnits) {
        h = (h * 31 + u) & 0x3fffffff;
      }
    }
    // ignore: avoid_print
    print('SIG=$h');
  });
}
