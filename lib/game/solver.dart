import 'hex.dart';
import 'level.dart';

/// Exact-cover backtracking solver: finds anchors for a subset of pieces that
/// fill every board cell exactly once (spare pieces may stay unused).
class Solver {
  final Set<Hex> board;
  final List<Piece> pieces;
  final int nodeLimit;

  int nodes = 0;
  late final List<Hex> _order;

  Solver(this.board, this.pieces, {this.nodeLimit = 2000000}) {
    _order = board.toList()
      ..sort((a, b) {
        final ya = 2 * a.r + a.q, yb = 2 * b.r + b.q;
        return ya != yb ? ya - yb : a.q - b.q;
      });
  }

  /// Returns anchors per piece (null = unused), or null when no solution was
  /// found within the node budget. [fixed] pre-places pieces that must stay.
  List<Hex?>? solve({Map<int, Hex> fixed = const {}}) {
    nodes = 0;
    final filled = <Hex>{};
    final result = List<Hex?>.filled(pieces.length, null);
    final used = List<bool>.filled(pieces.length, false);
    for (final e in fixed.entries) {
      for (final c in pieces[e.key].cellsAt(e.value)) {
        if (!board.contains(c) || !filled.add(c)) return null;
      }
      used[e.key] = true;
      result[e.key] = e.value;
    }
    return _search(filled, used, result) ? result : null;
  }

  bool _search(Set<Hex> filled, List<bool> used, List<Hex?> result) {
    if (++nodes > nodeLimit) return false;
    Hex? target;
    for (final h in _order) {
      if (!filled.contains(h)) {
        target = h;
        break;
      }
    }
    if (target == null) return true;

    final empty = board.length - filled.length;
    var capacity = 0;
    var smallest = 1 << 30;
    for (var i = 0; i < pieces.length; i++) {
      if (used[i]) continue;
      capacity += pieces[i].size;
      if (pieces[i].size < smallest) smallest = pieces[i].size;
    }
    if (capacity < empty) return false;
    if (_hasTooSmallHole(filled, smallest)) return false;

    final tried = <String>{};
    for (var i = 0; i < pieces.length; i++) {
      if (used[i]) continue;
      final piece = pieces[i];
      // Identical shapes are interchangeable; trying one is enough.
      if (!tried.add(piece.shapeKey)) continue;
      for (final cell in piece.cells) {
        final anchor = target - cell;
        final placed = piece.cellsAt(anchor).toList();
        if (placed.any((c) => !board.contains(c) || filled.contains(c))) continue;
        filled.addAll(placed);
        used[i] = true;
        result[i] = anchor;
        if (_search(filled, used, result)) return true;
        filled.removeAll(placed);
        used[i] = false;
        result[i] = null;
      }
    }
    return false;
  }

  /// Any empty pocket smaller than the smallest remaining piece is a dead end.
  bool _hasTooSmallHole(Set<Hex> filled, int smallest) {
    final seen = <Hex>{};
    for (final h in board) {
      if (filled.contains(h) || seen.contains(h)) continue;
      var size = 0;
      final stack = [h];
      seen.add(h);
      while (stack.isNotEmpty) {
        final c = stack.removeLast();
        size++;
        for (final n in c.neighbors) {
          if (board.contains(n) && !filled.contains(n) && seen.add(n)) {
            stack.add(n);
          }
        }
      }
      if (size < smallest) return true;
    }
    return false;
  }
}
