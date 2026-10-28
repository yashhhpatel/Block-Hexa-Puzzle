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
  const GameBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.theme,
  });

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  // Off when the setting or the system asks for less motion.
  bool get _moving =>
      widget.animate && !MediaQuery.of(context).disableAnimations;

  void _sync() {
    if (_moving && !_c.isAnimating) _c.repeat();
    if (!_moving) _c.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GameBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) =>
                  CustomPaint(painter: _BgPainter(_c.value, t.flare)),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t; // 0..1 over the 40 s loop
  final Color tint;
  _BgPainter(this.t, this.tint);

  // (x, y, size, phase) per hexagon. The far layer is small, faint and slow,
  // the near layer larger, brighter and faster, which reads as depth.
  static List<(double, double, double, double)> _layer(
    int n,
    int seed,
    double minS,
    double maxS,
  ) => List.generate(n, (i) {
    final r = math.Random(seed + i * 31);
    return (
      r.nextDouble(),
      r.nextDouble(),
      minS + r.nextDouble() * (maxS - minS),
      r.nextDouble() * 2 * math.pi,
    );
  });

  static final _far = _layer(16, 7, 0.02, 0.045);
  static final _near = _layer(8, 91, 0.06, 0.11);

  // Soft light flares that slowly fade in and out at fixed spots.
  static final _flares = List.generate(4, (i) {
    final r = math.Random(400 + i);
    return (r.nextDouble(), r.nextDouble() * 0.8, r.nextDouble());
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

    for (final (x, y, ph) in _flares) {
      // Each flare breathes on its own schedule within the loop.
      final a = math.pow(math.sin((t * 3 + ph) * math.pi), 2).toDouble();
      if (a < 0.02) continue;
      final c = Offset(size.width * x, size.height * y);
      final r = size.width * 0.35;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              tint.withValues(alpha: 0.10 * a),
              tint.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    _drawLayer(
      canvas,
      size,
      _far,
      speed: 0.5,
      sway: 8,
      alpha: 0.05,
      stroke: 0.10,
    );
    _drawLayer(
      canvas,
      size,
      _near,
      speed: 1.0,
      sway: 16,
      alpha: 0.08,
      stroke: 0.08,
    );
  }

  void _drawLayer(
    Canvas canvas,
    Size size,
    List<(double, double, double, double)> hexes, {
    required double speed,
    required double sway,
    required double alpha,
    required double stroke,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = tint.withValues(alpha: alpha);
    for (final (x, y, sz, ph) in hexes) {
      final dy = (y - t * speed) % 1.0;
      final c = Offset(
        size.width * x + math.sin(t * 2 * math.pi + ph) * sway,
        size.height * (dy * 1.2 - 0.1),
      );
      final s = size.width * sz;
      canvas.drawPath(
        hexPath(c, s, roundness: 0.15),
        paint..strokeWidth = s * stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t || old.tint != tint;
}

/// Squashes its child slightly while pressed and springs back on release.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.9,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: Duration(milliseconds: _down ? 70 : 280),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// A number that counts to its new value instead of jumping.
class CountUpText extends StatefulWidget {
  final int value;
  final TextStyle style;
  const CountUpText(this.value, {super.key, required this.style});

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> {
  late int _from = widget.value;

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.value),
      tween: Tween(begin: _from.toDouble(), end: widget.value.toDouble()),
      duration: Duration(milliseconds: _from == widget.value ? 0 : 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('${v.round()}', style: widget.style),
    );
  }
}

/// A bright band that sweeps across [child] every few seconds, clipped to
/// a hexagon. Used on the Play button.
class HexShimmer extends StatefulWidget {
  final Widget child;
  const HexShimmer({super.key, required this.child});

  @override
  State<HexShimmer> createState() => _HexShimmerState();
}

class _HexShimmerState extends State<HexShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipPath(
              clipper: const ShapeBorderClipper(shape: HexBorder()),
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) {
                  // Sweep during the first 35% of the loop, then rest.
                  final k = (_c.value / 0.35).clamp(0.0, 1.0);
                  if (k >= 1) return const SizedBox.shrink();
                  return FractionalTranslation(
                    translation: Offset(-1.2 + 2.4 * k, 0),
                    child: Transform.rotate(
                      angle: 0.4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.38),
                              Colors.white.withValues(alpha: 0),
                            ],
                            stops: const [0.3, 0.5, 0.7],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
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
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: size + 8,
          height: size + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(color, Colors.white, 0.35)!,
                        color,
                        dark,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(0, 3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: size * 0.52),
                ),
              ),
              if (badge != null)
                Positioned(right: -4, bottom: -2, child: badge!),
            ],
          ),
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
      child: Icon(
        Icons.hexagon,
        size: size * 0.55,
        color: const Color(0xFFE59A00),
      ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(),
          const SizedBox(width: 10),
          CountUpText(
            coins,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ],
      ),
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
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
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
              blurRadius: 5,
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        // Labels vary a lot by language: shrink rather than overflow.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: kDisplayStyle.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bold italic title text with a dark outline, used for headings.
class OutlinedTitle extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  const OutlinedTitle(
    this.text, {
    super.key,
    this.size = 30,
    this.color = AppColors.text,
  });

  @override
  Widget build(BuildContext context) {
    final style = kDisplayStyle.copyWith(fontSize: size);
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.14
              ..color = const Color(0xFF0A1A44),
          ),
        ),
        Text(text, style: style.copyWith(color: color)),
      ],
    );
  }
}

/// Three stars, [earned] of them lit.
class StarRow extends StatelessWidget {
  final int earned;
  final double size;
  const StarRow({super.key, required this.earned, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            Icons.star_rounded,
            size: size,
            color: i < earned
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.25),
          ),
      ],
    );
  }
}

/// Red notification dot with an optional count, overlaid on a child.
class NotifyDot extends StatelessWidget {
  final Widget child;
  final int count;
  const NotifyDot({super.key, required this.child, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
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
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Small preview of a block skin: a little three-cell cluster. With
/// [animate] the cells bob gently and a shine glides over them.
class SkinPreview extends StatefulWidget {
  final SkinStyle style;
  final double size;
  final bool animate;
  const SkinPreview({
    super.key,
    required this.style,
    this.size = 64,
    this.animate = false,
  });

  @override
  State<SkinPreview> createState() => _SkinPreviewState();
}

class _SkinPreviewState extends State<SkinPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _SkinPreviewPainter(
            widget.style,
            widget.animate ? _c.value : -1,
          ),
        ),
      ),
    );
  }
}

class _SkinPreviewPainter extends CustomPainter {
  final SkinStyle style;
  final double t; // <0 = still
  _SkinPreviewPainter(this.style, this.t);

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
    final clip = Path();
    for (var i = 0; i < cells.length; i++) {
      final bob = t < 0 ? 0.0 : math.sin((t + i / 3) * 2 * math.pi) * s * 0.08;
      final p = c + cells[i].toPixel(s) - centroid + Offset(0, bob);
      drawBlock(canvas, p, s, colors[i], style);
      clip.addPath(hexPath(p, s * 0.95), Offset.zero);
    }
    if (t >= 0 && t < 0.4) {
      // Diagonal shine gliding over the cluster.
      final x = -size.width * 0.3 + size.width * 1.6 * (t / 0.4);
      final band = Path()
        ..moveTo(x, 0)
        ..lineTo(x + size.width * 0.18, 0)
        ..lineTo(x - size.width * 0.22, size.height)
        ..lineTo(x - size.width * 0.4, size.height)
        ..close();
      canvas.save();
      canvas.clipPath(clip);
      canvas.drawPath(
        band,
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SkinPreviewPainter old) =>
      old.style != style || old.t != t;
}
