import 'dart:math' as math;
import 'dart:ui';

/// Axial coordinate of a flat-top hexagon cell.
class Hex {
  final int q;
  final int r;
  const Hex(this.q, this.r);

  static const origin = Hex(0, 0);

  /// Neighbour offsets in axial space, clockwise starting at "east-north-east".
  static const directions = <Hex>[
    Hex(1, 0),
    Hex(1, -1),
    Hex(0, -1),
    Hex(-1, 0),
    Hex(-1, 1),
    Hex(0, 1),
  ];

  Hex operator +(Hex o) => Hex(q + o.q, r + o.r);
  Hex operator -(Hex o) => Hex(q - o.q, r - o.r);

  int get s => -q - r;

  Iterable<Hex> get neighbors => directions.map((d) => this + d);

  int distanceTo(Hex o) {
    final dq = (q - o.q).abs();
    final dr = (r - o.r).abs();
    final ds = (s - o.s).abs();
    return math.max(dq, math.max(dr, ds));
  }

  /// Mirror across the vertical screen axis (x -> -x).
  Hex get mirrored => Hex(-q, r + q);

  /// Centre of this cell in pixels for a hex of circumradius [size].
  Offset toPixel(double size) =>
      Offset(size * 1.5 * q, size * math.sqrt(3) * (r + q / 2));

  /// Nearest cell to a pixel position for hexes of circumradius [size].
  static Hex fromPixel(Offset p, double size) {
    final fq = (2 / 3 * p.dx) / size;
    final fr = (-1 / 3 * p.dx + math.sqrt(3) / 3 * p.dy) / size;
    return _round(fq, fr);
  }

  static Hex _round(double fq, double fr) {
    final fs = -fq - fr;
    var rq = fq.round();
    var rr = fr.round();
    final rs = fs.round();
    final dq = (rq - fq).abs();
    final dr = (rr - fr).abs();
    final ds = (rs - fs).abs();
    if (dq > dr && dq > ds) {
      rq = -rr - rs;
    } else if (dr > ds) {
      rr = -rq - rs;
    }
    return Hex(rq, rr);
  }

  List<int> toJson() => [q, r];
  static Hex fromJson(List<dynamic> j) => Hex(j[0] as int, j[1] as int);

  @override
  bool operator ==(Object other) =>
      other is Hex && other.q == q && other.r == r;

  @override
  int get hashCode => q * 7919 + r;

  @override
  String toString() => 'Hex($q,$r)';
}

/// Corner points of a flat-top hexagon centred at [c].
List<Offset> hexCorners(Offset c, double size) {
  return List.generate(6, (i) {
    final a = math.pi / 3 * i;
    return Offset(c.dx + size * math.cos(a), c.dy + size * math.sin(a));
  });
}

/// A flat-top hexagon path with softly rounded corners.
Path hexPath(Offset c, double size, {double roundness = 0.16}) {
  final pts = hexCorners(c, size);
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final p = pts[i];
    final prev = pts[(i + 5) % 6];
    final next = pts[(i + 1) % 6];
    final a = Offset.lerp(p, prev, roundness)!;
    final b = Offset.lerp(p, next, roundness)!;
    if (i == 0) {
      path.moveTo(a.dx, a.dy);
    } else {
      path.lineTo(a.dx, a.dy);
    }
    path.quadraticBezierTo(p.dx, p.dy, b.dx, b.dy);
  }
  path.close();
  return path;
}
