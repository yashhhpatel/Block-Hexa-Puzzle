import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Screen transition used app-wide: the new screen opens through an
/// expanding hexagon while settling from a slight zoom; the screen below
/// dims and recedes a little.
class HexPageTransitionsBuilder extends PageTransitionsBuilder {
  const HexPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Respect the system "remove animations" accessibility setting.
    if (MediaQuery.of(context).disableAnimations) {
      return FadeTransition(opacity: animation, child: child);
    }
    final reveal = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([reveal, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final out = Curves.easeOut.transform(secondaryAnimation.value);
        Widget page = Transform.scale(
          scale: (1.06 - 0.06 * reveal.value) * (1 - 0.04 * out),
          child: child,
        );
        if (out > 0) {
          page = ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.35 * out),
              BlendMode.srcATop,
            ),
            child: page,
          );
        }
        if (reveal.value >= 1) return page;
        return ClipPath(
          clipper: _HexReveal(reveal.value),
          child: page,
        );
      },
    );
  }
}

class _HexReveal extends CustomClipper<Path> {
  final double t;
  _HexReveal(this.t);

  @override
  Path getClip(Size size) {
    final c = size.center(Offset.zero);
    // Large enough at t = 1 to cover the corners of the screen.
    final r = (0.08 + 0.92 * t) * size.longestSide * 0.82;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_HexReveal old) => old.t != t;
}
