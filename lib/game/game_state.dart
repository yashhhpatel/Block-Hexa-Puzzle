import 'package:flutter/foundation.dart';

import 'hex.dart';
import 'level.dart';

/// Bump when level generation changes, so old saved boards are discarded.
const int kSaveVersion = 2;

/// Rules for one level: which pieces sit where, and whether the board is full.
class GameState extends ChangeNotifier {
  final Level level;

  /// Board anchor of each piece, or null while it sits in the tray.
  final List<Hex?> placements;

  /// Pieces placed by a hint; they are locked in their solution spot.
  final Set<int> hinted = {};

  final Map<Hex, int> _occupant = {};

  /// Snapshots for Undo; each entry is the board before one player move.
  final List<_Snapshot> _history = [];
  _Snapshot? _moveStart;

  /// Hints spent on this attempt (affects the "no hints" star).
  int hintsUsed = 0;

  /// Blocks the player has put on the board this attempt.
  int blocksPlaced = 0;

  GameState(this.level) : placements = List.filled(level.pieces.length, null);

  bool get isComplete => _occupant.length == level.board.length;

  int get emptyCells => level.board.length - _occupant.length;

  bool get canUndo => _history.isNotEmpty;

  /// Call when the player starts dragging; pairs with [endMove].
  void beginMove() => _moveStart = _snapshot();

  /// Records the move for Undo if the board actually changed.
  void endMove() {
    final start = _moveStart;
    _moveStart = null;
    if (start == null) return;
    if (!start.sameAs(_snapshot())) {
      _history.add(start);
      if (_history.length > 200) _history.removeAt(0);
      notifyListeners();
    }
  }

  void undo() {
    if (_history.isEmpty) return;
    _apply(_history.removeLast());
    notifyListeners();
  }

  _Snapshot _snapshot() => _Snapshot([...placements], {...hinted});

  void _apply(_Snapshot s) {
    _occupant.clear();
    hinted
      ..clear()
      ..addAll(s.hinted);
    for (var i = 0; i < placements.length; i++) {
      placements[i] = s.placements[i];
      final a = placements[i];
      if (a == null) continue;
      for (final c in level.pieces[i].cellsAt(a)) {
        _occupant[c] = i;
      }
    }
  }

  int? occupantAt(Hex h) => _occupant[h];

  bool isPlaced(int piece) => placements[piece] != null;

  bool canPlace(int piece, Hex anchor) {
    for (final c in level.pieces[piece].cellsAt(anchor)) {
      if (!level.board.contains(c)) return false;
      final o = _occupant[c];
      if (o != null && o != piece) return false;
    }
    return true;
  }

  bool place(int piece, Hex anchor) {
    if (!canPlace(piece, anchor)) return false;
    if (_moveStart != null) blocksPlaced++;
    _lift(piece);
    placements[piece] = anchor;
    for (final c in level.pieces[piece].cellsAt(anchor)) {
      _occupant[c] = piece;
    }
    notifyListeners();
    return true;
  }

  /// Returns a placed piece to the tray.
  void remove(int piece) {
    if (hinted.contains(piece)) return;
    _lift(piece);
    notifyListeners();
  }

  void _lift(int piece) {
    final a = placements[piece];
    if (a == null) return;
    for (final c in level.pieces[piece].cellsAt(a)) {
      _occupant.remove(c);
    }
    placements[piece] = null;
  }

  void reset() {
    if (_occupant.isNotEmpty) _history.add(_snapshot());
    for (var i = 0; i < placements.length; i++) {
      placements[i] = null;
    }
    _occupant.clear();
    hinted.clear();
    notifyListeners();
  }

  /// Puts the next solution piece in place, clearing anything in its way.
  /// Returns the hinted piece, or null when nothing is left to hint.
  int? applyHint() {
    int? pick;
    for (var i = 0; i < level.pieces.length; i++) {
      final target = level.solution[i];
      if (target == null || hinted.contains(i)) continue;
      if (placements[i] == target) {
        // Already correct: lock it so later hints keep it.
        hinted.add(i);
        continue;
      }
      // Prefer pieces still in the tray, like a player would.
      if (pick == null || (isPlaced(pick) && !isPlaced(i))) pick = i;
    }
    if (pick == null) {
      notifyListeners();
      return null;
    }
    final target = level.solution[pick]!;
    // A paid hint can't be undone, so earlier moves are no longer undoable.
    _history.clear();
    hintsUsed++;
    _lift(pick);
    for (final c in level.pieces[pick].cellsAt(target)) {
      final o = _occupant[c];
      if (o != null) _lift(o);
    }
    placements[pick] = target;
    for (final c in level.pieces[pick].cellsAt(target)) {
      _occupant[c] = pick;
    }
    hinted.add(pick);
    notifyListeners();
    return pick;
  }

  Map<String, dynamic> toJson() => {
        'level': level.number,
        'placements': [for (final p in placements) p?.toJson()],
        'hinted': hinted.toList(),
        'hintsUsed': hintsUsed,
        'version': kSaveVersion,
      };

  /// Restores a saved in-progress board for the same level.
  void restore(Map<String, dynamic> json) {
    if (json['level'] != level.number) return;
    if (json['version'] != kSaveVersion) return;
    hintsUsed = (json['hintsUsed'] as int?) ?? 0;
    final saved = json['placements'] as List<dynamic>;
    if (saved.length != placements.length) return;
    final hints = (json['hinted'] as List<dynamic>).cast<int>().toSet();
    for (var i = 0; i < saved.length; i++) {
      final a = saved[i];
      if (a != null) place(i, Hex.fromJson(a as List<dynamic>));
    }
    hinted.addAll(hints.where((i) => placements[i] == level.solution[i]));
    notifyListeners();
  }
}

class _Snapshot {
  final List<Hex?> placements;
  final Set<int> hinted;
  _Snapshot(this.placements, this.hinted);

  bool sameAs(_Snapshot o) {
    for (var i = 0; i < placements.length; i++) {
      if (placements[i] != o.placements[i]) return false;
    }
    return hinted.length == o.hinted.length && hinted.containsAll(o.hinted);
  }
}
