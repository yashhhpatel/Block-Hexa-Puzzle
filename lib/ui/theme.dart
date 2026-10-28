import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/hex.dart';
import '../meta/cosmetics.dart';

class AppColors {
  static const bgTop = Color(0xFF14286B);
  static const bgMid = Color(0xFF0C1C4D);
  static const bgBottom = Color(0xFF060E2B);
  static const boardCell = Color(0xFF071233);
  static const boardLine = Color(0xFF5EC8FF);
  static const tray = Color(0xFF081638);
  static const accent = Color(0xFFFF4F8B);
  static const accentDark = Color(0xFFC21E5B);
  static const button = Color(0xFF35C7E0);
  static const buttonDark = Color(0xFF137F9A);
  static const gold = Color(0xFFFFC52E);
  static const text = Color(0xFFEAF6FF);
}

/// Block colours, indexed by Piece.colorIndex.
const List<Color> kBlockColors = [
  Color(0xFFFF4D8D), // pink
  Color(0xFFFF8A2B), // orange
  Color(0xFFFFC93A), // yellow
  Color(0xFF8BE04A), // lime
  Color(0xFF3FE0A8), // mint
  Color(0xFF3EC9F5), // cyan
  Color(0xFF3A7BFF), // blue
  Color(0xFF8E5CFF), // violet
  Color(0xFFC060F0), // purple
  Color(0xFFB8774A), // copper
  Color(0xFFFF5A4E), // red
  Color(0xFF26B8B0), // teal
  Color(0xFFF070C8), // magenta
  Color(0xFFD9E25A), // olive-lemon
];

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// Draws one block cell in the chosen skin. [size] is the hex circumradius.
void drawBlock(
  Canvas canvas,
  Offset c,
  double size,
  Color color,
  SkinStyle style, {
  double opacity = 1,
}) {
  switch (style) {
    case SkinStyle.gem:
      drawGem(canvas, c, size, color, opacity: opacity);
    case SkinStyle.flat:
      _drawFlat(canvas, c, size, color, opacity);
    case SkinStyle.candy:
      _drawCandy(canvas, c, size, color, opacity);
    case SkinStyle.neon:
      _drawNeon(canvas, c, size, color, opacity);
    case SkinStyle.crystal:
      _drawCrystal(canvas, c, size, color, opacity);
  }
}

void _drawFlat(Canvas canvas, Offset c, double size, Color color, double o) {
  canvas.drawPath(
    hexPath(c, size * 0.93, roundness: 0.22),
    Paint()..color = _shade(color, -0.12).withValues(alpha: o),
  );
  canvas.drawPath(
    hexPath(c.translate(0, -size * 0.05), size * 0.84, roundness: 0.22),
    Paint()..color = color.withValues(alpha: o),
  );
  canvas.drawPath(
    hexPath(c.translate(0, -size * 0.05), size * 0.6, roundness: 0.22),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.06
      ..color = Colors.white.withValues(alpha: 0.22 * o),
  );
}

void _drawCandy(Canvas canvas, Offset c, double size, Color color, double o) {
  final body = hexPath(c, size * 0.94, roundness: 0.38);
  canvas.drawPath(
    body,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.45),
        radius: 1.0,
        colors: [
          _shade(color, 0.32).withValues(alpha: o),
          color.withValues(alpha: o),
          _shade(color, -0.2).withValues(alpha: o),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: c, radius: size)),
  );
  // Candy stripe and wet highlight.
  canvas.save();
  canvas.clipPath(body);
  final stripe = Paint()
    ..color = Colors.white.withValues(alpha: 0.18 * o)
    ..strokeWidth = size * 0.22;
  canvas.drawLine(
    c.translate(-size, size * 0.2),
    c.translate(size * 0.2, -size),
    stripe,
  );
  canvas.restore();
  canvas.drawArc(
    Rect.fromCircle(center: c, radius: size * 0.62),
    math.pi * 1.1,
    math.pi * 0.55,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size * 0.12
      ..color = Colors.white.withValues(alpha: 0.7 * o),
  );
}

void _drawNeon(Canvas canvas, Offset c, double size, Color color, double o) {
  final path = hexPath(c, size * 0.86, roundness: 0.2);
  canvas.drawPath(
    path,
    Paint()
      ..color = Color.lerp(
        Colors.black,
        color,
        0.18,
      )!.withValues(alpha: 0.9 * o),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.2
      ..color = color.withValues(alpha: 0.55 * o)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.14),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.08
      ..color = _shade(color, 0.25).withValues(alpha: o),
  );
  canvas.drawPath(
    hexPath(c, size * 0.4, roundness: 0.3),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.05
      ..color = color.withValues(alpha: 0.6 * o),
  );
}

void _drawCrystal(Canvas canvas, Offset c, double size, Color color, double o) {
  final pts = hexCorners(c, size * 0.93);
  final inner = hexCorners(
    c.translate(-size * 0.06, -size * 0.08),
    size * 0.42,
  );
  const shades = [0.05, -0.12, -0.24, -0.08, 0.22, 0.3];
  for (var i = 0; i < 6; i++) {
    final j = (i + 1) % 6;
    final facet = Path()
      ..moveTo(pts[i].dx, pts[i].dy)
      ..lineTo(pts[j].dx, pts[j].dy)
      ..lineTo(inner[j].dx, inner[j].dy)
      ..lineTo(inner[i].dx, inner[i].dy)
      ..close();
    canvas.drawPath(
      facet,
      Paint()..color = _shade(color, shades[i]).withValues(alpha: o),
    );
  }
  final table = Path()..addPolygon(inner, true);
  canvas.drawPath(
    table,
    Paint()..color = _shade(color, 0.14).withValues(alpha: o),
  );
  canvas.drawPath(
    Path()..addPolygon(pts, true),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.05
      ..color = Colors.white.withValues(alpha: 0.55 * o),
  );
  canvas.drawCircle(
    inner[4].translate(size * 0.05, size * 0.05),
    size * 0.07,
    Paint()..color = Colors.white.withValues(alpha: 0.85 * o),
  );
}

/// Draws one glossy gem cell. [size] is the hex circumradius.
void drawGem(
  Canvas canvas,
  Offset c,
  double size,
  Color color, {
  double opacity = 1,
}) {
  final outer = hexPath(c, size * 0.95, roundness: 0.18);
  final top = c.translate(0, -size);
  final bottom = c.translate(0, size);

  canvas.drawPath(
    outer,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _shade(color, 0.18).withValues(alpha: opacity),
          color.withValues(alpha: opacity),
          _shade(color, -0.22).withValues(alpha: opacity),
        ],
      ).createShader(Rect.fromPoints(top, bottom)),
  );

  // Raised inner face.
  final face = hexPath(
    c.translate(0, -size * 0.04),
    size * 0.7,
    roundness: 0.2,
  );
  canvas.drawPath(
    face,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _shade(color, 0.12).withValues(alpha: opacity),
          _shade(color, -0.04).withValues(alpha: opacity),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: size)),
  );

  // Specular glint.
  canvas.drawOval(
    Rect.fromCenter(
      center: c.translate(-size * 0.22, -size * 0.42),
      width: size * 0.62,
      height: size * 0.2,
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.45 * opacity),
  );

  canvas.drawPath(
    outer,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size * 0.06)
      ..color = _shade(color, -0.3).withValues(alpha: 0.9 * opacity),
  );
}

/// Rounded hex button shape used for the Play button and level tiles.
class HexBorder extends ShapeBorder {
  const HexBorder();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  Path _path(Rect r) {
    final size = r.shortestSide / 2;
    // Pointy-top for buttons reads better as a "badge".
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = (60 * i - 90) * math.pi / 180;
      final p = r.center + Offset(size * math.cos(a), size * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
  @override
  ShapeBorder scale(double t) => this;
}
