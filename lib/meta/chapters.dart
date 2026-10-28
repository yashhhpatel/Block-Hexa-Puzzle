import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Look of a chapter: badge emoji, accent colour and card gradient.
class ChapterStyle {
  final String emoji;
  final Color color;
  final Color deep; // dark end of the card gradient
  const ChapterStyle(this.emoji, this.color, this.deep);
}

/// A named group of consecutive levels. Chapters never run out: after the
/// fixed ones come Grandmaster I, II, III… of 100 levels each.
class Chapter {
  final int index;
  final int first;
  final int count;
  final ChapterStyle style;

  const Chapter(this.index, this.first, this.count, this.style);

  Color get color => style.color;
  String get emoji => style.emoji;

  /// Localized name, e.g. "Easy" or "Grandmaster III".
  String get name => index < Chapters.fixedCount
      ? tr('chapter_$index')
      : tr('chapter_grand', {
          'n': Chapters.roman(index - Chapters.fixedCount + 1),
        });

  /// Name with its badge, e.g. "⚡ Insane".
  String get title => '$emoji $name';

  int get last => first + count - 1;
  bool contains(int level) => level >= first && level <= last;
  int positionOf(int level) => level - first + 1;

  /// Coins awarded the first time the last level of the chapter is cleared.
  int get reward => 50 + 25 * index;

  int get maxStars => count * 3;
}

class Chapters {
  // Level ranges of the original six chapters never move (players' stars
  // and progress are stored per level number). New chapters go after them.
  static const _fixed = [
    20, // Beginner      1-20
    40, // Easy         21-60
    60, // Normal       61-120
    80, // Hard        121-200
    100, // Expert     201-300
    100, // Master     301-400
    100, // Insane     401-500
    100, // Nightmare  501-600
    100, // Legendary  601-700
    100, // Impossible 701-800
  ];
  static int get fixedCount => _fixed.length;
  static const _endlessSize = 100;

  static const _styles = [
    ChapterStyle('🌱', Color(0xFF3FE0A8), Color(0xFF0E5A45)), // Beginner
    ChapterStyle('🟢', Color(0xFF6BDB4A), Color(0xFF1D5A12)), // Easy
    ChapterStyle('🔵', Color(0xFF3EC9F5), Color(0xFF0F4A7A)), // Normal
    ChapterStyle('🟠', Color(0xFFFF8A2B), Color(0xFF7A3208)), // Hard
    ChapterStyle('🔴', Color(0xFFFF3B47), Color(0xFF7A0E16)), // Expert
    ChapterStyle('🟣', Color(0xFF9B5CFF), Color(0xFF3A1478)), // Master
    ChapterStyle('⚡', Color(0xFFFFE135), Color(0xFF0F6E8C)), // Insane
    ChapterStyle('💀', Color(0xFFE0284A), Color(0xFF14040A)), // Nightmare
    ChapterStyle('👑', Color(0xFFFFC21A), Color(0xFF6E4400)), // Legendary
    ChapterStyle('🔥', Color(0xFFFF5A1F), Color(0xFF7A0F00)), // Impossible
  ];

  static const _grandmaster = [
    ChapterStyle('🏆', Color(0xFF5EC8FF), Color(0xFF14286B)),
    ChapterStyle('🏆', Color(0xFFC060F0), Color(0xFF3A1478)),
    ChapterStyle('🏆', Color(0xFFFFC93A), Color(0xFF6E4400)),
  ];

  static int get _fixedLevels => _fixed.fold(0, (s, c) => s + c);

  static Chapter at(int index) {
    if (index < _fixed.length) {
      var first = 1;
      for (var i = 0; i < index; i++) {
        first += _fixed[i];
      }
      return Chapter(index, first, _fixed[index], _styles[index]);
    }
    final k = index - _fixed.length;
    return Chapter(
      index,
      _fixedLevels + 1 + k * _endlessSize,
      _endlessSize,
      _grandmaster[k % _grandmaster.length],
    );
  }

  static Chapter forLevel(int level) {
    if (level > _fixedLevels) {
      return at(_fixed.length + (level - _fixedLevels - 1) ~/ _endlessSize);
    }
    for (var i = 0; ; i++) {
      final c = at(i);
      if (c.contains(level)) return c;
    }
  }

  static String roman(int n) {
    const vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const syms = [
      'M',
      'CM',
      'D',
      'CD',
      'C',
      'XC',
      'L',
      'XL',
      'X',
      'IX',
      'V',
      'IV',
      'I',
    ];
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
