import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../meta/quests.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'game_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Today's puzzle, the current streak and a calendar of solved days.
class DailyScreen extends StatefulWidget {
  final Services services;
  const DailyScreen({super.key, required this.services});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  Progress get p => widget.services.progress;

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
              _topBar(context, tr('daily_puzzle')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  children: [
                    _streakCard(streak),
                    const SizedBox(height: 14),
                    _todayCard(today, solvedToday),
                    const SizedBox(height: 18),
                    OutlinedTitle(monthYear(today), size: 22),
                    const SizedBox(height: 8),
                    _calendar(today),
                    const SizedBox(height: 10),
                    Text(
                      'Solve today\'s puzzle to grow your streak. Missed a day this month? '
                      'Tap it to catch up for half the coins.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
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

  Widget _topBar(BuildContext context, String title) {
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
              child: OutlinedTitle(title, size: 28),
            ),
          ),
          CoinPill(coins: p.coins),
        ],
      ),
    );
  }

  Widget _streakCard(int streak) {
    final best = p.stat(Stat.bestStreak);
    final nextMilestone = streak < 3
        ? 3
        : streak < 7
        ? 7
        : streak < 14
        ? 14
        : (streak ~/ 30 + 1) * 30;
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFFFC14D), Color(0xFFFF6A1F)],
              ),
              boxShadow: [BoxShadow(color: Color(0x88FF8A2B), blurRadius: 18)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                Text(
                  '$streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
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
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('next_bonus', {
                    'n': nextMilestone,
                    'c': Progress.streakBonusFor(nextMilestone),
                  }),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  tr('best_streak', {'n': best}),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayCard(DateTime today, bool solved) {
    return _Panel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('todays_puzzle'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('difficulty', {'d': tr('diff_${today.weekday - 1}')}),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  solved
                      ? tr('daily_solved_msg')
                      : tr('daily_reward_msg', {'n': Progress.dailyReward}),
                  style: TextStyle(
                    color: solved ? const Color(0xFF6CF0B8) : AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PillButton(
            label: solved ? tr('replay') : tr('play'),
            width: 110,
            icon: solved ? Icons.replay_rounded : Icons.play_arrow_rounded,
            color: solved ? AppColors.button : AppColors.accent,
            dark: solved ? AppColors.buttonDark : AppColors.accentDark,
            onTap: () => _play(today),
          ),
        ],
      ),
    );
  }

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
    final key = dayKeyOf(day);
    final isSolved = solved.contains(key);
    final isToday = day == today;
    final future = day.isAfter(today);
    Color bg;
    if (isSolved) {
      bg = const Color(0xFFFF8A2B);
    } else if (isToday) {
      bg = AppColors.accent;
    } else if (future) {
      bg = Colors.white.withValues(alpha: 0.04);
    } else {
      bg = Colors.white.withValues(alpha: 0.12);
    }
    return GestureDetector(
      onTap: future ? null : () => _play(day),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: Colors.white, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: isSolved
            ? const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 20,
              )
            : Text(
                '${day.day}',
                style: TextStyle(
                  color: future ? Colors.white24 : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
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
