"""One-off helper: swaps English UI literals for tr() lookups."""
import re, sys

def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        if a not in s:
            sys.exit(f'{path}: not found: {a!r}')
        s = s.replace(a, b)
    if "import '../l10n/l10n.dart';" not in s:
        s = s.replace("import 'package:flutter/material.dart';\n",
                      "import 'package:flutter/material.dart';\n\nimport '../l10n/l10n.dart';\n", 1)
    open(path, 'w', encoding='utf-8').write(s)

d = open('lib/ui/daily_screen.dart', encoding='utf-8').read()
d = re.sub(r"  static const _difficulty = \[[^\]]*\];\n", "", d)
d = re.sub(r"  static const _months = \[[^\]]*\];\n", "", d)
d = re.sub(r"'Solve today\'s puzzle[^\n]*\n\s*'Tap it to catch up for half the coins\.'", "tr('daily_footer')", d)
open('lib/ui/daily_screen.dart', 'w', encoding='utf-8').write(d)

patch('lib/ui/daily_screen.dart', [
    ("'Daily Puzzle'", "tr('daily_puzzle')"),
    ("'${_months[today.month - 1]} ${today.year}'", "monthYear(today)"),
    ("'Back'", "tr('back')"),
    ("'Start a streak today!'", "tr('start_streak')"),
    ("'$streak-day streak'", "tr('streak_title', {'n': streak})"),
    ("'Next bonus at $nextMilestone days (+${Progress.streakBonusFor(nextMilestone)})'",
     "tr('next_bonus', {'n': nextMilestone, 'c': Progress.streakBonusFor(nextMilestone)})"),
    ("'Best: $best days'", "tr('best_streak', {'n': best})"),
    ('"Today\'s puzzle"', "tr('todays_puzzle')"),
    ("'Difficulty: ${_difficulty[today.weekday - 1]}'", "tr('difficulty', {'d': tr('diff_${today.weekday - 1}')})"),
    ("'Solved! Come back tomorrow.'", "tr('daily_solved_msg')"),
    ("'Reward: ${Progress.dailyReward} coins + streak'", "tr('daily_reward_msg', {'n': Progress.dailyReward})"),
    ("solved ? 'Replay' : 'Play'", "solved ? tr('replay') : tr('play')"),
    ("const heads = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];", "final heads = [for (var i = 1; i <= 7; i++) tr('weekday_$i')];"),
])
patch('lib/ui/quests_screen.dart', [
    ("'Back'", "tr('back')"),
    ("'Quests'", "tr('quests_title')"),
    ("Tab(text: 'Daily')", "Tab(text: tr('tab_daily'))"),
    ("Tab(text: 'Achievements')", "Tab(text: tr('tab_achievements'))"),
    ("'New quests in ${left.inHours}h ${left.inMinutes % 60}m'", "tr('new_quests_in', {'h': left.inHours, 'm': left.inMinutes % 60})"),
    ("'Complete all daily quests'", "tr('all_quests')"),
    ("'CLAIM'", "tr('claim')"),
])
patch('lib/ui/shop_screen.dart', [
    ("'Collect ${item.starsRequired} stars to unlock ${item.name}.'", "tr('need_stars', {'n': item.starsRequired, 'name': item.name})"),
    ("'Not enough coins yet. Clear levels and quests to earn more!'", "tr('shop_no_coins')"),
    ("'Back'", "tr('back')"),
    ("'Shop'", "tr('shop_title')"),
    ("Tab(text: 'Blocks')", "Tab(text: tr('tab_blocks'))"),
    ("Tab(text: 'Themes')", "Tab(text: tr('tab_themes'))"),
    ("label: 'In use'", "label: tr('in_use')"),
    ("label: 'Use'", "label: tr('use')"),
])
patch('lib/ui/chapters_screen.dart', [
    ("'Chapters'", "tr('chapters_title')"),
    ("'Back'", "tr('back')"),
    ("'Levels ${c.first}–${c.last}'", "tr('levels_range', {'a': c.first, 'b': c.last})"),
])
patch('lib/ui/login_bonus_dialog.dart', [
    ("'Daily reward'", "tr('login_title')"),
    ("'Daily Reward'", "tr('login_title')"),
    ("'Come back every day for bigger rewards!'", "tr('login_sub')"),
    ("'Claim ${rewards[day]}'", "tr('claim_n', {'n': rewards[day]})"),
    ("'Day $day'", "tr('day_n', {'n': day})"),
])
print('ok')
