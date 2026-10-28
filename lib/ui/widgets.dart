import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/hex.dart';
import '../meta/cosmetics.dart';
import 'theme.dart';

/// Deep-blue gradient with slowly drifting hexagon outlines.
class GameBackground extends StatefulWidget {
  final bool animate;
  final BoardTheme? theme;
  final Widget child;
  const GameBackground(
      {super.key, required this.child, this.animate = true, this.theme});

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(GameBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? Cosmetics.themes.first;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.bgTop, t.bgMid, t.bgBottom],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(painter: _BgPainter(_c.value)),
          ),
        ),
        widget.child,
      ]),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  static final _seeds = List.generate(14, (i) {
    final r = math.Random(i * 31 + 7);
    return (r.nextDouble(), r.nextDouble(), 0.03 + r.nextDouble() * 0.06,
        r.nextDouble() * 2 * math.pi);
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Soft diagonal light beam.
    final beam = Path()
      ..moveTo(size.width * 0.15, 0)
      ..lineTo(size.width * 0.55, 0)
      ..lineTo(size.width, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.85)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..color = const Color(0xFF6FB8FF).withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    for (final (x, y, sz, ph) in _seeds) {
      final dy = (y - t * 0.5) % 1.0;
      final c = Offset(
          size.width * x + math.sin(t * 2 * math.pi + ph) * 12, size.height * dy);
      final s = size.width * sz;
      canvas.drawPath(
        hexPath(c, s, roundness: 0.15),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.12
          ..color = const Color(0xFF7FC6FF).withValues(alpha: 0.07),
      );
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

/// Circular glossy icon button used in the bottom bar.
class RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final Color dark;
  final Widget? badge;
  final String? semanticLabel;

  const RoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 52,
    this.color = AppColors.button,
    this.dark = AppColors.buttonDark,
    this.badge,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size + 8,
          height: size + 8,
          child: Stack(clipBehavior: Clip.none, children: [
            Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(color, Colors.white, 0.35)!, color, dark],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(0, 3),
                        blurRadius: 4),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: size * 0.52),
              ),
            ),
            if (badge != null) Positioned(right: -4, bottom: -2, child: badge!),
          ]),
        ),
      ),
    );
  }
}

class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF0A0), AppColors.gold, Color(0xFFD48A00)],
        ),
        border: Border.all(color: const Color(0xFFB06A00), width: 1.2),
      ),
      child: Icon(Icons.hexagon, size: size * 0.55, color: const Color(0xFFE59A00)),
    );
  }
}

class CoinPill extends StatelessWidget {
  final int coins;
  const CoinPill({super.key, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 14, 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const CoinIcon(),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Text('$coins',
              key: ValueKey(coins),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
        ),
      ]),
    );
  }
}

/// Rounded pill button with a glossy gradient.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color dark;
  final IconData? icon;
  final double width;

  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.accent,
    this.dark = AppColors.accentDark,
    this.icon,
    this.width = 150,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.3)!, color, dark],
          ),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                offset: const Offset(0, 3),
                blurRadius: 5),
          ],
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }
}

/// Bold italic title text with a dark outline, used for headings.
class OutlinedTitle extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  const OutlinedTitle(this.text,
      {super.key, this.size = 30, this.color = AppColors.text});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontSize: size, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic);
    return Stack(children: [
      Text(text,
          style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.14
                ..color = const Color(0xFF0A1A44))),
      Text(text, style: style.copyWith(color: color)),
    ]);
  }
}

/// Three stars, [earned] of them lit.
class StarRow extends StatelessWidget {
  final int earned;
  final double size;
  const StarRow({super.key, required this.earned, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 3; i++)
        Icon(Icons.star_rounded,
            size: size,
            color: i < earned ? AppColors.gold : Colors.white.withValues(alpha: 0.25)),
    ]);
  }
}

/// Red notification dot with an optional count, overlaid on a child.
class NotifyDot extends StatelessWidget {
  final Widget child;
  final int count;
  const NotifyDot({super.key, required this.child, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      child,
      if (count > 0)
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            constraints: const BoxConstraints(minWidth: 20),
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B3B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ),
    ]);
  }
}

/// Small preview of a block skin: a little three-cell cluster.
class SkinPreview extends StatelessWidget {
  final SkinStyle style;
  final double size;
  const SkinPreview({super.key, required this.style, this.size = 64});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SkinPreviewPainter(style));
}

class _SkinPreviewPainter extends CustomPainter {
  final SkinStyle style;
  _SkinPreviewPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width * 0.2;
    final c = size.center(Offset.zero);
    const cells = [Hex(0, 0), Hex(1, 0), Hex(0, 1)];
    final colors = [kBlockColors[0], kBlockColors[5], kBlockColors[2]];
    var centroid = Offset.zero;
    for (final h in cells) {
      centroid += h.toPixel(s);
    }
    centroid = centroid / cells.length.toDouble();
    for (var i = 0; i < cells.length; i++) {
      drawBlock(canvas, c + cells[i].toPixel(s) - centroid, s, colors[i], style);
    }
  }

  @override
  bool shouldRepaint(_SkinPreviewPainter old) => old.style != style;
}
