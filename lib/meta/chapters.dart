import 'package:flutter/material.dart';

/// A named group of consecutive levels. Chapters never run out: after the
/// fixed ones come Grandmaster I, II, III… of 100 levels each.
class Chapter {
  final int index;
  final String name;
  final int first;
  final int count;
  final Color color;

  const Chapter(this.index, this.name, this.first, this.count, this.color);

  int get last => first + count - 1;
  bool contains(int level) => level >= first && level <= last;
  int positionOf(int level) => level - first + 1;

  /// Coins awarded the first time the last level of the chapter is cleared.
  int get reward => 50 + 25 * index;

  int get maxStars => count * 3;
}

class Chapters {
  static const _fixed = [
    ('Beginner', 20),
    ('Easy', 40),
    ('Normal', 60),
    ('Hard', 80),
    ('Expert', 100),
    ('Master', 100),
  ];
  static const _endlessSize = 100;

  static const _colors = [
    Color(0xFF3FE0A8),
    Color(0xFF3EC9F5),
    Color(0xFFFFC93A),
    Color(0xFFFF8A2B),
    Color(0xFFFF4D8D),
    Color(0xFF8E5CFF),
    Color(0xFFC060F0),
    Color(0xFFFF5A4E),
  ];

  static int get _fixedLevels => _fixed.fold(0, (s, c) => s + c.$2);

  static Chapter at(int index) {
    final color = _colors[index % _colors.length];
    if (index < _fixed.length) {
      var first = 1;
      for (var i = 0; i < index; i++) {
        first += _fixed[i].$2;
      }
      return Chapter(index, _fixed[index].$1, first, _fixed[index].$2, color);
    }
    final k = index - _fixed.length;
    return Chapter(index, 'Grandmaster ${_roman(k + 1)}',
        _fixedLevels + 1 + k * _endlessSize, _endlessSize, color);
  }

  static Chapter forLevel(int level) {
    if (level > _fixedLevels) {
      return at(_fixed.length + (level - _fixedLevels - 1) ~/ _endlessSize);
    }
    for (var i = 0;; i++) {
      final c = at(i);
      if (c.contains(level)) return c;
    }
  }

  static String _roman(int n) {
    const vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const syms = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
    final b = StringBuffer();
    for (var i = 0; i < vals.length; i++) {
      while (n >= vals[i]) {
        b.write(syms[i]);
        n -= vals[i];
      }
    }
    return b.toString();
  }
}
