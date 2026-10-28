import 'hex.dart';
import 'level.dart';

/// Exact-cover backtracking solver: finds anchors for a subset of pieces that
/// fill every board cell exactly once (spare pieces may stay unused).
///
/// Board cells are indexed and every legal placement of every piece is
/// precomputed, so the search itself only touches small integer arrays.
class Solver {
  final Set<Hex> board;
  final List<Piece> pieces;
  final int nodeLimit;

  int nodes = 0;

  late final List<Hex> _cells; // index -> cell, in top-left-first order
  late final Map<Hex, int> _index;
  late final List<List<int>> _adj; // neighbour indices per cell

  /// For each cell: placements whose top-most cell is that cell, as
  /// (piece, anchor, covered cell indices). The search always fills the
  /// first empty cell, so only placements starting there can cover it.
  late final List<List<_Placement>> _startingAt;

  Solver(this.board, this.pieces, {this.nodeLimit = 2000000}) {
    _cells = board.toList()
      ..sort((a, b) {
        final ya = 2 * a.r + a.q, yb = 2 * b.r + b.q;
        return ya != yb ? ya - yb : a.q - b.q;
      });
    _index = {for (var i = 0; i < _cells.length; i++) _cells[i]: i};
    _adj = [
      for (final c in _cells)
        [for (final n in c.neighbors) if (_index.containsKey(n)) _index[n]!]
    ];
    _startingAt = List.generate(_cells.length, (_) => <_Placement>[]);
    for (var p = 0; p < pieces.length; p++) {
      final seen = <int>{};
      for (final cell in pieces[p].cells) {
        for (final target in _cells) {
          final anchor = target - cell;
          final idx = <int>[];
          var ok = true;
          for (final c in pieces[p].cellsAt(anchor)) {
            final i = _index[c];
            if (i == null) {
              ok = false;
              break;
            }
            idx.add(i);
          }
          if (!ok) continue;
          idx.sort();
          // Key by top-most covered cell; dedupe identical coverings.
          if (!seen.add(idx.fold(0, (h, i) => h * 131 + i + 1))) continue;
          _startingAt[idx.first].add(_Placement(p, anchor, idx));
        }
      }
    }
  }

  /// Returns anchors per piece (null = unused), or null when no solution was
  /// found within the node budget. [fixed] pre-places pieces that must stay.
  List<Hex?>? solve({Map<int, Hex> fixed = const {}}) {
    _countLimit = 0;
    final st = _State(_cells.length, pieces.length);
    for (final e in fixed.entries) {
      for (final c in pieces[e.key].cellsAt(e.value)) {
        final i = _index[c];
        if (i == null || st.filled[i]) return null;
        st.filled[i] = true;
        st.empty--;
      }
      st.used[e.key] = true;
      st.result[e.key] = e.value;
    }
    nodes = 0;
    return _search(st) ? st.result : null;
  }

  /// Counts distinct solutions up to [limit]. Returns -1 when the node
  /// budget ran out before the answer was certain.
  int countSolutions({int limit = 2}) {
    nodes = 0;
    _countLimit = limit;
    _found = 0;
    _search(_State(_cells.length, pieces.length));
    final result = _found;
    _countLimit = 0;
    if (nodes > nodeLimit && result < limit) return -1;
    return result;
  }

  int _countLimit = 0;
  int _found = 0;

  bool _search(_State st) {
    if (++nodes > nodeLimit) return false;
    var target = -1;
    for (var i = st.cursor; i < _cells.length; i++) {
      if (!st.filled[i]) {
        target = i;
        break;
      }
    }
    if (target < 0) {
      if (_countLimit == 0) return true;
      // Counting mode: record and keep searching until the limit is hit.
      return ++_found >= _countLimit;
    }

    var capacity = 0;
    var smallest = 1 << 30;
    for (var i = 0; i < pieces.length; i++) {
      if (st.used[i]) continue;
      capacity += pieces[i].size;
      if (pieces[i].size < smallest) smallest = pieces[i].size;
    }
    if (capacity < st.empty) return false;
    if (_hasTooSmallHole(st, smallest)) return false;

    final savedCursor = st.cursor;
    st.cursor = target;
    final tried = <String>{};
    for (final pl in _startingAt[target]) {
      if (st.used[pl.piece]) continue;
      if (!_fits(st, pl.cells)) continue;
      // Identical shapes in the same spot are interchangeable.
      if (!tried.add('${pieces[pl.piece].shapeKey}@${pl.cells.first}')) continue;
      for (final i in pl.cells) {
        st.filled[i] = true;
      }
      st.empty -= pl.cells.length;
      st.used[pl.piece] = true;
      st.result[pl.piece] = pl.anchor;
      if (_search(st)) return true;
      for (final i in pl.cells) {
        st.filled[i] = false;
      }
      st.empty += pl.cells.length;
      st.used[pl.piece] = false;
      st.result[pl.piece] = null;
      if (nodes > nodeLimit) break;
    }
    st.cursor = savedCursor;
    return false;
  }

  static bool _fits(_State st, List<int> cells) {
    for (final i in cells) {
      if (st.filled[i]) return false;
    }
    return true;
  }

  /// Any empty pocket smaller than the smallest remaining piece is a dead end.
  bool _hasTooSmallHole(_State st, int smallest) {
    final seen = st.seen..fillRange(0, st.seen.length, false);
    final stack = st.stack;
    for (var h = st.cursor; h < _cells.length; h++) {
      if (st.filled[h] || seen[h]) continue;
      var size = 0;
      stack.clear();
      stack.add(h);
      seen[h] = true;
      while (stack.isNotEmpty) {
        final c = stack.removeLast();
        size++;
        for (final n in _adj[c]) {
          if (!st.filled[n] && !seen[n]) {
            seen[n] = true;
            stack.add(n);
          }
        }
      }
      if (size < smallest) return true;
    }
    return false;
  }
}

class _Placement {
  final int piece;
  final Hex anchor;
  final List<int> cells;
  _Placement(this.piece, this.anchor, this.cells);
}

class _State {
  final List<bool> filled;
  final List<bool> used;
  final List<Hex?> result;
  final List<bool> seen;
  final List<int> stack = [];
  int empty;
  int cursor = 0;

  _State(int cells, int pieces)
      : filled = List.filled(cells, false),
        used = List.filled(pieces, false),
        result = List.filled(pieces, null),
        seen = List.filled(cells, false),
        empty = cells;
}
