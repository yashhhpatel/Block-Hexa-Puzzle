import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../meta/chapters.dart';
import '../meta/quests.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'theme.dart';
import 'widgets.dart';

/// Lifetime statistics, grouped into Progress, Daily, Skill and Activity.
class StatsScreen extends StatelessWidget {
  final Services services;
  const StatsScreen({super.key, required this.services});

  Progress get p => services.progress;

  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return tr('st_time_hm', {'h': h, 'm': m});
  }

  static String clock(double seconds) {
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final highest = (p.unlockedLevel - 1).clamp(0, 1 << 30);
    final (achDone, achTotal) = p.achievementTiers;
    final avg = p.averageClearSeconds;
    final sections = <(String, List<_Stat>)>[
      (
        tr('st_progress'),
        [
          _Stat(Icons.flag_rounded, tr('st_levels_cleared'), p.stat(Stat.levelsCleared)),
          _Stat(Icons.star_rounded, tr('st_total_stars'), p.totalStars,
              color: AppColors.gold),
          _Stat(Icons.auto_awesome_rounded, tr('st_three_star'),
              p.stat(Stat.threeStarLevels)),
          _Stat(Icons.emoji_events_rounded, tr('st_chapters'),
              p.stat(Stat.chaptersCompleted)),
          _Stat(Icons.workspace_premium_rounded, tr('st_achievements'), achDone,
              suffix: '/$achTotal'),
        ],
      ),
      (
        tr('st_daily'),
        [
          _Stat(Icons.local_fire_department_rounded, tr('st_current_streak'),
              p.streak, color: const Color(0xFFFF8A2B)),
          _Stat(Icons.whatshot_rounded, tr('st_best_streak'),
              p.stat(Stat.bestStreak), color: const Color(0xFFFF8A2B)),
          _Stat(Icons.calendar_month_rounded, tr('st_daily_solved'),
              p.stat(Stat.dailyPlayed)),
          _Stat(Icons.wb_sunny_rounded, tr('st_daily_perfect'),
              p.stat(Stat.dailyPerfect)),
        ],
      ),
      (
        tr('st_skill'),
        [
          _Stat(Icons.timer_rounded, tr('st_avg_time'), null,
              text: avg == null ? '–' : clock(avg)),
          _Stat(Icons.bolt_rounded, tr('st_fast'), p.stat(Stat.fastClears)),
          _Stat(Icons.psychology_rounded, tr('st_no_hint'),
              p.stat(Stat.noHintClears)),
          _Stat(Icons.lightbulb_rounded, tr('st_hints_used'),
              p.stat(Stat.hintsUsed)),
        ],
      ),
      (
        tr('st_activity'),
        [
          _Stat(Icons.hourglass_bottom_rounded, tr('st_time_played'), null,
              text: duration(p.stat(Stat.playSeconds))),
          _Stat(Icons.event_available_rounded, tr('st_days_played'),
              p.stat(Stat.loginDays)),
          _Stat(Icons.hexagon_rounded, tr('st_blocks'), p.stat(Stat.blocksPlaced)),
          _Stat(Icons.task_alt_rounded, tr('st_quests'),
              p.stat(Stat.questsCompleted)),
          _Stat(Icons.inventory_2_rounded, tr('st_chests'),
              p.stat(Stat.chestsOpened)),
        ],
      ),
    ];

    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: Row(
                  children: [
                    RoundButton(
                      icon: Icons.arrow_back_rounded,
                      size: 44,
                      semanticLabel: tr('back'),
                      onTap: () {
                        services.sfx.play(Sound.button);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: OutlinedTitle(tr('statistics'), size: 28),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _HeroCard(level: highest, progress: p),
                    for (final (title, stats) in sections) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.boardLine,
                            fontSize: 13,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.55,
                        children: [for (final s in stats) _StatTile(stat: s)],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat {
  final IconData icon;
  final String label;
  final int? value;
  final String? text;
  final String suffix;
  final Color color;
  const _Stat(
    this.icon,
    this.label,
    this.value, {
    this.text,
    this.suffix = '',
    this.color = AppColors.boardLine,
  });
}

class _StatTile extends StatelessWidget {
  final _Stat stat;
  const _StatTile({required this.stat});

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w900,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(stat.icon, color: stat.color, size: 22),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (stat.value != null)
                  CountUpTextFrom(stat.value!, style: valueStyle)
                else
                  Text(stat.text ?? '', style: valueStyle),
                if (stat.suffix.isNotEmpty)
                  Text(
                    stat.suffix,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            stat.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Counts up from zero when the page opens.
class CountUpTextFrom extends StatelessWidget {
  final int value;
  final TextStyle style;
  const CountUpTextFrom(this.value, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('${v.round()}', style: style),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int level;
  final Progress progress;
  const _HeroCard({required this.level, required this.progress});

  @override
  Widget build(BuildContext context) {
    final chapter = Chapters.forLevel(progress.unlockedLevel);
    final done = (progress.unlockedLevel - chapter.first).clamp(0, chapter.count);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [chapter.color.withValues(alpha: 0.55), const Color(0xFF15276A)],
        ),
        border: Border.all(color: chapter.color, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: ShapeDecoration(
              shape: const HexBorder(),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(chapter.color, Colors.white, 0.35)!,
                  chapter.color,
                  Color.lerp(chapter.color, Colors.black, 0.3)!,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: CountUpTextFrom(
                  level,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('st_highest_level'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  chapter.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: done / chapter.count),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 9,
                      backgroundColor: Colors.white12,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$done/${chapter.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
