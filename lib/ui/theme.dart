import 'dart:ui';

import 'package:flutter/material.dart';

import '../game/hex.dart';

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
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

/// Draws one glossy gem cell. [size] is the hex circumradius.
void drawGem(Canvas canvas, Offset c, double size, Color color,
    {double opacity = 1}) {
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
  final face = hexPath(c.translate(0, -size * 0.04), size * 0.7, roundness: 0.2);
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
        height: size * 0.2),
    Paint()..color = Colors.white.withValues(alpha: 0.45 * opacity),
  );

  canvas.drawPath(
    outer,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math_max(1, size * 0.06)
      ..color = _shade(color, -0.3).withValues(alpha: 0.9 * opacity),
  );
}

double math_max(double a, double b) => a > b ? a : b;

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
      final a = (60 * i - 90) * 3.141592653589793 / 180;
      final p = r.center + Offset(size * cos(a), size * sin(a));
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

double cos(double a) => _cos(a);
double sin(double a) => _sin(a);
double _cos(double a) => _math.cos(a);
double _sin(double a) => _math.sin(a);

// ignore: library_prefixes
class _math {
  static double cos(double a) => _Trig.cos(a);
  static double sin(double a) => _Trig.sin(a);
}

class _Trig {
  static double cos(double a) => _dartMathCos(a);
  static double sin(double a) => _dartMathSin(a);
}

double _dartMathCos(double a) => mathCos(a);
double _dartMathSin(double a) => mathSin(a);
