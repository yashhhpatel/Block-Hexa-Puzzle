import 'package:flutter/material.dart';

import 'dart:async';

import '../l10n/l10n.dart';
import '../meta/chapters.dart';
import '../services/ads.dart';
import '../services/billing.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'chapters_screen.dart';
import 'daily_screen.dart';
import 'game_screen.dart';
import 'login_bonus_dialog.dart';
import 'quests_screen.dart';
import 'settings_dialog.dart';
import 'shop_screen.dart';
import 'theme.dart';
import 'time_attack_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  final Services services;
  const HomeScreen({super.key, required this.services});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  StreamSubscription<BillingNotice>? _notices;

  Progress get p => widget.services.progress;

  @override
  void initState() {
    super.initState();
    widget.services.billing.premium.addListener(_refresh);
    // Tell the player if their Remove Ads plan ran out while they were away.
    _notices = widget.services.billing.notices.listen((n) {
      if (n == BillingNotice.expired && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('ra_expired'))));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Cold-start app-open ad first, then the daily login reward.
      await widget.services.ads.showAppOpenOnLaunch();
      if (!mounted) return;
      await maybeShowLoginBonus(context, widget.services);
      if (mounted) setState(() {});
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notices?.cancel();
    widget.services.billing.premium.removeListener(_refresh);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    widget.services.sfx.play(Sound.button);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    // A new day may have started while the player was in another screen.
    await maybeShowLoginBonus(context, widget.services);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final level = p.currentLevel;
    final chapter = Chapters.forLevel(level);
    final dailyDone = p.isDailySolved(p.today);
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    RoundButton(
                      icon: Icons.settings_rounded,
                      size: 44,
                      semanticLabel: tr('settings'),
                      onTap: () async {
                        widget.services.sfx.play(Sound.button);
                        await showSettingsDialog(context, widget.services);
                        if (mounted) setState(() {});
                      },
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.gold,
                            size: 24,
                          ),
                          const SizedBox(width: 4),
                          CountUpText(
                            p.totalStars,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CoinPill(coins: p.coins),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              const _Logo(),
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Transform.scale(
                  scale: 1 + 0.05 * Curves.easeInOut.transform(_pulse.value),
                  child: child,
                ),
                child: Pressable(
                  pressedScale: 0.92,
                  onTap: () => _open(
                    GameScreen(services: widget.services, level: level),
                  ),
                  child: HexShimmer(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: const ShapeDecoration(
                        shape: HexBorder(),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFF8DB5),
                            AppColors.accent,
                            AppColors.accentDark,
                          ],
                        ),
                        shadows: [
                          BoxShadow(color: Color(0x99FF4F8B), blurRadius: 30),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedTitle(tr('level_n', {'n': level}), size: 26),
              Text(
                '${chapter.title} · ${chapter.positionOf(level)}/${chapter.count}',
                style: TextStyle(
                  color: chapter.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              _chestBar(),
              const SizedBox(height: 12),
              PillButton(
                label: tr('time_attack'),
                icon: Icons.timer_rounded,
                width: 190,
                color: const Color(0xFF7A55F0),
                dark: const Color(0xFF4A2BB0),
                onTap: () =>
                    _open(TimeAttackScreen(services: widget.services)),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MenuTile(
                      icon: Icons.calendar_month_rounded,
                      label: tr('menu_daily'),
                      color: const Color(0xFFFF8A2B),
                      badge: dailyDone ? 0 : 1,
                      sub: p.streak > 0 ? '🔥 ${p.streak}' : null,
                      onTap: () =>
                          _open(DailyScreen(services: widget.services)),
                    ),
                    _MenuTile(
                      icon: Icons.task_alt_rounded,
                      label: tr('menu_quests'),
                      color: const Color(0xFF8E5CFF),
                      badge: p.claimableRewards,
                      onTap: () =>
                          _open(QuestsScreen(services: widget.services)),
                    ),
                    _MenuTile(
                      icon: Icons.storefront_rounded,
                      label: tr('menu_shop'),
                      color: const Color(0xFF2FB58A),
                      onTap: () => _open(ShopScreen(services: widget.services)),
                    ),
                    _MenuTile(
                      icon: Icons.grid_view_rounded,
                      label: tr('menu_levels'),
                      color: AppColors.button,
                      onTap: () =>
                          _open(ChaptersScreen(services: widget.services)),
                    ),
                  ],
                ),
              ),
              AdBanner(ads: widget.services.ads),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chestBar() {
    final c = p.chestProgress;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_rounded,
            color: Color(0xFF6CF0B8),
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('next_chest', {'n': c, 'total': Progress.chestSize}),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: c / Progress.chestSize,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFF6CF0B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final String? sub;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotifyDot(
            count: badge,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(color, Colors.white, 0.3)!,
                    color,
                    Color.lerp(color, Colors.black, 0.3)!,
                  ],
                ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(0, 3),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 80,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            height: 16,
            child: sub == null
                ? null
                : Text(
                    sub!,
                    style: const TextStyle(
                      color: Color(0xFFFFB070),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    const letters = 'HEXA';
    const colors = [
      Color(0xFF3EC9F5),
      Color(0xFFFFC93A),
      Color(0xFFFF4D8D),
      Color(0xFF8BE04A),
    ];
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < letters.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: ShapeDecoration(
                    shape: const HexBorder(),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(colors[i], Colors.white, 0.35)!,
                        colors[i],
                        Color.lerp(colors[i], Colors.black, 0.25)!,
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letters[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          offset: Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(child: OutlinedTitle(tr('logo_sub'), size: 32)),
      ],
    );
  }
}
