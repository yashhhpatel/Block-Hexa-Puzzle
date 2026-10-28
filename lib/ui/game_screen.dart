import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/generator.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'board_view.dart';
import 'settings_dialog.dart';
import 'theme.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  final Services services;
  final int level;
  const GameScreen({super.key, required this.services, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _game;
  final _boardKey = GlobalKey<BoardViewState>();
  bool _won = false;
  bool _showWin = false;
  bool _rewarded = false;
  String? _tip;
  Timer? _tipTimer;

  Progress get progress => widget.services.progress;
  Sfx get sfx => widget.services.sfx;

  @override
  void initState() {
    super.initState();
    _load(widget.level, restore: true);
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _game.removeListener(_onChanged);
    super.dispose();
  }

  void _load(int n, {bool restore = false}) {
    final game = GameState(LevelGenerator.generate(n));
    if (restore) {
      final saved = progress.savedBoard;
      if (saved != null) game.restore(saved);
    }
    game.addListener(_onChanged);
    _game = game;
    _won = false;
    _showWin = false;
    progress.setCurrentLevel(n);

    _tipTimer?.cancel();
    _tip = null;
    if (n == 1 && !progress.tutorialSeen) {
      _tip = 'Drag the blocks to fill up the board.';
    } else if (game.level.hasDecoys && !progress.decoyTipSeen) {
      _tip = "Tricky level!\nYou won't need all of the blocks.";
      progress.setDecoyTipSeen();
      _tipTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _tip = null);
      });
    }
  }

  void _onChanged() {
    if (_game.isComplete) {
      _onWin();
    } else {
      progress.saveBoard(_game.toJson());
    }
    setState(() {});
  }

  Future<void> _onWin() async {
    if (_won) return;
    _won = true;
    _tip = null;
    if (_game.level.number == 1) progress.setTutorialSeen();
    _rewarded = await progress.completeLevel(_game.level.number);
    _boardKey.currentState?.celebrate();
    sfx.play(Sound.win);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted && _won) setState(() => _showWin = true);
  }

  void _next() {
    sfx.play(Sound.button);
    _game.removeListener(_onChanged);
    setState(() => _load(_game.level.number + 1));
  }

  void _replay() {
    sfx.play(Sound.button);
    _game.removeListener(_onChanged);
    setState(() => _load(_game.level.number));
  }

  void _restart() {
    if (_game.isComplete) return;
    sfx.play(Sound.button);
    _game.reset();
  }

  void _hint() {
    if (_game.isComplete) return;
    if (!progress.spendCoins(Progress.hintCost)) {
      sfx.play(Sound.fail);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Not enough coins. Clear new levels to earn more!'),
          duration: Duration(seconds: 2),
        ));
      return;
    }
    if (_game.applyHint() == null) {
      // Nothing left to hint: refund.
      progress.setCoins(progress.coins + Progress.hintCost);
    } else {
      sfx.play(Sound.hint);
    }
    setState(() {});
  }

  bool get _winVisible =>
      _showWin && _game.isComplete && _boardKey.currentState != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        animate: progress.backgroundFx,
        child: SafeArea(
          child: Stack(children: [
            Column(children: [
              _header(),
              Expanded(
                child: BoardView(
                  key: _boardKey,
                  game: _game,
                  onPick: () => sfx.play(Sound.pick),
                  onPlace: () => sfx.play(Sound.place),
                  onFail: () => sfx.play(Sound.fail),
                ),
              ),
              _bottomBar(),
            ]),
            if (_tip != null) _tipBanner(_tip!),
            if (_winVisible) _WinOverlay(
              level: _game.level.number,
              reward: _rewarded ? Progress.levelReward : 0,
              onNext: _next,
              onReplay: _replay,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(children: [
        OutlinedTitle('Level ${_game.level.number}', size: 30),
        const Spacer(),
        CoinPill(coins: progress.coins),
      ]),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      color: Colors.black.withValues(alpha: 0.25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundButton(
            icon: Icons.arrow_back_rounded,
            semanticLabel: 'Back',
            onTap: () {
              sfx.play(Sound.button);
              Navigator.of(context).pop();
            },
          ),
          RoundButton(
            icon: Icons.settings_rounded,
            semanticLabel: 'Settings',
            onTap: () async {
              sfx.play(Sound.button);
              await showSettingsDialog(context, widget.services);
              if (mounted) setState(() {});
            },
          ),
          RoundButton(
            icon: Icons.refresh_rounded,
            semanticLabel: 'Restart',
            onTap: _restart,
          ),
          RoundButton(
            icon: Icons.lightbulb_rounded,
            semanticLabel: 'Hint',
            color: AppColors.gold,
            dark: const Color(0xFFC67F00),
            onTap: _hint,
            badge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF5B2A9E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                CoinIcon(size: 12),
                SizedBox(width: 2),
                Text('${Progress.hintCost}',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipBanner(String text) {
    return Positioned(
      left: 24,
      right: 24,
      top: 70,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                  offset: Offset(0, (1 - v) * -12), child: child)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A44).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.boardLine.withValues(alpha: 0.6)),
            ),
            child: Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic)),
          ),
        ),
      ),
    );
  }
}

class _WinOverlay extends StatelessWidget {
  final int level;
  final int reward;
  final VoidCallback onNext;
  final VoidCallback onReplay;

  const _WinOverlay({
    required this.level,
    required this.reward,
    required this.onNext,
    required this.onReplay,
  });

  static const _cheers = ['Awesome!', 'Brilliant!', 'Great!', 'Superb!', 'Perfect!'];

  @override
  Widget build(BuildContext context) {
    final cheer = _cheers[level % _cheers.length];
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutBack,
        builder: (_, v, _) => Container(
          color: Colors.black.withValues(alpha: 0.55 * v.clamp(0, 1)),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: 0.6 + 0.4 * v,
            child: Opacity(
              opacity: v.clamp(0, 1),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const _Medal(),
                const SizedBox(height: 14),
                OutlinedTitle(cheer.toUpperCase(), size: 36),
                const SizedBox(height: 6),
                Text('Level $level complete',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                if (reward > 0) ...[
                  const SizedBox(height: 10),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const CoinIcon(size: 24),
                    const SizedBox(width: 6),
                    Text('+$reward',
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ]),
                ],
                const SizedBox(height: 26),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  RoundButton(
                      icon: Icons.refresh_rounded,
                      onTap: onReplay,
                      semanticLabel: 'Replay'),
                  const SizedBox(width: 18),
                  PillButton(label: 'Next', onTap: onNext),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Spinning rays behind a golden hex medal.
class _Medal extends StatefulWidget {
  const _Medal();
  @override
  State<_Medal> createState() => _MedalState();
}

class _MedalState extends State<_Medal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Transform.rotate(
            angle: _c.value * 2 * math.pi,
            child: CustomPaint(size: const Size(170, 170), painter: _RaysPainter()),
          ),
        ),
        Container(
          width: 92,
          height: 92,
          decoration: const ShapeDecoration(
            shape: HexBorder(),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3A6), AppColors.gold, Color(0xFFE08A00)],
            ),
            shadows: [BoxShadow(color: Color(0x88FFC52E), blurRadius: 24)],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
        ),
      ]),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()..color = AppColors.gold.withValues(alpha: 0.22);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.12) * size.width / 2,
            c.dy + math.sin(a - 0.12) * size.width / 2)
        ..lineTo(c.dx + math.cos(a + 0.12) * size.width / 2,
            c.dy + math.sin(a + 0.12) * size.width / 2)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => false;
}
