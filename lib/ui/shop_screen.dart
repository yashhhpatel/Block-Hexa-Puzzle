import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../game/hex.dart';
import '../meta/cosmetics.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'theme.dart';
import 'widgets.dart';

/// Block skins and board themes, bought with coins or unlocked with stars.
class ShopScreen extends StatefulWidget {
  final Services services;
  const ShopScreen({super.key, required this.services});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Progress get p => widget.services.progress;

  Future<void> _tap(ShopItem item) async {
    final sfx = widget.services.sfx;
    if (p.isUnlocked(item)) {
      sfx.play(Sound.button);
      await p.equip(item);
    } else if (item.starsRequired > 0 && p.totalStars < item.starsRequired) {
      sfx.play(Sound.fail);
      _toast(tr('need_stars', {'n': item.starsRequired, 'name': item.name}));
    } else if (await p.unlock(item)) {
      sfx.play(Sound.coin);
      await p.equip(item);
    } else {
      sfx.play(Sound.fail);
      _toast(tr('shop_no_coins'));
    }
    if (mounted) setState(() {});
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: GameBackground(
          animate: p.backgroundFx,
          theme: p.theme,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
                  child: Row(
                    children: [
                      RoundButton(
                        icon: Icons.arrow_back_rounded,
                        size: 44,
                        semanticLabel: tr('back'),
                        onTap: () {
                          widget.services.sfx.play(Sound.button);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 10),
                      OutlinedTitle(tr('shop_title'), size: 28),
                      const Spacer(),
                      _StarPill(stars: p.totalStars),
                      const SizedBox(width: 6),
                      CoinPill(coins: p.coins),
                    ],
                  ),
                ),
                TabBar(
                  indicatorColor: AppColors.accent,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: tr('tab_blocks')),
                    Tab(text: tr('tab_themes')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _grid([
                        for (final s in Cosmetics.skins)
                          _ItemCard(
                            item: s,
                            preview: SkinPreview(style: s.style, size: 78),
                            unlocked: p.isUnlocked(s),
                            equipped: p.skinId == s.id,
                            onTap: () => _tap(s),
                          ),
                      ]),
                      _grid([
                        for (final t in Cosmetics.themes)
                          _ItemCard(
                            item: t,
                            preview: _ThemePreview(
                              theme: t,
                              skin: p.skin.style,
                            ),
                            unlocked: p.isUnlocked(t),
                            equipped: p.themeId == t.id,
                            onTap: () => _tap(t),
                          ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(List<Widget> cards) => GridView.count(
    crossAxisCount: 2,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 0.82,
    children: cards,
  );
}

class _StarPill extends StatelessWidget {
  final int stars;
  const _StarPill({required this.stars});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: AppColors.gold, size: 22),
        const SizedBox(width: 4),
        Text(
          '$stars',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}

class _ItemCard extends StatelessWidget {
  final ShopItem item;
  final Widget preview;
  final bool unlocked;
  final bool equipped;
  final VoidCallback onTap;

  const _ItemCard({
    required this.item,
    required this.preview,
    required this.unlocked,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget action;
    if (equipped) {
      action = _Tag(
        label: tr('in_use'),
        color: Color(0xFF2FB58A),
        icon: Icons.check_rounded,
      );
    } else if (unlocked) {
      action = _Tag(label: tr('use'), color: AppColors.button);
    } else if (item.starsRequired > 0) {
      action = _Tag(
        label: '${item.starsRequired}',
        color: const Color(0xFF5B2A9E),
        icon: Icons.star_rounded,
      );
    } else {
      action = _Tag(
        label: '${item.price}',
        color: const Color(0xFFE59A00),
        coin: true,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: equipped
                ? const Color(0xFF6CF0B8)
                : Colors.white.withValues(alpha: 0.12),
            width: equipped ? 2.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(child: preview),
                  if (!unlocked)
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(Icons.lock_rounded, color: Colors.white54),
                    ),
                ],
              ),
            ),
            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            action,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool coin;
  const _Tag({
    required this.label,
    required this.color,
    this.icon,
    this.coin = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.8),
        width: 1.5,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (coin) ...[const CoinIcon(size: 18), const SizedBox(width: 5)],
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

/// Mini board in the theme's colours with a couple of blocks on it.
class _ThemePreview extends StatelessWidget {
  final BoardTheme theme;
  final SkinStyle skin;
  const _ThemePreview({required this.theme, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bgTop, theme.bgMid, theme.bgBottom],
        ),
      ),
      child: CustomPaint(painter: _ThemePainter(theme, skin)),
    );
  }
}

class _ThemePainter extends CustomPainter {
  final BoardTheme theme;
  final SkinStyle skin;
  _ThemePainter(this.theme, this.skin);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height * 0.16;
    final c = size.center(Offset.zero);
    const cells = [
      (0.0, -1.0),
      (-1.5, -0.5),
      (1.5, -0.5),
      (0.0, 0.0),
      (-1.5, 0.5),
      (1.5, 0.5),
      (0.0, 1.0),
    ];
    for (var i = 0; i < cells.length; i++) {
      final p = c + Offset(cells[i].$1 * s, cells[i].$2 * s * 1.732);
      final path = hexPath(p, s, roundness: 0.1);
      canvas.drawPath(path, Paint()..color = theme.cell);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = theme.line.withValues(alpha: 0.85),
      );
      if (i == 1 || i == 3 || i == 4) {
        drawBlock(canvas, p, s, kBlockColors[i == 3 ? 0 : 6], skin);
      }
    }
  }

  @override
  bool shouldRepaint(_ThemePainter old) =>
      old.theme != theme || old.skin != skin;
}
