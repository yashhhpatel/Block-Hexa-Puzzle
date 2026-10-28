import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/hex.dart';
import '../l10n/l10n.dart';
import '../meta/cosmetics.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'theme.dart';
import 'widgets.dart';

/// Six illustrated, swipeable steps explaining the game.
class HowToPlayScreen extends StatefulWidget {
  final Services services;
  const HowToPlayScreen({super.key, required this.services});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen>
    with SingleTickerProviderStateMixin {
  static const _steps = 6;
  static const _icons = [
    Icons.pan_tool_alt_rounded,
    Icons.hexagon_rounded,
    Icons.undo_rounded,
    Icons.star_rounded,
    Icons.lightbulb_rounded,
    Icons.local_fire_department_rounded,
  ];
  static const _colors = [
    Color(0xFF3EC9F5),
    Color(0xFF8BE04A),
    Color(0xFF8E5CFF),
    AppColors.gold,
    Color(0xFFFF8A2B),
    Color(0xFFFF4D8D),
  ];

  final _pages = PageController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
        ..repeat();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _next() {
    widget.services.sfx.play(Sound.button);
    if (_page == _steps - 1) {
      Navigator.pop(context);
    } else {
      _pages.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.services.progress;
    final last = _page == _steps - 1;
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                RoundButton(
                  icon: Icons.arrow_back_rounded,
                  size: 44,
                  semanticLabel: tr('back'),
                  onTap: () {
                    widget.services.sfx.play(Sound.button);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: OutlinedTitle(tr('how_to_play'), size: 28),
                  ),
                ),
                if (!last)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('htp_skip'),
                        style: const TextStyle(
                            color: Colors.white70, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _steps,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _StepCard(
                  index: i,
                  icon: _icons[i],
                  color: _colors[i],
                  title: tr('htp_${i + 1}_title'),
                  body: tr('htp_${i + 1}_body'),
                  anim: _anim,
                  skin: p.skin.style,
                  theme: p.theme,
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _steps; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: i == _page ? _colors[_page] : Colors.white24,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
              child: PillButton(
                label: last ? tr('htp_start') : tr('next'),
                icon: last ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
                width: 240,
                onTap: _next,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Animation<double> anim;
  final SkinStyle skin;
  final BoardTheme theme;

  const _StepCard({
    required this.index,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.anim,
    required this.skin,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
        ),
        child: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AnimatedBuilder(
                animation: anim,
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _StepPainter(index, anim.value, skin, theme),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: ShapeDecoration(shape: const HexBorder(), color: color),
                  child: Icon(icon, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 10),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Little looping animation for each step, drawn with the real block skin.
class _StepPainter extends CustomPainter {
  final int step;
  final double t; // 0..1, looping
  final SkinStyle skin;
  final BoardTheme theme;
  _StepPainter(this.step, this.t, this.skin, this.theme);

  static const _flower = [
    Hex(0, 0), Hex(1, 0), Hex(1, -1), Hex(0, -1), Hex(-1, 0), Hex(-1, 1), Hex(0, 1),
  ];

  double _ease(double x) => Curves.easeInOutCubic.transform(x.clamp(0.0, 1.0));

  void _board(Canvas c, Offset o, double s, Iterable<Hex> cells) {
    for (final h in cells) {
      final p = hexPath(o + h.toPixel(s), s, roundness: 0.1);
      c.drawPath(p, Paint()..color = theme.cell);
      c.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, s * 0.06)
            ..color = theme.line.withValues(alpha: 0.85));
    }
  }

  void _blocks(Canvas c, Offset o, double s, List<Hex> cells, Color color) {
    for (final h in cells) {
      drawBlock(c, o + h.toPixel(s), s, color, skin);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 9;
    final mid = size.center(Offset.zero);
    final boardO = mid.translate(0, -s * 0.8);
    switch (step) {
      case 0: // drag a block from the tray onto the board
        _board(canvas, boardO, s, _flower);
        _blocks(canvas, boardO, s, const [Hex(-1, 0), Hex(-1, 1), Hex(0, 1)], kBlockColors[5]);
        const piece = [Hex(0, 0), Hex(1, -1), Hex(1, 0)];
        final from = mid.translate(s * 2.6, s * 3.2);
        final to = boardO;
        final k = _ease(t / 0.7);
        final scale = s * (0.6 + 0.4 * k);
        final at = Offset.lerp(from, to, k)!;
        _blocks(canvas, at, scale, piece, kBlockColors[0]);
        _finger(canvas, at.translate(s * 0.6, s * 1.6), s);
      case 1: // the board fills cell by cell
        _board(canvas, boardO, s, _flower);
        final colors = [kBlockColors[2], kBlockColors[3], kBlockColors[7]];
        const groups = [
          [Hex(0, -1), Hex(1, -1)],
          [Hex(-1, 0), Hex(0, 0), Hex(-1, 1)],
          [Hex(1, 0), Hex(0, 1)],
        ];
        for (var g = 0; g < groups.length; g++) {
          final k = _ease((t * 1.3 - g * 0.25) / 0.2);
          if (k <= 0) continue;
          _blocks(canvas, boardO, s * (0.7 + 0.3 * k), groups[g], colors[g]);
        }
        if (t > 0.85) _sparkle(canvas, boardO, s, (t - 0.85) / 0.15);
      case 2: // a placed block slides back to the tray
        _board(canvas, boardO, s, _flower);
        _blocks(canvas, boardO, s, const [Hex(0, -1), Hex(1, -1), Hex(1, 0)], kBlockColors[6]);
        final k = _ease(math.sin(t * math.pi));
        final at = Offset.lerp(boardO, mid.translate(-s * 2.4, s * 3.0), k)!;
        _blocks(canvas, at, s * (1 - 0.35 * k), const [Hex(-1, 0), Hex(-1, 1), Hex(0, 1)],
            kBlockColors[8]);
        _icon(canvas, Icons.undo_rounded, mid.translate(s * 2.8, s * 3.0), s * 1.3);
      case 3: // three stars pop in
        for (var i = 0; i < 3; i++) {
          final k = _ease((t * 1.4 - i * 0.22) / 0.25);
          final x = (i - 1) * s * 2.6;
          final y = i == 1 ? -s * 0.9 : 0.0;
          _icon(canvas, Icons.star_rounded, mid.translate(x, y), s * (1.6 + 1.0 * k),
              color: Color.lerp(Colors.white24, AppColors.gold, k)!);
        }
        _icon(canvas, Icons.timer_rounded, mid.translate(-s * 1.6, s * 2.8), s * 1.1,
            color: Colors.white70);
        _icon(canvas, Icons.lightbulb_outline_rounded, mid.translate(s * 1.6, s * 2.8), s * 1.1,
            color: Colors.white70);
      case 4: // a spare block that isn't needed
        _board(canvas, boardO, s, _flower);
        _blocks(canvas, boardO, s, const [Hex(0, -1), Hex(1, -1), Hex(0, 0)], kBlockColors[1]);
        _blocks(canvas, boardO, s, const [Hex(-1, 0), Hex(-1, 1)], kBlockColors[4]);
        _blocks(canvas, boardO, s, const [Hex(1, 0), Hex(0, 1)], kBlockColors[9]);
        final spare = mid.translate(0, s * 3.4);
        final wobble = math.sin(t * math.pi * 4) * 0.08;
        canvas.save();
        canvas.translate(spare.dx, spare.dy);
        canvas.rotate(wobble);
        _blocks(canvas, Offset.zero, s * 0.7, const [Hex(0, 0), Hex(1, 0), Hex(2, -1)],
            kBlockColors[10].withValues(alpha: 0.6));
        canvas.restore();
        _icon(canvas, Icons.close_rounded, spare.translate(s * 0.9, -s * 0.3), s * 1.3,
            color: const Color(0xFFFF5A4E));
      default: // daily streak flame and calendar
        final pulse = 1 + 0.08 * math.sin(t * math.pi * 2);
        canvas.drawCircle(
            mid.translate(0, -s * 0.6),
            s * 2.3 * pulse,
            Paint()
              ..shader = const RadialGradient(colors: [Color(0xFFFFC14D), Color(0xFFFF6A1F)])
                  .createShader(
                      Rect.fromCircle(center: mid.translate(0, -s * 0.6), radius: s * 2.3)));
        _icon(canvas, Icons.local_fire_department_rounded, mid.translate(0, -s * 0.6),
            s * 2.8 * pulse);
        for (var i = 0; i < 7; i++) {
          final on = i <= (t * 7).floor();
          final c = mid.translate((i - 3) * s * 1.1, s * 3.0);
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 0.9, height: s * 0.9),
                  Radius.circular(s * 0.2)),
              Paint()..color = on ? const Color(0xFFFF8A2B) : Colors.white12);
        }
    }
  }

  void _finger(Canvas c, Offset at, double s) =>
      _icon(c, Icons.touch_app_rounded, at, s * 1.5, color: Colors.white);

  void _sparkle(Canvas c, Offset o, double s, double k) {
    final paint = Paint()..color = Colors.white.withValues(alpha: (1 - k).clamp(0.0, 1.0));
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * s * (2 + 2 * k), s * 0.14, paint);
    }
  }

  void _icon(Canvas c, IconData icon, Offset center, double size,
      {Color color = Colors.white}) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_StepPainter old) =>
      old.t != t || old.step != step || old.skin != skin || old.theme != theme;
}
