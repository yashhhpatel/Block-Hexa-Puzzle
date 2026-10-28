import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../services/progress.dart';
import '../services/sfx.dart';
import 'theme.dart';
import 'widgets.dart';

/// Shows an "Achievement unlocked!" toast over whatever screen is open,
/// one at a time, whenever play reaches a new achievement tier.
class AchievementToaster extends StatefulWidget {
  final Progress progress;
  final Sfx sfx;
  final Widget child;

  const AchievementToaster({
    super.key,
    required this.progress,
    required this.sfx,
    required this.child,
  });

  @override
  State<AchievementToaster> createState() => _AchievementToasterState();
}

class _AchievementToasterState extends State<AchievementToaster>
    with SingleTickerProviderStateMixin {
  final _queue = <AchievementUnlock>[];
  AchievementUnlock? _current;
  StreamSubscription<AchievementUnlock>? _sub;
  Timer? _hide;
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    reverseDuration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    _sub = widget.progress.achievementUnlocks.listen((u) {
      _queue.add(u);
      if (_current == null) _next();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hide?.cancel();
    _slide.dispose();
    super.dispose();
  }

  void _next() {
    if (_queue.isEmpty) {
      setState(() => _current = null);
      return;
    }
    setState(() => _current = _queue.removeAt(0));
    widget.sfx.play(Sound.star);
    HapticFeedback.mediumImpact();
    _slide.forward(from: 0);
    _hide = Timer(const Duration(milliseconds: 3200), _dismiss);
  }

  Future<void> _dismiss() async {
    _hide?.cancel();
    await _slide.reverse();
    if (mounted) _next();
  }

  @override
  Widget build(BuildContext context) {
    final u = _current;
    return Stack(
      children: [
        widget.child,
        if (u != null)
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.paddingOf(context).top + 8,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -1.6),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _slide,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              )),
              child: GestureDetector(
                onTap: _dismiss,
                child: _ToastCard(unlock: u),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastCard extends StatelessWidget {
  final AchievementUnlock unlock;
  const _ToastCard({required this.unlock});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF5B2A9E), Color(0xFF233F9A)],
          ),
          border: Border.all(color: AppColors.gold, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x88000000), blurRadius: 16),
            BoxShadow(color: Color(0x55FFC52E), blurRadius: 24),
          ],
        ),
        child: Row(
          children: [
            const TrophyBadge(size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('ach_unlocked').toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    unlock.def.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    unlock.def.title(unlock.target),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 20),
                Text(
                  '+${unlock.reward}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Golden hex trophy with a slowly turning ring of light behind it.
class TrophyBadge extends StatefulWidget {
  final double size;
  const TrophyBadge({super.key, this.size = 56});

  @override
  State<TrophyBadge> createState() => _TrophyBadgeState();
}

class _TrophyBadgeState extends State<TrophyBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _spin,
            builder: (_, _) => Transform.rotate(
              angle: _spin.value * 2 * math.pi,
              child: CustomPaint(size: Size.square(s), painter: _RaysPainter()),
            ),
          ),
          Container(
            width: s * 0.72,
            height: s * 0.72,
            decoration: const ShapeDecoration(
              shape: HexBorder(),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3A6), AppColors.gold, Color(0xFFE08A00)],
              ),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: s * 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()..color = AppColors.gold.withValues(alpha: 0.35);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a - 0.14) * r, c.dy + math.sin(a - 0.14) * r)
          ..lineTo(c.dx + math.cos(a + 0.14) * r, c.dy + math.sin(a + 0.14) * r)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => false;
}

/// Short celebration when an achievement reward is collected: the trophy
/// pops in, coins count up, then it closes by itself (or on tap).
Future<void> showRewardBurst(
  BuildContext context, {
  required String title,
  required int coins,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, _, _) => _RewardBurst(title: title, coins: coins),
    transitionBuilder: (_, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}

class _RewardBurst extends StatefulWidget {
  final String title;
  final int coins;
  const _RewardBurst({required this.title, required this.coins});

  @override
  State<_RewardBurst> createState() => _RewardBurstState();
}

class _RewardBurstState extends State<_RewardBurst> {
  Timer? _close;

  @override
  void initState() {
    super.initState();
    _close = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TrophyBadge(size: 150),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: OutlinedTitle(widget.title, size: 28),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 30),
                  const SizedBox(width: 8),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: widget.coins),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Text(
                      '+$v',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
