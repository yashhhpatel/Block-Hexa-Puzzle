import 'dart:ui';

import 'hex.dart';

/// A polyhex block. [cells] are relative to the piece anchor; cells[0] is
/// always (0,0), so placing the piece at board cell `a` covers `a + cell`.
class Piece {
  final List<Hex> cells;
  final int colorIndex;

  Piece(List<Hex> cells, this.colorIndex) : cells = normalize(cells);

  int get size => cells.length;

  /// Centroid of the cells in unit-size pixel space (size = 1).
  Offset get unitCentroid {
    var x = 0.0, y = 0.0;
    for (final c in cells) {
      final p = c.toPixel(1);
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / cells.length, y / cells.length);
  }

  /// Bounding box of the piece's hexagons in unit-size pixel space.
  Rect get unitBounds {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final c in cells) {
      final p = c.toPixel(1);
      if (p.dx - 1 < minX) minX = p.dx - 1;
      if (p.dx + 1 > maxX) maxX = p.dx + 1;
      if (p.dy - 0.866 < minY) minY = p.dy - 0.866;
      if (p.dy + 0.866 > maxY) maxY = p.dy + 0.866;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Iterable<Hex> cellsAt(Hex anchor) => cells.map((c) => anchor + c);

  /// Sorts cells (top-to-bottom, left-to-right) and shifts so cells[0] is the origin.
  static List<Hex> normalize(List<Hex> cells) {
    final sorted = [...cells]
      ..sort((a, b) {
        final ya = 2 * a.r + a.q, yb = 2 * b.r + b.q;
        return ya != yb ? ya - yb : a.q - b.q;
      });
    final base = sorted.first;
    return [for (final c in sorted) c - base];
  }

  /// Canonical key for comparing shapes (translation only, no rotation).
  String get shapeKey => cells.map((c) => '${c.q},${c.r}').join(';');
}

class Level {
  final int number;
  final Set<Hex> board;
  final List<Piece> pieces;

  /// Anchor of each piece in the generated solution; null for decoy pieces.
  final List<Hex?> solution;

  Level({
    required this.number,
    required this.board,
    required this.pieces,
    required this.solution,
  });

  int get decoyCount => solution.where((s) => s == null).length;
  bool get hasDecoys => decoyCount > 0;

  /// Checks that the stored solution exactly covers the board.
  bool verifySolution() {
    final covered = <Hex>{};
    for (var i = 0; i < pieces.length; i++) {
      final a = solution[i];
      if (a == null) continue;
      for (final c in pieces[i].cellsAt(a)) {
        if (!board.contains(c) || !covered.add(c)) return false;
      }
    }
    return covered.length == board.length;
  }
}
