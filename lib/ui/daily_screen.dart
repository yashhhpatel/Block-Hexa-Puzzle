import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/generator.dart';
import '../game/hex.dart';
import '../game/level.dart';
import '../l10n/l10n.dart';
import '../meta/cosmetics.dart';
import '../meta/quests.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'game_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Today's puzzle, the current streak, this week, streak rewards and a
/// calendar of solved days. Missed days of this month can be caught up.
class DailyScreen extends StatefulWidget {
  final Services services;
  const DailyScreen({super.key, required this.services});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen>
    with SingleTickerProviderStateMixin {
  static const _milestones = [3, 7, 14, 30];
  static const _diffColors = [
    Color(0xFF3FE0A8),
    Color(0xFF6BDB4A),
    Color(0xFF3EC9F5),
    Color(0xFFFFC93A),
    Color(0xFFFF8A2B),
    Color(0xFFFF5A4E),
    Color(0xFFC060F0),
  ];

  late final AnimationController _flame = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  Timer? _tick;
  Level? _todayLevel;

  Progress get p => widget.services.progress;

  @override
  void initState() {
    super.initState();
    // Countdown to the next puzzle; a minute's resolution is plenty.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    final now = p.now();
    final day = DateTime(now.year, now.month, now.day);
    Isolate.run(() => LevelGenerator.generateDaily(day)).then((l) {
      if (mounted) setState(() => _todayLevel = l);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _flame.dispose();
    super.dispose();
  }

  Future<void> _play(DateTime day) async {
    widget.services.sfx.play(Sound.button);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(services: widget.services, dailyDate: day),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = p.now();
    final today = DateTime(now.year, now.month, now.day);
    final solvedToday = p.isDailySolved(p.today);
    final streak = p.streak;
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Column(
            children: [
              _topBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    _hero(streak, now),
                    const SizedBox(height: 14),
                    _sectionTitle(tr('daily_this_week')),
                    _week(today),
                    const SizedBox(height: 14),
                    _todayCard(today, solvedToday),
                    const SizedBox(height: 18),
                    _sectionTitle(tr('daily_milestones')),
                    _milestoneTrack(streak),
                    const SizedBox(height: 18),
                    _sectionTitle(monthYear(today)),
                    _calendar(today),
                    const SizedBox(height: 12),
                    Text(
                      tr('daily_footer'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
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
              child: OutlinedTitle(tr('daily_puzzle'), size: 28),
            ),
          ),
          CoinPill(coins: p.coins),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.boardLine,
        fontSize: 13,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  // ---- hero: animated flame, streak and countdown ------------------------

  Widget _hero(int streak, DateTime now) {
    final best = p.stat(Stat.bestStreak);
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final left = midnight.difference(now);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A2B), Color(0xFFE0284A), Color(0xFF5B2A9E)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x55FF6A1F), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _flame,
            builder: (_, _) {
              final k = Curves.easeInOut.transform(_flame.value);
              return SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 84 + 8 * k,
                      height: 84 + 8 * k,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFE07A), Color(0xFFFF6A1F)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFC14D)
                                .withValues(alpha: 0.4 + 0.3 * k),
                            blurRadius: 18 + 10 * k,
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 1 + 0.06 * k,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                          CountUpText(
                            streak,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak == 0
                      ? tr('start_streak')
                      : tr('streak_title', {'n': streak}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('best_streak', {'n': best}),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: Colors.white, size: 15),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          tr('daily_next_in', {
                            'h': left.inHours,
                            'm': left.inMinutes % 60,
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- this week ----------------------------------------------------------

  Widget _week(DateTime today) {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final solved = p.dailySolved;
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _weekDay(
                monday.add(Duration(days: i)),
                today,
                solved,
              ),
            ),
        ],
      ),
    );
  }

  Widget _weekDay(DateTime day, DateTime today, Set<int> solved) {
    final done = solved.contains(dayKeyOf(day));
    final isToday = day == today;
    final future = day.isAfter(today);
    return Column(
      children: [
        Text(
          tr('weekday_${day.weekday}'),
          style: TextStyle(
            color: isToday ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 38,
          height: 38,
          decoration: ShapeDecoration(
            shape: const HexBorder(),
            gradient: done
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFC14D), Color(0xFFFF6A1F)],
                  )
                : null,
            color: done
                ? null
                : Colors.white.withValues(alpha: future ? 0.05 : 0.12),
            shadows: isToday
                ? const [BoxShadow(color: Color(0xAAFF4F8B), blurRadius: 12)]
                : null,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 20)
              : Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isToday
                        ? AppColors.accent
                        : (future ? Colors.white24 : Colors.white70),
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ],
    );
  }

  // ---- today's puzzle -----------------------------------------------------

  Widget _todayCard(DateTime today, bool solved) {
    final diff = today.weekday - 1;
    final level = _todayLevel;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(
          color: solved ? const Color(0xFF6CF0B8) : AppColors.accent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // A miniature of today's actual board.
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [p.theme.bgTop, p.theme.bgBottom],
                  ),
                ),
                child: level == null
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.boardLine,
                          ),
                        ),
                      )
                    : CustomPaint(
                        painter: _MiniBoardPainter(
                          level,
                          p.theme,
                          solved: solved,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('todays_puzzle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      shortDate(today),
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _pill(tr('diff_$diff'), _diffColors[diff]),
                        if (level != null)
                          _pill(
                            tr('daily_blocks', {
                              'n': level.pieces.length,
                              'c': level.board.length,
                            }),
                            Colors.white24,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (solved)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF6CF0B8)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tr('daily_solved_msg'),
                          style: const TextStyle(
                            color: Color(0xFF6CF0B8),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _rewardChip(
                        const CoinIcon(size: 16),
                        '+${Progress.dailyReward}',
                      ),
                      _rewardChip(
                        const Icon(Icons.local_fire_department_rounded,
                            color: Color(0xFFFF8A2B), size: 16),
                        '+1',
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              PillButton(
                label: solved ? tr('replay') : tr('play'),
                width: 128,
                icon: solved ? Icons.replay_rounded : Icons.play_arrow_rounded,
                color: solved ? AppColors.button : AppColors.accent,
                dark: solved ? AppColors.buttonDark : AppColors.accentDark,
                onTap: () => _play(today),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.9)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _rewardChip(Widget icon, String text) => Container(
    padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  // ---- streak rewards -----------------------------------------------------

  Widget _milestoneTrack(int streak) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final frac = (streak / _milestones.last).clamp(0.0, 1.0);
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: frac),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Container(
                        height: 6,
                        width: (c.maxWidth - 36) * v,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFC14D), Color(0xFFFF6A1F)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final m in _milestones) _milestoneNode(m, streak),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final m in _milestones)
                SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      Text(
                        tr('days_n', {'n': m}),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinIcon(size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '+${Progress.streakBonusFor(m)}',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _milestoneNode(int m, int streak) {
    final reached = streak >= m;
    return SizedBox(
      width: 64,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: ShapeDecoration(
            shape: const HexBorder(),
            gradient: reached
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE07A), Color(0xFFFF8A2B)],
                  )
                : null,
            color: reached ? null : const Color(0xFF2A3566),
          ),
          alignment: Alignment.center,
          child: Icon(
            reached ? Icons.check_rounded : Icons.card_giftcard_rounded,
            color: reached ? Colors.white : Colors.white54,
            size: 18,
          ),
        ),
      ),
    );
  }

  // ---- calendar -----------------------------------------------------------

  Widget _calendar(DateTime today) {
    final first = DateTime(today.year, today.month, 1);
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday-first
    final solved = p.dailySolved;
    final heads = [for (var i = 1; i <= 7; i++) tr('weekday_$i')];
    return _Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              for (final h in heads)
                Expanded(
                  child: Center(
                    child: Text(
                      h,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox(),
              for (var d = 1; d <= daysInMonth; d++)
                _dayCell(DateTime(today.year, today.month, d), today, solved),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, DateTime today, Set<int> solved) {
    final isSolved = solved.contains(dayKeyOf(day));
    final isToday = day == today;
    final future = day.isAfter(today);
    final missed = !isSolved && !future && !isToday;
    return Pressable(
      pressedScale: 0.88,
      onTap: future ? null : () => _play(day),
      child: Container(
        decoration: ShapeDecoration(
          shape: const HexBorder(),
          gradient: isSolved
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFC14D), Color(0xFFFF6A1F)],
                )
              : isToday
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFF8DB5), AppColors.accent],
                )
              : null,
          color: isSolved || isToday
              ? null
              : Colors.white.withValues(alpha: future ? 0.04 : 0.12),
          shadows: isToday
              ? const [BoxShadow(color: Color(0xAAFF4F8B), blurRadius: 10)]
              : null,
        ),
        alignment: Alignment.center,
        child: isSolved
            ? const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 18,
              )
            : Text(
                '${day.day}',
                style: TextStyle(
                  color: future
                      ? Colors.white24
                      : (missed ? Colors.white70 : Colors.white),
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

/// Today's board in miniature: the outline only, ticked off once solved.
class _MiniBoardPainter extends CustomPainter {
  final Level level;
  final BoardTheme theme;
  final bool solved;
  _MiniBoardPainter(this.level, this.theme, {required this.solved});

  @override
  void paint(Canvas canvas, Size size) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final h in level.board) {
      final q = h.toPixel(1);
      minX = math.min(minX, q.dx - 1);
      maxX = math.max(maxX, q.dx + 1);
      minY = math.min(minY, q.dy - 0.87);
      maxY = math.max(maxY, q.dy + 0.87);
    }
    final s = math.min(
      size.width * 0.86 / (maxX - minX),
      size.height * 0.86 / (maxY - minY),
    );
    final origin =
        size.center(Offset.zero) - Offset((minX + maxX) / 2 * s, (minY + maxY) / 2 * s);
    final fill = Paint()
      ..color = solved
          ? const Color(0xFF6CF0B8).withValues(alpha: 0.35)
          : theme.cell;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, s * 0.1)
      ..color = theme.line.withValues(alpha: 0.9);
    for (final h in level.board) {
      final path = hexPath(origin + h.toPixel(s), s * 0.96, roundness: 0.12);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_MiniBoardPainter old) =>
      old.level != level || old.theme != theme || old.solved != solved;
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}
