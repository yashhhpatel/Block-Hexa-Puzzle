import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

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
  String get name => tr('skin_$id');
  @override
  final int price;
  @override
  final int starsRequired;
  final SkinStyle style;

  const BlockSkin(
    this.id,
    this.style, {
    this.price = 0,
    this.starsRequired = 0,
  });
}

class BoardTheme implements ShopItem {
  @override
  final String id;
  @override
  String get name => tr('theme_$id');
  @override
  final int price;
  @override
  final int starsRequired;
  final Color bgTop, bgMid, bgBottom;
  final Color cell, line, tray;

  /// Colour of the background light flares and drifting hexagons. Defaults
  /// to [line]; a second colour gives two-tone themes like Aurora.
  final Color? flareColor;
  Color get flare => flareColor ?? line;

  const BoardTheme(
    this.id, {
    required this.bgTop,
    required this.bgMid,
    required this.bgBottom,
    required this.cell,
    required this.line,
    required this.tray,
    this.flareColor,
    this.price = 0,
    this.starsRequired = 0,
  });
}

class Cosmetics {
  static const skins = <BlockSkin>[
    BlockSkin('gem', SkinStyle.gem),
    BlockSkin('flat', SkinStyle.flat, price: 150),
    BlockSkin('candy', SkinStyle.candy, price: 300),
    BlockSkin('crystal', SkinStyle.crystal, starsRequired: 90),
    BlockSkin('neon', SkinStyle.neon, price: 500),
  ];

  static const themes = <BoardTheme>[
    BoardTheme(
      'ocean',
      bgTop: Color(0xFF14286B),
      bgMid: Color(0xFF0C1C4D),
      bgBottom: Color(0xFF060E2B),
      cell: Color(0xFF071233),
      line: Color(0xFF5EC8FF),
      tray: Color(0xFF081638),
    ),
    BoardTheme(
      'galaxy',
      price: 200,
      bgTop: Color(0xFF3A1A78),
      bgMid: Color(0xFF221050),
      bgBottom: Color(0xFF0E0628),
      cell: Color(0xFF150A33),
      line: Color(0xFFC08CFF),
      tray: Color(0xFF170A38),
    ),
    BoardTheme(
      'forest',
      price: 250,
      bgTop: Color(0xFF155A4A),
      bgMid: Color(0xFF0B3B33),
      bgBottom: Color(0xFF04201C),
      cell: Color(0xFF052520),
      line: Color(0xFF6CF0B8),
      tray: Color(0xFF062A24),
    ),
    BoardTheme(
      'sunset',
      price: 350,
      bgTop: Color(0xFF8A2E5A),
      bgMid: Color(0xFF4E1A48),
      bgBottom: Color(0xFF1E0A24),
      cell: Color(0xFF2A0C2A),
      line: Color(0xFFFFB070),
      tray: Color(0xFF2A0B2C),
    ),
    BoardTheme(
      'midnight',
      starsRequired: 60,
      bgTop: Color(0xFF2A2F3A),
      bgMid: Color(0xFF171A22),
      bgBottom: Color(0xFF07080C),
      cell: Color(0xFF0B0D12),
      line: Color(0xFFE8EEF8),
      tray: Color(0xFF0D0F15),
    ),
    // Northern lights: mint board lines over a teal night, violet glow.
    BoardTheme(
      'aurora',
      price: 400,
      bgTop: Color(0xFF0B4A55),
      bgMid: Color(0xFF0A2440),
      bgBottom: Color(0xFF050C1C),
      cell: Color(0xFF061A2C),
      line: Color(0xFF5CFFC8),
      tray: Color(0xFF071B2E),
      flareColor: Color(0xFFB57BFF),
    ),
    // Cherry blossom: rose dusk with petal-white lines.
    BoardTheme(
      'sakura',
      price: 450,
      bgTop: Color(0xFFB8577F),
      bgMid: Color(0xFF6A2752),
      bgBottom: Color(0xFF2A0F26),
      cell: Color(0xFF3A1230),
      line: Color(0xFFFFD1E6),
      tray: Color(0xFF331029),
      flareColor: Color(0xFFFFE3F0),
    ),
    // Glacier: icy blues with frost-white lines.
    BoardTheme(
      'glacier',
      price: 300,
      bgTop: Color(0xFF2A6A8C),
      bgMid: Color(0xFF14425E),
      bgBottom: Color(0xFF07202F),
      cell: Color(0xFF0A2A3C),
      line: Color(0xFFDFF6FF),
      tray: Color(0xFF0B2B3D),
      flareColor: Color(0xFF9FE8FF),
    ),
    // Lava: black rock, ember glow, molten-orange lines. Earned with stars.
    BoardTheme(
      'lava',
      starsRequired: 120,
      bgTop: Color(0xFF5A0F05),
      bgMid: Color(0xFF2E0704),
      bgBottom: Color(0xFF0E0202),
      cell: Color(0xFF1A0503),
      line: Color(0xFFFF6A1F),
      tray: Color(0xFF1C0604),
      flareColor: Color(0xFFFFC24A),
    ),
    // Royal: deep indigo velvet with gold trim.
    BoardTheme(
      'royal',
      price: 600,
      bgTop: Color(0xFF1F1658),
      bgMid: Color(0xFF120C36),
      bgBottom: Color(0xFF07051A),
      cell: Color(0xFF0E0A2A),
      line: Color(0xFFFFD36B),
      tray: Color(0xFF100B2E),
      flareColor: Color(0xFFFFE9A8),
    ),
  ];

  static BlockSkin skin(String id) =>
      skins.firstWhere((s) => s.id == id, orElse: () => skins.first);
  static BoardTheme theme(String id) =>
      themes.firstWhere((t) => t.id == id, orElse: () => themes.first);
}
