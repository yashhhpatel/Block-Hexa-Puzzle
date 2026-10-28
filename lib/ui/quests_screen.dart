import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../meta/quests.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'achievement_toast.dart';
import 'theme.dart';
import 'widgets.dart';

/// Daily quests (reset at midnight) and tiered lifetime achievements.
class QuestsScreen extends StatefulWidget {
  final Services services;
  const QuestsScreen({super.key, required this.services});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  Timer? _clock;

  Progress get p => widget.services.progress;

  @override
  void initState() {
    super.initState();
    // Keeps the "new quests in" countdown fresh.
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _claimAchievement(AchievementStatus a) async {
    final got = await p.claimAchievement(a.def.id);
    if (got <= 0 || !mounted) return;
    widget.services.sfx.play(Sound.coin);
    setState(() {});
    await showRewardBurst(context, title: a.def.name, coins: got);
  }

  Future<void> _claim(Future<int> Function() claim) async {
    final got = await claim();
    if (got > 0) widget.services.sfx.play(Sound.coin);
    if (mounted) setState(() {});
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
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: OutlinedTitle(tr('quests_title'), size: 28),
                        ),
                      ),
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
                    Tab(text: tr('tab_daily')),
                    Tab(text: tr('tab_achievements')),
                  ],
                ),
                Expanded(
                  child: TabBarView(children: [_daily(), _achievements()]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _daily() {
    final quests = p.todayQuests;
    final now = p.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final left = midnight.difference(now);
    final allDone = quests.every((q) => q.claimed);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded, color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr('new_quests_in', {
                  'h': left.inHours,
                  'm': left.inMinutes % 60,
                }),
                style: const TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final q in quests)
          _Card(
            icon: _iconFor(q.def.stat),
            title: q.def.title,
            progress: q.progress,
            target: q.def.target,
            reward: q.def.reward,
            claimed: q.claimed,
            onClaim: q.claimable
                ? () => _claim(() => p.claimQuest(q.def.id))
                : null,
          ),
        _Card(
          icon: Icons.workspace_premium_rounded,
          title: tr('all_quests'),
          progress: quests.where((q) => q.claimed).length,
          target: quests.length,
          reward: Quests.allDoneBonus,
          claimed: p.allQuestsBonusClaimed,
          highlight: true,
          onClaim: allDone && p.allQuestsBonusClaimable
              ? () => _claim(() => p.claimQuest('all'))
              : null,
        ),
      ],
    );
  }

  Widget _achievements() {
    final list = p.achievements
      ..sort((a, b) {
        // Claimable first, then closest to completion, finished ones last.
        int rank(AchievementStatus s) => s.claimable ? 0 : (s.maxed ? 2 : 1);
        final r = rank(a) - rank(b);
        if (r != 0) return r;
        return (b.value / b.target).compareTo(a.value / a.target);
      });
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        for (final a in list)
          _Card(
            icon: _iconFor(a.def.stat),
            title: a.def.name,
            subtitle: a.maxed
                ? '${a.def.title(a.def.tiers.last)} ✓'
                : a.def.title(a.target),
            progress: a.value,
            target: a.target,
            reward: a.maxed ? 0 : a.reward,
            claimed: a.maxed,
            tiers: a.def.tiers.length,
            tiersDone: a.claimedTiers,
            onClaim: a.claimable ? () => _claimAchievement(a) : null,
          ),
      ],
    );
  }

  static IconData _iconFor(Stat s) => switch (s) {
    Stat.levelsCleared => Icons.flag_rounded,
    Stat.noHintClears => Icons.lightbulb_outline_rounded,
    Stat.starsEarned => Icons.star_rounded,
    Stat.fastClears => Icons.timer_rounded,
    Stat.threeStarLevels => Icons.auto_awesome_rounded,
    Stat.dailyPlayed => Icons.calendar_month_rounded,
    Stat.blocksPlaced => Icons.hexagon_rounded,
    Stat.chaptersCompleted => Icons.emoji_events_rounded,
    Stat.bestStreak => Icons.local_fire_department_rounded,
    Stat.questsCompleted => Icons.task_alt_rounded,
    Stat.loginDays => Icons.event_available_rounded,
    Stat.chestsOpened => Icons.inventory_2_rounded,
    Stat.itemsUnlocked => Icons.palette_rounded,
    Stat.dailyPerfect => Icons.wb_sunny_rounded,
    Stat.hintsUsed => Icons.lightbulb_rounded,
    Stat.playSeconds ||
    Stat.timedClears ||
    Stat.timedSeconds => Icons.timer_rounded,
  };
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final int progress;
  final int target;
  final int reward;
  final bool claimed;
  final bool highlight;
  final int tiers;
  final int tiersDone;
  final VoidCallback? onClaim;

  const _Card({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.progress,
    required this.target,
    required this.reward,
    required this.claimed,
    required this.onClaim,
    this.highlight = false,
    this.tiers = 0,
    this.tiersDone = 0,
  });

  @override
  Widget build(BuildContext context) {
    final frac = (progress / target).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF5B2A9E).withValues(alpha: 0.45)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onClaim != null
              ? AppColors.gold
              : Colors.white.withValues(alpha: 0.1),
          width: onClaim != null ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(
              icon,
              color: claimed ? Colors.white38 : AppColors.boardLine,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: claimed ? Colors.white54 : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: claimed ? Colors.white38 : Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: claimed ? 1 : frac,
                          minHeight: 8,
                          backgroundColor: Colors.white12,
                          color: claimed
                              ? Colors.white30
                              : const Color(0xFF6CF0B8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${progress.clamp(0, target)}/$target',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (tiers > 0) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      for (var i = 0; i < tiers; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.hexagon_rounded,
                            size: 11,
                            color: i < tiersDone
                                ? AppColors.gold
                                : Colors.white24,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimed)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF6CF0B8),
              size: 30,
            )
          else
            GestureDetector(
              onTap: onClaim,
              child: Opacity(
                opacity: onClaim != null ? 1 : 0.5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: onClaim != null
                        ? const LinearGradient(
                            colors: [Color(0xFFFFD45E), Color(0xFFF0A000)],
                          )
                        : null,
                    color: onClaim == null ? Colors.white12 : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinIcon(size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$reward',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (onClaim != null)
                        Text(
                          tr('claim'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
