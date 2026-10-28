import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_state.dart';
import '../game/hex.dart';
import '../game/level.dart';
import '../meta/cosmetics.dart';
import 'theme.dart';

/// Where everything sits for a given play-area size.
class BoardLayout {
  final Size size;
  final Rect boardRect;
  final Rect trayRect;
  final double cell; // board hex circumradius
  final Offset boardOrigin; // pixel of board Hex(0,0)
  final double trayCell;
  final List<Offset> traySlots; // centre of each piece's tray bounding box

  /// Tray page of each piece. Busy levels whose blocks would get too small
  /// to grab are split over several pages instead of shrinking further.
  final List<int> pageOf;
  final int pageCount;

  BoardLayout._(
    this.size,
    this.boardRect,
    this.trayRect,
    this.cell,
    this.boardOrigin,
    this.trayCell,
    this.traySlots,
    this.pageOf,
    this.pageCount,
  );

  /// Smallest comfortable tray block (hex radius) before paging kicks in.
  static double minTrayCell(Size size) => size.width / 34;

  factory BoardLayout.compute(Size size, Level level) {
    // Busy levels (Insane and beyond have up to ~22 blocks) get a taller
    // tray so their blocks stay big enough to see and grab.
    final n = level.pieces.length;
    final trayH = size.height * (n <= 14 ? 0.34 : (n <= 18 ? 0.38 : 0.42));
    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height - trayH);
    final trayRect = Rect.fromLTWH(0, size.height - trayH, size.width, trayH);

    // Board: fit the outline, but cap cell size so tiny boards don't balloon.
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final h in level.board) {
      final p = h.toPixel(1);
      minX = math.min(minX, p.dx - 1);
      maxX = math.max(maxX, p.dx + 1);
      minY = math.min(minY, p.dy - 0.866);
      maxY = math.max(maxY, p.dy + 0.866);
    }
    final bw = maxX - minX, bh = maxY - minY;
    final cell = math.min(
      math.min(boardRect.width * 0.92 / bw, boardRect.height * 0.86 / bh),
      size.width / 8.5,
    );
    final boardCenter = boardRect.center.translate(0, boardRect.height * 0.02);
    final boardOrigin =
        boardCenter -
        Offset((minX + maxX) / 2 * cell, (minY + maxY) / 2 * cell);

    // Tray: pack piece bounding boxes into centred rows, shrinking to fit.
    final all = List.generate(n, (i) => i);
    var trayCell = math.min(cell * 0.62, size.width / 16);
    late List<Offset> slots;
    for (var i = 0; i < 30; i++) {
      final packed = _pack(level.pieces, all, trayCell, trayRect.deflate(10));
      if (packed != null) {
        slots = packed;
        break;
      }
      trayCell *= 0.92;
      if (i == 29) {
        slots = _pack(level.pieces, all, trayCell, trayRect, force: true)!;
      }
    }

    // Too many blocks to show at a grabbable size: use pages instead.
    final pageOf = List<int>.filled(n, 0);
    var pageCount = 1;
    final minTray = minTrayCell(size);
    if (trayCell < minTray && n > 1) {
      trayCell = minTray * 1.15;
      // Room at the sides for the page arrows and below for the dots.
      final area = Rect.fromLTRB(
        trayRect.left + 44,
        trayRect.top + 8,
        trayRect.right - 44,
        trayRect.bottom - 24,
      );
      final pages = <List<int>>[[]];
      for (var i = 0; i < n; i++) {
        final trial = [...pages.last, i];
        if (pages.last.isNotEmpty &&
            _pack(level.pieces, trial, trayCell, area) == null) {
          pages.add([i]);
        } else {
          pages.last.add(i);
        }
      }
      slots = List.filled(n, Offset.zero);
      for (var pg = 0; pg < pages.length; pg++) {
        final packed = _pack(
          level.pieces,
          pages[pg],
          trayCell,
          area,
          force: true,
        )!;
        for (var k = 0; k < pages[pg].length; k++) {
          slots[pages[pg][k]] = packed[k];
          pageOf[pages[pg][k]] = pg;
        }
      }
      pageCount = pages.length;
    }
    return BoardLayout._(
      size,
      boardRect,
      trayRect,
      cell,
      boardOrigin,
      trayCell,
      slots,
      pageOf,
      pageCount,
    );
  }

  /// Packs the pieces listed in [ids] into centred rows. The result is
  /// aligned with [ids]; null if they don't fit (unless [force]).
  static List<Offset>? _pack(
    List<Piece> pieces,
    List<int> ids,
    double s,
    Rect area, {
    bool force = false,
  }) {
    final gap = s * (pieces.length > 14 ? 0.6 : 0.9);
    final rows = <List<int>>[[]];
    final rowW = <double>[0];
    final rowH = <double>[0];
    for (var k = 0; k < ids.length; k++) {
      final i = ids[k];
      final b = pieces[i].unitBounds;
      final w = b.width * s, h = b.height * s;
      if (rows.last.isNotEmpty && rowW.last + gap + w > area.width) {
        rows.add([]);
        rowW.add(0);
        rowH.add(0);
      }
      rowW[rowW.length - 1] += (rows.last.isEmpty ? 0 : gap) + w;
      rowH[rowH.length - 1] = math.max(rowH.last, h);
      rows.last.add(k);
    }
    final totalH =
        rowH.fold<double>(0, (a, b) => a + b) + gap * 0.6 * (rows.length - 1);
    if (!force && (totalH > area.height || rowW.any((w) => w > area.width))) {
      return null;
    }
    final slots = List<Offset>.filled(ids.length, Offset.zero);
    var y = area.center.dy - totalH / 2;
    for (var r = 0; r < rows.length; r++) {
      var x = area.center.dx - rowW[r] / 2;
      for (final k in rows[r]) {
        final b = pieces[ids[k]].unitBounds;
        final w = b.width * s;
        slots[k] = Offset(x + w / 2, y + rowH[r] / 2);
        x += w + gap;
      }
      y += rowH[r] + gap * 0.6;
    }
    return slots;
  }

  /// Centroid position of [piece] when resting in the tray, while tray
  /// [page] is showing (pieces of other pages sit off to the side).
  Offset trayCentroid(Level level, int piece, {int page = 0}) {
    final p = level.pieces[piece];
    final b = p.unitBounds;
    return traySlots[piece] -
        b.center * trayCell +
        p.unitCentroid * trayCell +
        Offset((pageOf[piece] - page) * size.width, 0);
  }

  /// Centroid position of [piece] when placed at [anchor].
  Offset boardCentroid(Level level, int piece, Hex anchor) =>
      boardOrigin +
      anchor.toPixel(cell) +
      level.pieces[piece].unitCentroid * cell;
}

class _Visual {
  Offset center;
  double scale;
  _Visual(this.center, this.scale);
}

/// A short-lived spark thrown off when a block lands.
class _Spark {
  Offset pos;
  Offset vel;
  final Color color;
  final double size;
  double life = 1; // 1 -> 0
  _Spark(this.pos, this.vel, this.color, this.size);
}

/// The playfield: board, tray and the block being dragged.
class BoardView extends StatefulWidget {
  final GameState game;
  final SkinStyle skin;
  final BoardTheme theme;
  final VoidCallback onPick;
  final VoidCallback onPlace;
  final VoidCallback onFail;

  /// Shows an animated hand dragging the first block (level 1).
  final bool tutorial;

  /// Colour-blind mode: a small symbol on each block colour.
  final bool patterns;

  const BoardView({
    super.key,
    required this.game,
    required this.skin,
    required this.theme,
    required this.onPick,
    required this.onPlace,
    required this.onFail,
    this.tutorial = false,
    this.patterns = false,
  });

  @override
  State<BoardView> createState() => BoardViewState();
}

class BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  BoardLayout? _layout;
  final List<_Visual?> _visuals = [];
  final List<_Spark> _sparks = [];
  final _rng = math.Random();

  int? _drag;
  Offset _dragGrab = Offset.zero; // centroid minus finger
  Offset _finger = Offset.zero;
  Hex? _preview;
  Duration _last = Duration.zero;
  double _time = 0;

  /// 0..1 progress of the celebration wave once the board is completed.
  double _winT = 0;

  /// 0..1 level-start animation: cells pop in, then the tray fills.
  double _intro = 1;
  bool _celebrating = false;

  /// Tray page on show (busy levels only).
  int _page = 0;

  /// Landing bounce progress (0..1) per freshly placed block.
  final Map<int, double> _land = {};

  /// System or in-game "reduce motion": no sparks, bounces or waves.
  bool _calm = false;

  /// Tutorial hand loop time, -1 when hidden.
  bool get _showTutorial =>
      widget.tutorial &&
      _intro >= 1 &&
      _drag == null &&
      !game.isComplete &&
      game.placements.every((p) => p == null);

  GameState get game => widget.game;
  Level get level => game.level;

  /// "Almost there" glow on the last few empty cells.
  bool get _almost => !game.isComplete && game.emptyCells <= 4;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    game.addListener(_onGame);
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      oldWidget.game.removeListener(_onGame);
      widget.game.addListener(_onGame);
      _layout = null;
      _visuals.clear();
      _sparks.clear();
      _drag = null;
      _celebrating = false;
      _winT = 0;
      _intro = 1;
      _page = 0;
      _land.clear();
    }
  }

  @override
  void dispose() {
    game.removeListener(_onGame);
    _ticker.dispose();
    super.dispose();
  }

  void _onGame() {
    if (!game.isComplete) {
      _celebrating = false;
      _winT = 0;
    }
    _autoTurnPage();
    if (!_ticker.isActive) _ticker.start();
  }

  /// When every block on the shown tray page is used, show the next page
  /// that still has blocks.
  void _autoTurnPage() {
    final l = _layout;
    if (l == null || l.pageCount < 2 || _drag != null) return;
    bool waiting(int i) => !game.isPlaced(i);
    final here = [
      for (var i = 0; i < level.pieces.length; i++)
        if (l.pageOf[i] == _page && waiting(i)) i,
    ];
    if (here.isNotEmpty) return;
    for (var i = 0; i < level.pieces.length; i++) {
      if (waiting(i)) {
        _page = l.pageOf[i];
        return;
      }
    }
  }

  void _turnPage(int delta) {
    final l = _layout;
    if (l == null) return;
    final next = (_page + delta).clamp(0, l.pageCount - 1);
    if (next == _page) return;
    setState(() => _page = next);
    if (!_ticker.isActive) _ticker.start();
  }

  void celebrate() {
    _celebrating = true;
    _winT = 0;
    // Confetti of sparks from every board cell.
    final l = _layout;
    if (l != null) {
      for (final h in level.board) {
        final occ = game.occupantAt(h);
        final color = occ == null
            ? Colors.white
            : kBlockColors[level.pieces[occ].colorIndex % kBlockColors.length];
        _burst(l.boardOrigin + h.toPixel(l.cell), color, 3, l.cell * 0.6);
      }
    }
    if (!_ticker.isActive) _ticker.start();
  }

  void _burst(Offset at, Color color, int n, double speed) {
    if (_calm) return;
    for (var k = 0; k < n; k++) {
      final a = _rng.nextDouble() * 2 * math.pi;
      final v = speed * (2 + _rng.nextDouble() * 3);
      _sparks.add(
        _Spark(
          at,
          Offset(math.cos(a), math.sin(a)) * v,
          color,
          (_layout?.cell ?? 20) * (0.12 + _rng.nextDouble() * 0.12),
        ),
      );
    }
  }

  Offset _targetCenter(int i) {
    final a = game.placements[i];
    return a == null
        ? _layout!.trayCentroid(level, i, page: _page)
        : _layout!.boardCentroid(level, i, a);
  }

  double _targetScale(int i) =>
      game.placements[i] == null ? _layout!.trayCell : _layout!.cell;

  void _tick(Duration now) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    _time += dt;
    final layout = _layout;
    if (layout == null) return;
    var moving = false;
    for (var i = 0; i < _visuals.length; i++) {
      final v = _visuals[i]!;
      var tc = i == _drag ? _finger + _dragGrab : _targetCenter(i);
      final pv = _preview;
      if (i == _drag && pv != null) {
        // Magnet: near a valid spot the block leans into it.
        final snap = layout.boardCentroid(level, i, pv);
        final d = (snap - tc).distance;
        final r = layout.cell * 1.3;
        if (d < r) tc = Offset.lerp(tc, snap, 0.4 * (1 - d / r))!;
      }
      if (_intro < 1 && i != _drag && !game.isPlaced(i)) {
        tc = tc.translate(0, layout.trayRect.height * (1 - _trayRise));
      }
      final ts = i == _drag ? layout.cell : _targetScale(i);
      final k = 1 - math.exp(-dt * (i == _drag ? 40 : 16));
      v.center = Offset.lerp(v.center, tc, k)!;
      v.scale = v.scale + (ts - v.scale) * k;
      if ((v.center - tc).distance > 0.3 || (v.scale - ts).abs() > 0.01) {
        moving = true;
      } else {
        v.center = tc;
        v.scale = ts;
      }
    }
    for (final s in _sparks) {
      s.pos += s.vel * dt;
      s.vel = s.vel * math.pow(0.04, dt).toDouble() + Offset(0, 300 * dt);
      s.life -= dt / 0.7;
    }
    _sparks.removeWhere((s) => s.life <= 0);
    if (_sparks.isNotEmpty) moving = true;
    if (_celebrating && _winT < 1) {
      _winT = math.min(1, _winT + dt / 1.1);
      moving = true;
    }
    if (_intro < 1) {
      _intro = math.min(1, _intro + dt / 1.0);
      moving = true;
    }
    if (_land.isNotEmpty) {
      _land.updateAll((_, p) => p + dt / 0.32);
      _land.removeWhere((_, p) => p >= 1);
      moving = true;
    }
    if (_almost || _showTutorial) moving = true;
    setState(() {});
    if (!moving && _drag == null) {
      _ticker.stop();
      _last = Duration.zero;
    }
  }

  void _ensureLayout(Size size) {
    if (_layout != null && _layout!.size == size) return;
    _layout = BoardLayout.compute(size, level);
    final fresh = _visuals.isEmpty;
    // Respect the system "remove animations" setting.
    if (fresh && !MediaQuery.of(context).disableAnimations) _intro = 0;
    _visuals
      ..clear()
      ..addAll(
        List.generate(level.pieces.length, (i) {
          final c = _targetCenter(i);
          // On a new level, blocks rise into the tray.
          return _Visual(
            fresh ? c.translate(0, _layout!.trayRect.height) : c,
            _targetScale(i),
          );
        }),
      );
    if (!_ticker.isActive) _ticker.start();
  }

  /// How far the tray blocks have risen (0 = hidden below, 1 = in place).
  double get _trayRise =>
      Curves.easeOutCubic.transform(((_intro - 0.35) / 0.55).clamp(0.0, 1.0));

  // ---- input -------------------------------------------------------------

  int? _hitTest(Offset p) {
    final l = _layout!;
    final h = Hex.fromPixel(p - l.boardOrigin, l.cell);
    final occ = game.occupantAt(h);
    if (occ != null && !game.hinted.contains(occ)) return occ;

    int? best;
    var bestD = l.trayCell * 1.9;
    for (var i = 0; i < level.pieces.length; i++) {
      if (game.isPlaced(i) || l.pageOf[i] != _page) continue;
      final v = _visuals[i]!;
      final origin = v.center - level.pieces[i].unitCentroid * v.scale;
      for (final c in level.pieces[i].cells) {
        final d = (origin + c.toPixel(v.scale) - p).distance;
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
    }
    return best;
  }

  void _onDown(PointerDownEvent e) {
    if (_drag != null || game.isComplete || _layout == null) return;
    final i = _hitTest(e.localPosition);
    if (i == null) return;
    final l = _layout!;
    final v = _visuals[i]!;
    _finger = e.localPosition;
    game.beginMove();
    if (game.isPlaced(i)) {
      _dragGrab = v.center - _finger;
      game.remove(i);
    } else {
      // Scale the grab point up to board size and lift the block above the
      // finger so it stays visible while dragging.
      final rel = (v.center - _finger) * (l.cell / v.scale);
      _dragGrab = rel + Offset(0, -l.cell * 2.2);
    }
    _drag = i;
    _preview = null;
    widget.onPick();
    if (!_ticker.isActive) _ticker.start();
  }

  void _onMove(PointerMoveEvent e) {
    if (_drag == null) return;
    _finger = e.localPosition;
    _preview = _snapAnchor(_drag!, _finger + _dragGrab);
  }

  void _onUp(PointerEvent e) {
    final i = _drag;
    if (i == null) return;
    _drag = null;
    final anchor = _snapAnchor(i, _finger + _dragGrab);
    _preview = null;
    if (anchor != null && game.place(i, anchor)) {
      final l = _layout!;
      final color =
          kBlockColors[level.pieces[i].colorIndex % kBlockColors.length];
      for (final c in level.pieces[i].cellsAt(anchor)) {
        _burst(l.boardOrigin + c.toPixel(l.cell), color, 2, l.cell * 0.35);
      }
      if (!_calm) _land[i] = 0;
      widget.onPlace();
    } else {
      widget.onFail();
      setState(() {});
    }
    game.endMove();
    if (!_ticker.isActive) _ticker.start();
  }

  /// Best fitting anchor near where the dragged block would land.
  Hex? _snapAnchor(int i, Offset centroid) {
    final l = _layout!;
    final piece = level.pieces[i];
    final originPx = centroid - piece.unitCentroid * l.cell;
    final guess = Hex.fromPixel(originPx - l.boardOrigin, l.cell);
    Hex? best;
    var bestD = l.cell * 1.15;
    for (final cand in [guess, ...guess.neighbors]) {
      if (!game.canPlace(i, cand)) continue;
      final d = (l.boardOrigin + cand.toPixel(l.cell) - originPx).distance;
      if (d < bestD) {
        bestD = d;
        best = cand;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    _calm = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureLayout(constraints.biggest);
        final l = _layout!;
        final board = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onUp,
          // Keep rising/returning blocks inside the playfield so they never
          // show through the control bar below it.
          child: ClipRect(
            child: CustomPaint(
              size: constraints.biggest,
              painter: _BoardPainter(
                game: game,
                layout: _layout!,
                visuals: _visuals.cast<_Visual>(),
                sparks: _sparks,
                skin: widget.skin,
                theme: widget.theme,
                drag: _drag,
                preview: _preview,
                winT: _celebrating && !_calm ? _winT : 0,
                intro: _intro,
                almostPulse: !_almost
                    ? -1
                    : (_calm ? 0.5 : (math.sin(_time * 5) + 1) / 2),
                page: _page,
                land: _land,
                patterns: widget.patterns,
                tutorialT: _showTutorial ? (_time / 2.6) % 1.0 : -1,
              ),
            ),
          ),
        );
        if (l.pageCount < 2) return board;
        return Stack(
          children: [
            board,
            Positioned(
              left: 2,
              top: l.trayRect.center.dy - 22,
              child: _PageArrow(
                icon: Icons.chevron_left_rounded,
                enabled: _page > 0,
                onTap: () => _turnPage(-1),
              ),
            ),
            Positioned(
              right: 2,
              top: l.trayRect.center.dy - 22,
              child: _PageArrow(
                icon: Icons.chevron_right_rounded,
                enabled: _page < l.pageCount - 1,
                onTap: () => _turnPage(1),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < l.pageCount; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 16 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? widget.theme.line
                              : Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PageArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.25,
        child: Container(
          width: 38,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final GameState game;
  final BoardLayout layout;
  final List<_Visual> visuals;
  final List<_Spark> sparks;
  final SkinStyle skin;
  final BoardTheme theme;
  final int? drag;
  final Hex? preview;
  final double winT;
  final double intro; // 0..1 level-start pop-in
  final double almostPulse; // <0 = off
  final int page;
  final Map<int, double> land;
  final bool patterns;
  final double tutorialT; // <0 = off

  _BoardPainter({
    required this.game,
    required this.layout,
    required this.visuals,
    required this.sparks,
    required this.skin,
    required this.theme,
    required this.drag,
    required this.preview,
    required this.winT,
    required this.intro,
    required this.almostPulse,
    required this.page,
    required this.land,
    required this.patterns,
    required this.tutorialT,
  });

  Level get level => game.level;

  /// Centre of the board in pixels; the win wave spreads out from here.
  Offset get _boardCenter => layout.boardRect.center;

  @override
  void paint(Canvas canvas, Size size) {
    _paintTray(canvas);
    _paintBoard(canvas);

    // Placed blocks first, then tray blocks, then the dragged one on top.
    final order = <int>[
      for (var i = 0; i < visuals.length; i++)
        if (i != drag && game.isPlaced(i)) i,
      for (var i = 0; i < visuals.length; i++)
        if (i != drag && !game.isPlaced(i)) i,
      ?drag,
    ];
    for (final i in order) {
      _paintPiece(canvas, i, lifted: i == drag);
    }
    for (final s in sparks) {
      canvas.drawPath(
        hexPath(s.pos, s.size * (0.4 + 0.6 * s.life)),
        Paint()..color = s.color.withValues(alpha: s.life.clamp(0.0, 1.0)),
      );
    }
    if (tutorialT >= 0) _paintTutorial(canvas);
  }

  /// A ghost of the first block glides from the tray to its spot on the
  /// board with a hand "dragging" it, on a loop until the player moves one.
  void _paintTutorial(Canvas canvas) {
    var i = -1;
    for (var k = 0; k < level.pieces.length; k++) {
      if (level.solution[k] != null && layout.pageOf[k] == page) {
        i = k;
        break;
      }
    }
    if (i < 0) return;
    final p = level.pieces[i];
    final from = layout.trayCentroid(level, i, page: page);
    final to = layout.boardCentroid(level, i, level.solution[i]!);
    final t = tutorialT;
    final move = Curves.easeInOutCubic.transform(
      ((t - 0.15) / 0.6).clamp(0, 1),
    );
    final fade = t < 0.1 ? t / 0.1 : (t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1.0);
    final centre = Offset.lerp(from, to, move)!;
    final scale = layout.trayCell + (layout.cell - layout.trayCell) * move;
    final origin = centre - p.unitCentroid * scale;
    final color = kBlockColors[p.colorIndex % kBlockColors.length];
    for (final c in p.cells) {
      drawBlock(
        canvas,
        origin + c.toPixel(scale),
        scale,
        color,
        skin,
        opacity: 0.55 * fade,
      );
    }
    final hand = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.touch_app_rounded.codePoint),
        style: TextStyle(
          fontSize: layout.cell * 1.6,
          fontFamily: Icons.touch_app_rounded.fontFamily,
          package: Icons.touch_app_rounded.fontPackage,
          color: Colors.white.withValues(alpha: fade),
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hand.paint(canvas, centre + Offset(-hand.width * 0.3, scale * 0.6));
  }

  void _paintTray(Canvas canvas) {
    final r = layout.trayRect;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.tray.withValues(alpha: 0.55),
            theme.tray.withValues(alpha: 0.85),
          ],
        ).createShader(r),
    );
    // Glowing top rim.
    canvas.drawLine(
      r.topLeft.translate(r.width * 0.06, 0),
      r.topRight.translate(-r.width * 0.06, 0),
      Paint()
        ..color = theme.line.withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Empty silhouettes mark where blocks that left the tray belong.
    final ghost = Paint()..color = Colors.black.withValues(alpha: 0.28);
    for (var i = 0; i < level.pieces.length; i++) {
      if (!game.isPlaced(i) && i != drag) continue;
      final p = level.pieces[i];
      final origin =
          layout.trayCentroid(level, i, page: page) -
          p.unitCentroid * layout.trayCell;
      for (final c in p.cells) {
        canvas.drawPath(
          hexPath(origin + c.toPixel(layout.trayCell), layout.trayCell * 0.92),
          ghost,
        );
      }
    }
  }

  /// Pop-in scale of a board cell at [center] during the level intro: a
  /// ripple from the middle outwards, overshooting slightly.
  double _introScale(Offset center) {
    if (intro >= 1) return 1;
    final d =
        (center - _boardCenter).distance / (layout.boardRect.longestSide * 0.5);
    final local = ((intro * 1.8 - d * 0.9) / 0.45).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(local);
  }

  void _paintBoard(Canvas canvas) {
    final s = layout.cell;
    final fill = Paint()..color = theme.cell.withValues(alpha: 0.85);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.16
      ..color = theme.line.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.12);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.05)
      ..color = theme.line.withValues(alpha: 0.75);

    final outline = Path();
    for (final h in level.board) {
      final center = layout.boardOrigin + h.toPixel(s);
      final k = _introScale(center);
      if (k <= 0) continue;
      outline.addPath(hexPath(center, s * k, roundness: 0.1), Offset.zero);
    }
    canvas.drawPath(outline, glow);
    canvas.drawPath(outline, fill);
    canvas.drawPath(outline, line);

    // Almost there: the last few holes pulse to draw the eye.
    if (almostPulse >= 0) {
      final p = Paint()
        ..color = theme.line.withValues(alpha: 0.12 + 0.18 * almostPulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.2);
      for (final h in level.board) {
        if (game.occupantAt(h) != null) continue;
        canvas.drawPath(hexPath(layout.boardOrigin + h.toPixel(s), s * 0.8), p);
      }
    }

    // Landing preview for the dragged block.
    if (drag != null && preview != null) {
      final p = Paint()..color = Colors.white.withValues(alpha: 0.16);
      for (final c in level.pieces[drag!].cellsAt(preview!)) {
        canvas.drawPath(hexPath(layout.boardOrigin + c.toPixel(s), s * 0.9), p);
      }
    }
  }

  void _paintPiece(Canvas canvas, int i, {required bool lifted}) {
    final p = level.pieces[i];
    final v = visuals[i];
    final color = kBlockColors[p.colorIndex % kBlockColors.length];
    final origin = v.center - p.unitCentroid * v.scale;

    if (lifted) {
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, v.scale * 0.25);
      for (final c in p.cells) {
        canvas.drawPath(
          hexPath(
            origin + c.toPixel(v.scale) + Offset(0, v.scale * 0.35),
            v.scale * 0.9,
          ),
          shadow,
        );
      }
    }
    final maxDist = layout.boardRect.longestSide * 0.6;
    for (final c in p.cells) {
      final center = origin + c.toPixel(v.scale);
      var size = v.scale;
      var flash = 0.0;
      if (intro < 1 && game.isPlaced(i)) {
        size *= _introScale(center);
        if (size <= 0) continue;
      }
      final lp = land[i];
      if (lp != null) {
        // Landing squash-and-bounce: dips, overshoots slightly, settles.
        size *= 1 - 0.13 * math.sin(math.pi * 2 * lp) * (1 - lp);
      }
      if (winT > 0 && game.isPlaced(i)) {
        // A wave ripples out from the middle: each cell pops and flashes.
        final d = (center - _boardCenter).distance / maxDist;
        final local = ((winT * 1.6 - d) / 0.35).clamp(0.0, 1.0);
        final bump = math.sin(local * math.pi);
        size *= 1 + 0.22 * bump;
        flash = 0.6 * bump;
      }
      drawBlock(canvas, center, size, color, skin);
      if (patterns) drawPattern(canvas, center, size, p.colorIndex);
      if (flash > 0) {
        canvas.drawPath(
          hexPath(center, size * 0.95),
          Paint()..color = Colors.white.withValues(alpha: flash),
        );
      }
    }
    if (game.hinted.contains(i)) {
      // Small light marks a hint-placed (locked) block.
      final c = origin + p.cells.first.toPixel(v.scale);
      canvas.drawCircle(
        c,
        v.scale * 0.16,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
