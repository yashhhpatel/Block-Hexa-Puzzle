import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/level.dart';
import '../l10n/l10n.dart';
import '../services/progress.dart';
import '../services/sfx.dart';
import 'theme.dart';
import 'widgets.dart';

String formatTime(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// The level-complete screen: stars, checklist, rewards and what's next.
class WinOverlay extends StatefulWidget {
  final Level level;
  final WinSummary summary;
  final int seconds;
  final Sfx sfx;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  /// Shows a rewarded video; completes with true only if the reward was
  /// earned, in which case the coins of this win are paid out again.
  final Future<bool> Function()? onDoubleCoins;

  const WinOverlay({
    super.key,
    required this.level,
    required this.summary,
    required this.seconds,
    required this.sfx,
    required this.onNext,
    required this.onReplay,
    required this.onHome,
    this.onDoubleCoins,
  });

  @override
  State<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<WinOverlay> {
  int _litStars = 0;
  final List<Timer> _timers = [];
  bool _doubled = false;
  bool _busy = false;

  Future<void> _double() async {
    final watch = widget.onDoubleCoins;
    // One claim per win: ignore taps while a video runs or once doubled.
    if (watch == null || _busy || _doubled) return;
    setState(() => _busy = true);
    final ok = await watch();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _doubled = ok;
    });
    if (ok) widget.sfx.play(Sound.coin);
  }

  @override
  void initState() {
    super.initState();
    // Stars pop in one at a time.
    for (var i = 0; i < widget.summary.stars; i++) {
      _timers.add(
        Timer(Duration(milliseconds: 450 + 280 * i), () {
          if (!mounted) return;
          setState(() => _litStars = i + 1);
          widget.sfx.play(Sound.star);
        }),
      );
    }
    if (widget.summary.coins > 0) {
      _timers.add(
        Timer(
          Duration(milliseconds: 600 + 280 * widget.summary.stars),
          () => widget.sfx.play(Sound.coin),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final level = widget.level;
    final cheer = s.stars == 3
        ? tr('cheer_perfect')
        : tr('cheer_${(level.number + (level.dailyKey ?? 0)) % 4}');
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Container(
          color: Colors.black.withValues(alpha: 0.55 * v.clamp(0, 1)),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: 0.7 + 0.3 * v,
            child: Opacity(opacity: v.clamp(0, 1), child: child),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF0233F9A), Color(0xF20E1A4A)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.8),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BigStars(lit: _litStars),
                const SizedBox(height: 8),
                OutlinedTitle(cheer.toUpperCase(), size: 34),
                const SizedBox(height: 4),
                Text(
                  level.isDaily
                      ? tr('daily_solved_in', {'t': formatTime(widget.seconds)})
                      : tr('level_cleared_in', {
                          'n': level.number,
                          't': formatTime(widget.seconds),
                        }),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _criteria(s, level),
                const SizedBox(height: 12),
                ..._rewards(s),
                if (!level.isDaily) ...[
                  const SizedBox(height: 12),
                  _ChestBar(
                    progress: s.chestProgress,
                    opened: s.chestReward != null,
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoundButton(
                      icon: Icons.home_rounded,
                      onTap: widget.onHome,
                      semanticLabel: tr('home'),
                    ),
                    const SizedBox(width: 10),
                    RoundButton(
                      icon: Icons.refresh_rounded,
                      onTap: widget.onReplay,
                      semanticLabel: tr('replay'),
                    ),
                    const SizedBox(width: 14),
                    PillButton(
                      label: level.isDaily ? tr('done') : tr('next'),
                      onTap: widget.onNext,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _criteria(WinSummary s, Level level) {
    Widget row(bool ok, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: ok ? const Color(0xFF6CF0B8) : Colors.white38,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: ok ? Colors.white : Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(true, tr('crit_filled')),
          row(s.noHints, tr('crit_no_hints')),
          row(
            s.underPar,
            tr('crit_under', {'t': formatTime(level.parSeconds)}),
          ),
        ],
      ),
    );
  }

  static const _coinStyle = TextStyle(
    color: AppColors.gold,
    fontSize: 26,
    fontWeight: FontWeight.w900,
  );

  Widget _doubleButton() {
    return Pressable(
      onTap: _busy ? null : _double,
      pressedScale: 0.94,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE07A), AppColors.gold, Color(0xFFD48A00)],
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x66FFC52E), blurRadius: 14),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.ondemand_video_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tr('double_btn'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Color(0x66000000), blurRadius: 3)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doubledChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2FB58A).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6CF0B8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF6CF0B8),
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            tr('double_done'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rewards(WinSummary s) {
    final lines = <Widget>[];
    if (s.coins > 0) {
      lines.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 26),
            const SizedBox(width: 6),
            const Text('+', style: _coinStyle),
            CountUpText(_doubled ? s.coins * 2 : s.coins, style: _coinStyle),
          ],
        ),
      );
      if (widget.onDoubleCoins != null) {
        lines.add(const SizedBox(height: 8));
        lines.add(_doubled ? _doubledChip() : _doubleButton());
      }
    }
    Widget note(IconData icon, String text, Color color) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (s.newBest && s.previousStars > 0) {
      lines.add(
        note(
          Icons.trending_up_rounded,
          tr('new_best', {'n': s.stars}),
          AppColors.gold,
        ),
      );
    }
    if (s.dailyStreak != null) {
      lines.add(
        note(
          Icons.local_fire_department_rounded,
          tr('streak_days', {'n': s.dailyStreak!}),
          const Color(0xFFFF8A2B),
        ),
      );
    }
    if (s.streakBonus != null) {
      lines.add(
        note(
          Icons.card_giftcard_rounded,
          tr('streak_bonus', {'n': s.streakBonus!}),
          const Color(0xFFFF8A2B),
        ),
      );
    }
    if (s.chestReward != null) {
      lines.add(
        note(
          Icons.inventory_2_rounded,
          tr('chest_opened_reward', {'n': s.chestReward!}),
          const Color(0xFF6CF0B8),
        ),
      );
    }
    final ch = s.chapterCompleted;
    if (ch != null) {
      lines.add(
        note(
          Icons.emoji_events_rounded,
          tr('chapter_complete', {'name': ch.title, 'n': ch.reward}),
          ch.color,
        ),
      );
    }
    return lines;
  }
}

class _BigStars extends StatelessWidget {
  final int lit;
  const _BigStars({required this.lit});

  @override
  Widget build(BuildContext context) {
    Widget star(int i, double size, double lift) {
      final on = i < lit;
      return Transform.translate(
        offset: Offset(0, lift),
        child: AnimatedScale(
          scale: on ? 1 : 0.8,
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: on ? AppColors.gold : Colors.white.withValues(alpha: 0.18),
            shadows: on
                ? const [Shadow(color: Color(0xAAFFC52E), blurRadius: 18)]
                : null,
          ),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(angle: -math.pi / 14, child: star(0, 70, 14)),
          star(1, 96, 0),
          Transform.rotate(angle: math.pi / 14, child: star(2, 70, 14)),
        ],
      ),
    );
  }
}

/// Progress toward the next reward chest (one step per new level cleared).
class _ChestBar extends StatelessWidget {
  final int progress;
  final bool opened;
  const _ChestBar({required this.progress, required this.opened});

  @override
  Widget build(BuildContext context) {
    final frac = opened ? 1.0 : progress / Progress.chestSize;
    return SizedBox(
      width: 240,
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_rounded,
            color: Color(0xFF6CF0B8),
            size: 26,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opened
                      ? tr('chest_opened')
                      : tr('chest_progress', {
                          'n': progress,
                          'total': Progress.chestSize,
                        }),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFF6CF0B8),
                    ),
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
