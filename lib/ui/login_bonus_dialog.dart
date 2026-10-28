import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'theme.dart';
import 'widgets.dart';

/// Shows the 7-day login reward track if today's reward is unclaimed.
Future<void> maybeShowLoginBonus(
  BuildContext context,
  Services services,
) async {
  final day = services.progress.pendingLoginDay;
  if (day == null) return;
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: tr('login_title'),
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => _LoginBonus(services: services, day: day),
    transitionBuilder: (_, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: child,
    ),
  );
}

class _LoginBonus extends StatelessWidget {
  final Services services;
  final int day;
  const _LoginBonus({required this.services, required this.day});

  @override
  Widget build(BuildContext context) {
    const rewards = Progress.loginRewards;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 330,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF233F9A), Color(0xFF15276A)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.gold, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedTitle(tr('login_title'), size: 28),
              const SizedBox(height: 4),
              Text(
                tr('login_sub'),
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < rewards.length; i++)
                    _DayTile(
                      day: i + 1,
                      coins: rewards[i],
                      state: i < day ? 0 : (i == day ? 1 : 2),
                      big: i == rewards.length - 1,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              PillButton(
                label: tr('claim_n', {'n': rewards[day]}),
                icon: Icons.card_giftcard_rounded,
                width: 200,
                onTap: () async {
                  await services.progress.claimLoginBonus();
                  services.sfx.play(Sound.coin);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final int day;
  final int coins;
  final int state; // 0 claimed, 1 today, 2 upcoming
  final bool big;
  const _DayTile({
    required this.day,
    required this.coins,
    required this.state,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final today = state == 1;
    return Container(
      width: big ? 140 : 66,
      height: 78,
      decoration: BoxDecoration(
        color: today
            ? AppColors.gold.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: state == 0 ? 0.35 : 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: today ? AppColors.gold : Colors.white.withValues(alpha: 0.15),
          width: today ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tr('day_n', {'n': day}),
            style: TextStyle(
              color: today ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          state == 0
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF6CF0B8),
                  size: 26,
                )
              : CoinIcon(size: big ? 30 : 24),
          const SizedBox(height: 2),
          Text(
            '$coins',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
