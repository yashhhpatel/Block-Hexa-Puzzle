import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/generator.dart';
import '../game/level.dart';
import '../l10n/l10n.dart';
import '../services/ads.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'board_view.dart';
import 'theme.dart';
import 'widgets.dart';
import 'win_overlay.dart' show formatTime;

/// Time Attack: solve as many puzzles as possible before the clock runs
/// out. Each solve adds a little time and the puzzles get harder.
class TimeAttackScreen extends StatefulWidget {
  final Services services;
  const TimeAttackScreen({super.key, required this.services});

  static const startSeconds = 120;
  static const bonusSeconds = 12;
  static const coinsPerPuzzle = 3;

  /// Difficulty of the [solved]-th puzzle, as a level number.
  static int difficultyFor(int solved) => math.min(140, 6 + solved * 5);

  @override
  State<TimeAttackScreen> createState() => _TimeAttackScreenState();
}

enum _Phase { intro, playing, finished }

class _TimeAttackScreenState extends State<TimeAttackScreen>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.intro;
  GameState? _game;
  final _boardKey = GlobalKey<BoardViewState>();
  final _rng = math.Random();
  Future<Level>? _next;

  /// Time left = budget - elapsed; the stopwatch pauses with the app.
  final _clock = Stopwatch();
  int _budgetMs = TimeAttackScreen.startSeconds * 1000;
  Timer? _tick;
  int _solved = 0;
  bool _newBest = false;
  int _bonusFlash = 0; // counts up so the "+12s" pop restarts each time

  Progress get p => widget.services.progress;
  Sfx get sfx => widget.services.sfx;

  int get _leftMs => math.max(0, _budgetMs - _clock.elapsedMilliseconds);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _game?.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_phase != _Phase.playing) return;
    if (state == AppLifecycleState.resumed) {
      _clock.start();
    } else {
      _clock.stop();
    }
  }

  // Static so the isolate closure captures only its arguments.
  static Future<Level> _build(int seed, int difficulty) =>
      Isolate.run(() => LevelGenerator.generateFree(seed, difficulty));

  Future<Level> _make(int solved) {
    final d = TimeAttackScreen.difficultyFor(solved);
    final seed = _rng.nextInt(1 << 30);
    // Easy puzzles are instant; harder ones are built off the UI thread.
    return d < LevelGenerator.uniqueFromLevel
        ? Future.value(LevelGenerator.generateFree(seed, d))
        : _build(seed, d);
  }

  Future<void> _start() async {
    sfx.play(Sound.button);
    _solved = 0;
    _newBest = false;
    _budgetMs = TimeAttackScreen.startSeconds * 1000;
    _clock
      ..stop()
      ..reset();
    final first = await _make(0);
    if (!mounted) return;
    _next = _make(1);
    _setGame(first);
    setState(() => _phase = _Phase.playing);
    _clock.start();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_phase == _Phase.playing && _leftMs <= 0) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  void _setGame(Level level) {
    _game?.removeListener(_onChanged);
    final g = GameState(level)..addListener(_onChanged);
    _game = g;
  }

  Future<void> _onChanged() async {
    final g = _game;
    if (g == null || !g.isComplete || _phase != _Phase.playing) {
      if (mounted) setState(() {});
      return;
    }
    // Solved: bank it, add time, move straight on to the next puzzle.
    _solved++;
    _budgetMs += TimeAttackScreen.bonusSeconds * 1000;
    _bonusFlash++;
    sfx.play(Sound.star);
    p.recordBlocksPlaced(g.blocksPlaced);
    _boardKey.currentState?.celebrate();
    final next = _next ?? _make(_solved);
    _next = _make(_solved + 1);
    final level = await next;
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted || _phase != _Phase.playing) return;
    setState(() => _setGame(level));
  }

  Future<void> _finish() async {
    if (_phase != _Phase.playing) return;
    _clock.stop();
    _tick?.cancel();
    setState(() => _phase = _Phase.finished);
    sfx.play(Sound.win);
    final g = _game;
    if (g != null) p.recordBlocksPlaced(g.blocksPlaced);
    _newBest = await p.recordTimeAttack(_solved);
    await p.addCoins(_solved * TimeAttackScreen.coinsPerPuzzle);
    // A full-screen ad only after a real run, before the results.
    if (_solved > 0) await widget.services.ads.showInterstitial();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _header(),
                  Expanded(
                    child: switch (_phase) {
                      _Phase.intro => _intro(),
                      _ => _game == null
                          ? const SizedBox()
                          : BoardView(
                              key: _boardKey,
                              game: _game!,
                              skin: p.skin.style,
                              theme: p.theme,
                              patterns: p.colorBlind,
                              onPick: () => sfx.play(Sound.pick),
                              onPlace: () => sfx.play(Sound.place),
                              onFail: () => sfx.play(Sound.fail),
                            ),
                    },
                  ),
                  if (_phase == _Phase.playing) _bottomBar(),
                  AdBanner(ads: widget.services.ads),
                ],
              ),
              if (_phase == _Phase.finished) _results(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final secs = (_leftMs / 1000).ceil();
    final hurry = _phase == _Phase.playing && secs <= 10;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
      child: Row(
        children: [
          RoundButton(
            icon: Icons.arrow_back_rounded,
            size: 44,
            semanticLabel: tr('back'),
            onTap: () {
              sfx.play(Sound.button);
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: OutlinedTitle(tr('time_attack'), size: 26),
            ),
          ),
          if (_phase == _Phase.playing) ...[
            _chip(
              Icons.check_circle_rounded,
              '$_solved',
              const Color(0xFF6CF0B8),
            ),
            const SizedBox(width: 6),
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: hurry && secs.isOdd ? 1.12 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: _chip(
                    Icons.timer_rounded,
                    formatTime(secs),
                    hurry ? const Color(0xFFFF5A4E) : AppColors.gold,
                  ),
                ),
                if (_bonusFlash > 0)
                  Positioned(
                    right: 0,
                    top: -16,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_bonusFlash),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1100),
                      builder: (_, v, _) => Opacity(
                        opacity: (1 - v).clamp(0, 1),
                        child: Transform.translate(
                          offset: Offset(0, -14 * v),
                          child: Text(
                            tr('ta_bonus', {'n': TimeAttackScreen.bonusSeconds}),
                            style: const TextStyle(
                              color: Color(0xFF6CF0B8),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ] else
            CoinPill(coins: p.coins),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _intro() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const ShapeDecoration(
                shape: HexBorder(),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB08CFF), Color(0xFF7A55F0), Color(0xFF4A2BB0)],
                ),
                shadows: [BoxShadow(color: Color(0x887A55F0), blurRadius: 30)],
              ),
              child: const Icon(Icons.timer_rounded, color: Colors.white, size: 62),
            ),
            const SizedBox(height: 18),
            Text(
              tr('ta_desc', {
                'm': TimeAttackScreen.startSeconds ~/ 60,
                's': TimeAttackScreen.bonusSeconds,
              }),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr('ta_best', {'n': p.timeAttackBest}),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 22),
            PillButton(
              label: tr('ta_start'),
              icon: Icons.play_arrow_rounded,
              width: 200,
              color: const Color(0xFF7A55F0),
              dark: const Color(0xFF4A2BB0),
              onTap: _start,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final g = _game;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      color: Colors.black.withValues(alpha: 0.25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Opacity(
            opacity: g != null && g.canUndo ? 1 : 0.45,
            child: RoundButton(
              icon: Icons.undo_rounded,
              size: 48,
              semanticLabel: tr('undo'),
              onTap: () {
                if (g == null || !g.canUndo) return;
                sfx.play(Sound.undo);
                g.undo();
              },
            ),
          ),
          RoundButton(
            icon: Icons.refresh_rounded,
            size: 48,
            semanticLabel: tr('restart'),
            onTap: () {
              if (g == null || g.isComplete) return;
              sfx.play(Sound.button);
              g.reset();
            },
          ),
          RoundButton(
            icon: Icons.flag_rounded,
            size: 48,
            semanticLabel: tr('ta_end'),
            color: const Color(0xFFFF5A4E),
            dark: const Color(0xFFB0261C),
            onTap: _finish,
          ),
        ],
      ),
    );
  }

  Widget _results() {
    final coins = _solved * TimeAttackScreen.coinsPerPuzzle;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF0233F9A), Color(0xF20E1A4A)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedTitle(tr('ta_time_up'), size: 32),
              const SizedBox(height: 12),
              CountUpText(
                _solved,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                tr('ta_solved'),
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 10),
              if (_newBest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: Text(
                    tr('ta_new_best'),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                Text(
                  tr('ta_best', {'n': p.timeAttackBest}),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (coins > 0) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 24),
                    const SizedBox(width: 6),
                    Text(
                      '+$coins',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundButton(
                    icon: Icons.home_rounded,
                    semanticLabel: tr('home'),
                    onTap: () {
                      sfx.play(Sound.button);
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                  const SizedBox(width: 14),
                  PillButton(
                    label: tr('ta_play_again'),
                    icon: Icons.replay_rounded,
                    width: 180,
                    color: const Color(0xFF7A55F0),
                    dark: const Color(0xFF4A2BB0),
                    onTap: _start,
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
