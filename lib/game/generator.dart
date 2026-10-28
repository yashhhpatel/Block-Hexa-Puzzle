import 'dart:math' as math;

import 'hex.dart';
import 'level.dart';

/// Number of distinct block colours available to the renderer.
const int kPaletteSize = 14;

/// Difficulty knobs derived from the level number.
class Difficulty {
  final int pieceCount;
  final int minPieceSize;
  final int maxPieceSize;
  final int decoys;

  const Difficulty({
    required this.pieceCount,
    required this.minPieceSize,
    required this.maxPieceSize,
    required this.decoys,
  });

  /// Smoothly ramps from 3 small blocks at level 1 to 11-14 larger blocks,
  /// adding spare "decoy" blocks as levels get harder.
  factory Difficulty.forLevel(int level, math.Random rng) {
    final n = math.max(1, level);
    final base = 3 + math.sqrt(n - 1).floor();
    int count;
    if (base >= 14) {
      count = 11 + rng.nextInt(4); // plateau: 11..14
    } else {
      count = (base - (n > 8 ? rng.nextInt(2) : 0)).clamp(3, 14);
    }
    final minSize = n < 4 ? 2 : (n < 40 ? 2 : 3);
    final maxSize = n < 4 ? 4 : (n < 15 ? 5 : (n < 60 ? 6 : 7));

    var decoys = 0;
    if (n >= 6) {
      final chance = math.min(0.55, 0.15 + n * 0.004);
      if (rng.nextDouble() < chance) decoys = 1;
      if (n >= 60 && rng.nextDouble() < 0.25) decoys = 2;
    }
    return Difficulty(
      pieceCount: count,
      minPieceSize: minSize,
      maxPieceSize: maxSize,
      decoys: decoys,
    );
  }
}

enum BoardStyle { symmetric, blob, twin }

/// Procedurally builds a solvable level for any level number.
///
/// The same number always yields the same level, and there is no upper limit.
/// Solvability is guaranteed by construction: the board is grown first, then
/// cut into connected blocks, so the cut itself is a valid solution.
class LevelGenerator {
  static Level generate(int levelNumber) {
    final rng = math.Random(_seedFor(levelNumber));
    final diff = Difficulty.forLevel(levelNumber, rng);

    for (var attempt = 0;; attempt++) {
      // Relax the target if a shape refuses to split nicely.
      final pieceCount = math.max(2, diff.pieceCount - attempt ~/ 40);
      final level = _tryBuild(levelNumber, rng, diff, pieceCount);
      if (level != null && level.verifySolution()) return level;
    }
  }

  static int _seedFor(int level) => (level * 2654435761 + 97) & 0x7fffffff;

  static Level? _tryBuild(
      int levelNumber, math.Random rng, Difficulty diff, int pieceCount) {
    final avg = (diff.minPieceSize + diff.maxPieceSize) / 2;
    final targetCells = (pieceCount * avg).round();

    final style = levelNumber == 1
        ? BoardStyle.twin
        : _pickStyle(rng);

    List<Set<Hex>> components;
    switch (style) {
      case BoardStyle.twin:
        final half = _growBlob(rng, (targetCells / 2).round(), mirror: false);
        components = [half, _mirroredCopyBeside(half)];
      case BoardStyle.symmetric:
        components = [_growBlob(rng, targetCells, mirror: true)];
      case BoardStyle.blob:
        components = [_growBlob(rng, targetCells, mirror: false)];
    }

    final regions = <Set<Hex>>[];
    final total = components.fold<int>(0, (s, c) => s + c.length);
    var remaining = pieceCount;
    for (var i = 0; i < components.length; i++) {
      final comp = components[i];
      final k = i == components.length - 1
          ? remaining
          : math.max(1, (pieceCount * comp.length / total).round());
      remaining -= k;
      final parts = _partition(rng, comp, k, diff.minPieceSize, diff.maxPieceSize);
      if (parts == null) return null;
      regions.addAll(parts);
    }

    final board = <Hex>{for (final c in components) ...c};
    final colorOrder = List.generate(kPaletteSize, (i) => i)..shuffle(rng);

    final entries = <(Piece, Hex?)>[];
    for (final region in regions) {
      final piece = Piece(region.toList(), 0);
      // Anchor is the region cell that became the piece's (0,0).
      final anchor = _anchorOf(region);
      entries.add((piece, anchor));
    }
    for (var d = 0; d < diff.decoys; d++) {
      final size = diff.minPieceSize + rng.nextInt(math.max(1, diff.maxPieceSize - diff.minPieceSize));
      entries.add((Piece(_growBlob(rng, size, mirror: false).toList(), 0), null));
    }
    entries.shuffle(rng);

    final pieces = <Piece>[];
    final solution = <Hex?>[];
    for (var i = 0; i < entries.length; i++) {
      pieces.add(Piece(entries[i].$1.cells, colorOrder[i % kPaletteSize]));
      solution.add(entries[i].$2);
    }
    return Level(number: levelNumber, board: board, pieces: pieces, solution: solution);
  }

  static BoardStyle _pickStyle(math.Random rng) {
    final x = rng.nextDouble();
    if (x < 0.55) return BoardStyle.symmetric;
    if (x < 0.88) return BoardStyle.blob;
    return BoardStyle.twin;
  }

  static Hex _anchorOf(Set<Hex> region) {
    final sorted = region.toList()
      ..sort((a, b) {
        final ya = 2 * a.r + a.q, yb = 2 * b.r + b.q;
        return ya != yb ? ya - yb : a.q - b.q;
      });
    return sorted.first;
  }

  /// Grows a compact connected cluster of about [n] cells. With [mirror] the
  /// cluster is left/right symmetric, which gives the tidy board outlines.
  static Set<Hex> _growBlob(math.Random rng, int n, {required bool mirror}) {
    final cells = <Hex>{Hex.origin};
    if (mirror && n > 1) cells.add(const Hex(0, 1));
    while (cells.length < n) {
      final frontier = <Hex>{};
      for (final c in cells) {
        for (final nb in c.neighbors) {
          if (!cells.contains(nb)) frontier.add(nb);
        }
      }
      final list = frontier.toList();
      if (mirror && n - cells.length == 1) {
        final onAxis = list.where((h) => h.q == 0).toList();
        if (onAxis.isNotEmpty) {
          cells.add(onAxis[rng.nextInt(onAxis.length)]);
          continue;
        }
      }
      // Favour cells that touch many existing cells -> compact, hole-free shapes.
      final weights = list.map((h) {
        final k = h.neighbors.where(cells.contains).length;
        return k * k * k + 0.3;
      }).toList();
      final pick = list[_weightedIndex(rng, weights)];
      cells.add(pick);
      if (mirror) cells.add(pick.mirrored);
    }
    return cells;
  }

  /// Places a mirror image of [shape] to its right with a one-cell gap.
  static Set<Hex> _mirroredCopyBeside(Set<Hex> shape) {
    final mirrored = shape.map((h) => h.mirrored).toSet();
    // Shifting by (2k, -k) moves right without changing screen height.
    for (var k = 1;; k++) {
      final shift = Hex(2 * k, -k);
      final moved = mirrored.map((h) => h + shift).toSet();
      final clash = moved.any(
          (h) => shape.contains(h) || h.neighbors.any(shape.contains));
      if (!clash) return moved;
    }
  }

  /// Splits [cells] into [k] connected regions sized within [minS]..[maxS].
  static List<Set<Hex>>? _partition(
      math.Random rng, Set<Hex> cells, int k, int minS, int maxS) {
    k = math.min(k, cells.length ~/ minS);
    if (k <= 0) return null;
    if (cells.length > k * maxS) {
      // Allow slightly larger blocks rather than failing on big boards.
      maxS = (cells.length / k).ceil() + 1;
    }
    final all = cells.toList();
    for (var tries = 0; tries < 60; tries++) {
      final owner = <Hex, int>{};
      final regions = <Set<Hex>>[];

      // Spread seeds out: each new seed is the farthest of a few random picks.
      final seeds = <Hex>[all[rng.nextInt(all.length)]];
      while (seeds.length < k) {
        Hex? best;
        var bestD = -1;
        for (var s = 0; s < 8; s++) {
          final cand = all[rng.nextInt(all.length)];
          if (seeds.contains(cand)) continue;
          final d = seeds.map(cand.distanceTo).reduce(math.min);
          if (d > bestD) {
            bestD = d;
            best = cand;
          }
        }
        if (best == null) break;
        seeds.add(best);
      }
      if (seeds.length < k) continue;
      for (var i = 0; i < k; i++) {
        owner[seeds[i]] = i;
        regions.add({seeds[i]});
      }

      var progress = true;
      while (owner.length < all.length && progress) {
        progress = false;
        final order = List.generate(k, (i) => i)
          ..sort((a, b) => regions[a].length - regions[b].length);
        for (final i in order) {
          if (regions[i].length >= maxS) continue;
          final options = <Hex>[];
          for (final c in regions[i]) {
            for (final nb in c.neighbors) {
              if (cells.contains(nb) && !owner.containsKey(nb)) options.add(nb);
            }
          }
          if (options.isEmpty) continue;
          final pick = options[rng.nextInt(options.length)];
          owner[pick] = i;
          regions[i].add(pick);
          progress = true;
          break; // regrow from the (new) smallest region
        }
      }

      if (owner.length < all.length) continue;
      if (regions.any((r) => r.length < minS || r.length > maxS)) continue;
      return regions;
    }
    return null;
  }

  static int _weightedIndex(math.Random rng, List<double> w) {
    final total = w.fold<double>(0, (a, b) => a + b);
    var x = rng.nextDouble() * total;
    for (var i = 0; i < w.length; i++) {
      x -= w[i];
      if (x <= 0) return i;
    }
    return w.length - 1;
  }
}
