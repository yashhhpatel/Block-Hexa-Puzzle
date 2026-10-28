import 'dart:async';
import 'dart:isolate';

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
import 'win_overlay.dart';
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
    _recordPlay();
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
      // Coming back from a rewarded video also "resumes" the app; the hint
      // flow restarts the clock itself once the video is closed.
      if (_game != null && !_game!.isComplete && !_hintBusy) _clock.start();
    } else {
      _clock.stop();
      _recordPlay();
    }
  }

  int _playRecorded = 0;

  /// Adds board time since the last call to the "time played" statistic.
  void _recordPlay() {
    final now = _clock.elapsed.inSeconds;
    if (now > _playRecorded) progress.recordPlayTime(now - _playRecorded);
    _playRecorded = now;
  }

  // ---- loading ------------------------------------------------------------

  // Static so the closures sent to the isolate capture only their argument,
  // never the State (which holds timers and can't cross isolates).
  static Future<Level> _generateLevel(int n) =>
      Isolate.run(() => LevelGenerator.generate(n));
  static Future<Level> _generateDaily(DateTime day) =>
      Isolate.run(() => LevelGenerator.generateDaily(day));

  int? _prefetchNumber;
  Future<Level>? _prefetched;

  /// Starts building level [n] in the background so "Next" opens it
  /// instantly, even for the big boards of the hardest chapters.
  void _prefetchNext(int n) {
    if (n < LevelGenerator.uniqueFromLevel || _prefetchNumber == n) return;
    _prefetchNumber = n;
    _prefetched = _generateLevel(n);
  }

  Future<void> _loadLevel(int n, {bool restore = false}) async {
    final token = ++_loadToken;
    _detach();
    // Small levels are instant; bigger ones are built off the UI thread,
    // usually already done in the background while the previous one was
    // being played.
    final Level level;
    if (n < LevelGenerator.uniqueFromLevel) {
      level = LevelGenerator.generate(n);
    } else if (_prefetchNumber == n && _prefetched != null) {
      level = await _prefetched!;
    } else {
      level = await _generateLevel(n);
    }
    if (!mounted || token != _loadToken) return;
    final game = GameState(level);
    if (restore) {
      final saved = progress.savedBoard;
      if (saved != null) game.restore(saved);
    }
    progress.setCurrentLevel(n);
    _attach(game);
    _prefetchNext(n + 1);

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
    final level = await _generateDaily(day);
    if (!mounted || token != _loadToken) return;
    _attach(GameState(level));
    setState(() {});
  }

  void _detach() {
    _recordPlay();
    _recordBlocks();
    _game?.removeListener(_onChanged);
    _game = null;
    _win = null;
    _doubleClaimed = false;
    _winning = false;
    _showWin = false;
    _blocksRecorded = false;
    _tipTimer?.cancel();
    _tip = null;
    _clock
      ..stop()
      ..reset();
    _playRecorded = 0;
  }

  void _attach(GameState game) {
    game.addListener(_onChanged);
    _game = game;
    if (!game.freeHintAvailable) widget.services.ads.preloadRewarded();
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
    if (summary.coins > 0) widget.services.ads.preloadRewarded();
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

  void _home() {
    sfx.play(Sound.button);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Paid out at most once per win, and only after Google confirms the
  /// rewarded video was watched to the end.
  bool _doubleClaimed = false;

  Future<bool> _doubleCoins() async {
    final win = _win;
    if (win == null || _doubleClaimed || win.coins <= 0) return false;
    final ads = widget.services.ads;
    if (!ads.rewardedReady) {
      ads.preloadRewarded();
      _snack(tr('double_unavailable'));
      return false;
    }
    final earned = await ads.showRewarded();
    if (!mounted || _win != win) return false;
    if (!earned) {
      _snack(tr('double_incomplete'));
      return false;
    }
    if (_doubleClaimed) return false;
    _doubleClaimed = true;
    await progress.addCoins(win.coins);
    if (mounted) setState(() {});
    return true;
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
      // The next hint will need a video: get one ready now.
      widget.services.ads.preloadRewarded();
      return;
    }
    sfx.play(Sound.button);
    // Neither the question nor the video counts against the target time.
    _hintBusy = true;
    _clock.stop();
    final watch = await _confirmVideo();
    final ads = widget.services.ads;
    var earned = false;
    var unavailable = false;
    if (watch == true && mounted && _game == g && !g.isComplete) {
      if (ads.rewardedReady) {
        earned = await ads.showRewarded();
      } else {
        ads.preloadRewarded();
        unavailable = true;
      }
    }
    _hintBusy = false;
    if (!mounted || _game != g) return;
    if (!g.isComplete) _clock.start();
    if (watch != true) return;
    if (unavailable) {
      _snack(tr('hint_ad_unavailable'));
      return;
    }
    if (earned) {
      _giveHint(g);
    } else {
      sfx.play(Sound.fail);
      _snack(tr('hint_ad_incomplete'));
    }
  }

  void _giveHint(GameState g) {
    if (g.applyHint() != null) {
      sfx.play(Sound.hint);
      progress.recordHint();
    }
    setState(() {});
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 3),
          // Float above the control bar so the buttons stay tappable.
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 140),
        ),
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
                WinOverlay(
                  level: g.level,
                  summary: _win!,
                  seconds: _clock.elapsed.inSeconds,
                  sfx: sfx,
                  onNext: _next,
                  onReplay: _replay,
                  onHome: _home,
                  onDoubleCoins: _win!.coins > 0 ? _doubleCoins : null,
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
                          '${chapter.title} ${chapter.positionOf(level!.number)}/${chapter.count}',
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
