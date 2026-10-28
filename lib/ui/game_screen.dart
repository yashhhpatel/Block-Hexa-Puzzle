import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/generator.dart';
import '../config.dart';
import '../game/level.dart';
import '../l10n/l10n.dart';
import '../meta/chapters.dart';
import '../services/ads.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'board_view.dart';
import 'settings_dialog.dart';
import 'theme.dart';
import 'widgets.dart';

/// Plays either a main level ([level]) or a Daily Puzzle ([dailyDate]).
class GameScreen extends StatefulWidget {
  final Services services;
  final int? level;
  final DateTime? dailyDate;

  const GameScreen({
    super.key,
    required this.services,
    this.level,
    this.dailyDate,
  }) : assert((level == null) != (dailyDate == null));

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GameState? _game;
  final _boardKey = GlobalKey<BoardViewState>();
  final _clock = Stopwatch();
  Timer? _ticker;
  WinSummary? _win;
  bool _showWin = false;
  bool _blocksRecorded = false;
  bool _winning = false;
  String? _tip;
  Timer? _tipTimer;
  int _loadToken = 0;

  Progress get progress => widget.services.progress;
  Sfx get sfx => widget.services.sfx;
  bool get _isDaily => widget.dailyDate != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isDaily) {
      _loadDaily(widget.dailyDate!);
    } else {
      _loadLevel(widget.level!, restore: true);
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _clock.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordBlocks();
    _ticker?.cancel();
    _tipTimer?.cancel();
    _game?.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The clock only runs while the player can actually see the board.
    if (state == AppLifecycleState.resumed) {
      if (_game != null && !_game!.isComplete) _clock.start();
    } else {
      _clock.stop();
    }
  }

  // ---- loading ------------------------------------------------------------

  Future<void> _loadLevel(int n, {bool restore = false}) async {
    final token = ++_loadToken;
    _detach();
    // Small levels are instant; bigger ones are built off the UI thread.
    final level = n < LevelGenerator.uniqueFromLevel
        ? LevelGenerator.generate(n)
        : await Isolate.run(() => LevelGenerator.generate(n));
    if (!mounted || token != _loadToken) return;
    final game = GameState(level);
    if (restore) {
      final saved = progress.savedBoard;
      if (saved != null) game.restore(saved);
    }
    progress.setCurrentLevel(n);
    _attach(game);

    if (n == 1 && !progress.tutorialSeen) {
      _tip = tr('tip_drag');
    } else if (level.hasDecoys && !progress.decoyTipSeen) {
      _showTip(tr('tip_tricky'));
      progress.setDecoyTipSeen();
    }
    setState(() {});
  }

  Future<void> _loadDaily(DateTime day) async {
    final token = ++_loadToken;
    _detach();
    final level = await Isolate.run(() => LevelGenerator.generateDaily(day));
    if (!mounted || token != _loadToken) return;
    _attach(GameState(level));
    setState(() {});
  }

  void _detach() {
    _recordBlocks();
    _game?.removeListener(_onChanged);
    _game = null;
    _win = null;
    _winning = false;
    _showWin = false;
    _blocksRecorded = false;
    _tipTimer?.cancel();
    _tip = null;
    _clock
      ..stop()
      ..reset();
  }

  void _attach(GameState game) {
    game.addListener(_onChanged);
    _game = game;
    _clock.start();
  }

  void _showTip(String text) {
    _tip = text;
    _tipTimer?.cancel();
    _tipTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _tip = null);
    });
  }

  void _recordBlocks() {
    final g = _game;
    if (g == null || _blocksRecorded) return;
    _blocksRecorded = true;
    progress.recordBlocksPlaced(g.blocksPlaced);
  }

  // ---- play ---------------------------------------------------------------

  void _onChanged() {
    final g = _game!;
    if (g.isComplete) {
      _onWin(g);
    } else if (!g.level.isDaily) {
      progress.saveBoard(g.toJson());
    }
    setState(() {});
  }

  Future<void> _onWin(GameState g) async {
    if (_winning) return;
    _winning = true;
    _clock.stop();
    _tip = null;
    _recordBlocks();
    final seconds = _clock.elapsed.inSeconds;
    if (g.level.number == 1) progress.setTutorialSeen();
    final summary = g.level.isDaily
        ? await progress.recordDailyWin(
            g.level,
            seconds: seconds,
            hintsUsed: g.hintsUsed,
          )
        : await progress.recordLevelWin(
            g.level,
            seconds: seconds,
            hintsUsed: g.hintsUsed,
          );
    if (!mounted || _game != g) return;
    _win = summary;
    _boardKey.currentState?.celebrate();
    sfx.play(Sound.win);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted || _game != g) return;
    await _maybeInterstitial(g.level);
    if (mounted && _game == g) setState(() => _showWin = true);
  }

  /// Interstitial before the win screen: after every Daily Puzzle, and after
  /// every [kInterstitialEveryLevels] completed levels.
  Future<void> _maybeInterstitial(Level level) async {
    final ads = widget.services.ads;
    if (level.isDaily) {
      await ads.showInterstitial();
      return;
    }
    final count = progress.levelsSinceAd + 1;
    if (count >= kInterstitialEveryLevels && await ads.showInterstitial()) {
      await progress.setLevelsSinceAd(0);
    } else {
      // Not shown (none loaded, offline, subscriber): try again next win.
      await progress.setLevelsSinceAd(count);
    }
  }

  void _next() {
    sfx.play(Sound.button);
    if (_isDaily) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _loadLevel(_game!.level.number + 1));
  }

  void _replay() {
    sfx.play(Sound.button);
    if (_isDaily) {
      setState(() => _loadDaily(widget.dailyDate!));
    } else {
      setState(() => _loadLevel(_game!.level.number));
    }
  }

  void _restart() {
    final g = _game;
    if (g == null || g.isComplete) return;
    sfx.play(Sound.button);
    g.reset();
  }

  void _undo() {
    final g = _game;
    if (g == null || g.isComplete || !g.canUndo) return;
    sfx.play(Sound.undo);
    g.undo();
  }

  bool _hintBusy = false;

  /// One free hint per level; after that, one rewarded video = one hint.
  Future<void> _hint() async {
    final g = _game;
    if (g == null || g.isComplete || _hintBusy) return;
    if (g.freeHintAvailable) {
      _giveHint(g);
      return;
    }
    sfx.play(Sound.button);
    final watch = await _confirmVideo();
    if (watch != true || !mounted || _game != g || g.isComplete) return;

    final ads = widget.services.ads;
    if (!ads.rewardedReady) {
      ads.preloadRewarded();
      _snack(tr('hint_ad_unavailable'));
      return;
    }
    _hintBusy = true;
    _clock.stop(); // the video doesn't count against the target time
    final earned = await ads.showRewarded();
    _hintBusy = false;
    if (!mounted || _game != g) return;
    if (!g.isComplete) _clock.start();
    if (earned) {
      _giveHint(g);
    } else {
      sfx.play(Sound.fail);
      _snack(tr('hint_ad_incomplete'));
    }
  }

  void _giveHint(GameState g) {
    if (g.applyHint() != null) sfx.play(Sound.hint);
    setState(() {});
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
      );
  }

  Future<bool?> _confirmVideo() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15276A),
        icon: const Icon(
          Icons.ondemand_video_rounded,
          color: AppColors.gold,
          size: 40,
        ),
        title: Text(
          tr('hint_watch_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          tr('hint_watch_body'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(tr('hint_watch_btn')),
          ),
        ],
      ),
    );
  }

  // ---- ui -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return Scaffold(
      body: GameBackground(
        animate: progress.backgroundFx,
        theme: progress.theme,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _header(g),
                  Expanded(
                    child: g == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.boardLine,
                            ),
                          )
                        : BoardView(
                            key: _boardKey,
                            game: g,
                            skin: progress.skin.style,
                            theme: progress.theme,
                            onPick: () => sfx.play(Sound.pick),
                            onPlace: () => sfx.play(Sound.place),
                            onFail: () => sfx.play(Sound.fail),
                          ),
                  ),
                  _bottomBar(g),
                  AdBanner(ads: widget.services.ads),
                ],
              ),
              if (_tip != null) _tipBanner(_tip!),
              if (_showWin && g != null && _win != null)
                _WinOverlay(
                  level: g.level,
                  summary: _win!,
                  seconds: _clock.elapsed.inSeconds,
                  sfx: sfx,
                  onNext: _next,
                  onReplay: _replay,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(GameState? g) {
    final level = g?.level;
    final title = _isDaily
        ? tr('daily_title', {'date': shortDate(widget.dailyDate!)})
        : tr('level_n', {'n': level?.number ?? widget.level!});
    final secs = _clock.elapsed.inSeconds;
    final par = level?.parSeconds;
    final chapter = level != null && !level.isDaily
        ? Chapters.forLevel(level.number)
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedTitle(title, size: 28),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (chapter != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: chapter.color.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: chapter.color.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Text(
                          '${chapter.name} ${chapter.positionOf(level!.number)}/${chapter.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (par != null) _ParClock(seconds: secs, par: par),
                  ],
                ),
              ],
            ),
          ),
          CoinPill(coins: progress.coins),
        ],
      ),
    );
  }

  Widget _bottomBar(GameState? g) {
    const size = 48.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      color: Colors.black.withValues(alpha: 0.25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundButton(
            icon: Icons.arrow_back_rounded,
            size: size,
            semanticLabel: tr('back'),
            onTap: () {
              sfx.play(Sound.button);
              Navigator.of(context).pop();
            },
          ),
          RoundButton(
            icon: Icons.settings_rounded,
            size: size,
            semanticLabel: tr('settings'),
            onTap: () async {
              sfx.play(Sound.button);
              _clock.stop();
              await showSettingsDialog(context, widget.services);
              if (mounted && _game != null && !_game!.isComplete) {
                _clock.start();
              }
              if (mounted) setState(() {});
            },
          ),
          Opacity(
            opacity: g != null && g.canUndo && !g.isComplete ? 1 : 0.45,
            child: RoundButton(
              icon: Icons.undo_rounded,
              size: size,
              semanticLabel: tr('undo'),
              onTap: _undo,
            ),
          ),
          RoundButton(
            icon: Icons.refresh_rounded,
            size: size,
            semanticLabel: tr('restart'),
            onTap: _restart,
          ),
          RoundButton(
            icon: Icons.lightbulb_rounded,
            size: size,
            semanticLabel: tr('hint'),
            color: AppColors.gold,
            dark: const Color(0xFFC67F00),
            onTap: _hint,
            badge: _hintBadge(g),
          ),
        ],
      ),
    );
  }

  /// "FREE" while the level's free hint is unused, then a video icon.
  Widget _hintBadge(GameState? g) {
    final free = g?.freeHintAvailable ?? true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: free ? const Color(0xFF2FB58A) : const Color(0xFF5B2A9E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: free
          ? Text(
              tr('hint_free'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            )
          : const Icon(
              Icons.ondemand_video_rounded,
              color: Colors.white,
              size: 13,
            ),
    );
  }

  Widget _tipBanner(String text) {
    return Positioned(
      left: 24,
      right: 24,
      top: 78,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, (1 - v) * -12),
              child: child,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A44).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.boardLine.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatTime(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Elapsed time next to the star target; turns grey once the target passes.
class _ParClock extends StatelessWidget {
  final int seconds;
  final int par;
  const _ParClock({required this.seconds, required this.par});

  @override
  Widget build(BuildContext context) {
    final ok = seconds <= par;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 15,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 3),
        Text(
          formatTime(seconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.star_rounded,
          size: 15,
          color: ok ? AppColors.gold : Colors.white38,
        ),
        Text(
          formatTime(par),
          style: TextStyle(
            color: ok ? AppColors.gold : Colors.white38,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _WinOverlay extends StatefulWidget {
  final Level level;
  final WinSummary summary;
  final int seconds;
  final Sfx sfx;
  final VoidCallback onNext;
  final VoidCallback onReplay;

  const _WinOverlay({
    required this.level,
    required this.summary,
    required this.seconds,
    required this.sfx,
    required this.onNext,
    required this.onReplay,
  });

  @override
  State<_WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<_WinOverlay> {
  int _litStars = 0;
  final List<Timer> _timers = [];

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
                      icon: Icons.refresh_rounded,
                      onTap: widget.onReplay,
                      semanticLabel: tr('replay'),
                    ),
                    const SizedBox(width: 18),
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

  List<Widget> _rewards(WinSummary s) {
    final lines = <Widget>[];
    if (s.coins > 0) {
      lines.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 26),
            const SizedBox(width: 6),
            Text(
              '+${s.coins}',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
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
          tr('chapter_complete', {'name': ch.name, 'n': ch.reward}),
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
