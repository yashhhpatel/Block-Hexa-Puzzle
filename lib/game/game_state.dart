import 'package:flutter/foundation.dart';

import 'hex.dart';
import 'level.dart';

/// Rules for one level: which pieces sit where, and whether the board is full.
class GameState extends ChangeNotifier {
  final Level level;

  /// Board anchor of each piece, or null while it sits in the tray.
  final List<Hex?> placements;

  /// Pieces placed by a hint; they are locked in their solution spot.
  final Set<int> hinted = {};

  final Map<Hex, int> _occupant = {};

  GameState(this.level) : placements = List.filled(level.pieces.length, null);

  bool get isComplete => _occupant.length == level.board.length;

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
      };

  /// Restores a saved in-progress board for the same level.
  void restore(Map<String, dynamic> json) {
    if (json['level'] != level.number) return;
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
