import 'package:flutter/material.dart';

/// Something the shop sells: free, bought with coins, or unlocked by stars.
abstract class ShopItem {
  String get id;
  String get name;
  int get price; // coins; 0 = free
  int get starsRequired; // 0 = no star gate
}

enum SkinStyle { gem, flat, candy, neon, crystal }

class BlockSkin implements ShopItem {
  @override
  final String id;
  @override
  final String name;
  @override
  final int price;
  @override
  final int starsRequired;
  final SkinStyle style;

  const BlockSkin(this.id, this.name, this.style,
      {this.price = 0, this.starsRequired = 0});
}

class BoardTheme implements ShopItem {
  @override
  final String id;
  @override
  final String name;
  @override
  final int price;
  @override
  final int starsRequired;
  final Color bgTop, bgMid, bgBottom;
  final Color cell, line, tray;

  const BoardTheme(
    this.id,
    this.name, {
    required this.bgTop,
    required this.bgMid,
    required this.bgBottom,
    required this.cell,
    required this.line,
    required this.tray,
    this.price = 0,
    this.starsRequired = 0,
  });
}

class Cosmetics {
  static const skins = <BlockSkin>[
    BlockSkin('gem', 'Gem', SkinStyle.gem),
    BlockSkin('flat', 'Matte', SkinStyle.flat, price: 150),
    BlockSkin('candy', 'Candy', SkinStyle.candy, price: 300),
    BlockSkin('crystal', 'Crystal', SkinStyle.crystal, starsRequired: 90),
    BlockSkin('neon', 'Neon', SkinStyle.neon, price: 500),
  ];

  static const themes = <BoardTheme>[
    BoardTheme('ocean', 'Ocean',
        bgTop: Color(0xFF14286B),
        bgMid: Color(0xFF0C1C4D),
        bgBottom: Color(0xFF060E2B),
        cell: Color(0xFF071233),
        line: Color(0xFF5EC8FF),
        tray: Color(0xFF081638)),
    BoardTheme('galaxy', 'Galaxy',
        price: 200,
        bgTop: Color(0xFF3A1A78),
        bgMid: Color(0xFF221050),
        bgBottom: Color(0xFF0E0628),
        cell: Color(0xFF150A33),
        line: Color(0xFFC08CFF),
        tray: Color(0xFF170A38)),
    BoardTheme('forest', 'Forest',
        price: 250,
        bgTop: Color(0xFF155A4A),
        bgMid: Color(0xFF0B3B33),
        bgBottom: Color(0xFF04201C),
        cell: Color(0xFF052520),
        line: Color(0xFF6CF0B8),
        tray: Color(0xFF062A24)),
    BoardTheme('sunset', 'Sunset',
        price: 350,
        bgTop: Color(0xFF8A2E5A),
        bgMid: Color(0xFF4E1A48),
        bgBottom: Color(0xFF1E0A24),
        cell: Color(0xFF2A0C2A),
        line: Color(0xFFFFB070),
        tray: Color(0xFF2A0B2C)),
    BoardTheme('midnight', 'Midnight',
        starsRequired: 60,
        bgTop: Color(0xFF2A2F3A),
        bgMid: Color(0xFF171A22),
        bgBottom: Color(0xFF07080C),
        cell: Color(0xFF0B0D12),
        line: Color(0xFFE8EEF8),
        tray: Color(0xFF0D0F15)),
  ];

  static BlockSkin skin(String id) =>
      skins.firstWhere((s) => s.id == id, orElse: () => skins.first);
  static BoardTheme theme(String id) =>
      themes.firstWhere((t) => t.id == id, orElse: () => themes.first);
}
