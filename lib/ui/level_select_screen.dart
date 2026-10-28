import 'package:flutter/material.dart';

import '../services/services.dart';
import '../services/sfx.dart';
import 'game_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Scrollable grid of levels. Levels never run out: the grid always shows a
/// few locked levels past the furthest one reached.
class LevelSelectScreen extends StatefulWidget {
  final Services services;
  const LevelSelectScreen({super.key, required this.services});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final row = (widget.services.progress.unlockedLevel - 1) ~/ 4;
    _scroll = ScrollController(initialScrollOffset: (row - 2).clamp(0, 1 << 30) * 92.0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.services.progress;
    final unlocked = p.unlockedLevel;
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(children: [
                RoundButton(
                  icon: Icons.arrow_back_rounded,
                  size: 44,
                  semanticLabel: 'Back',
                  onTap: () {
                    widget.services.sfx.play(Sound.button);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),
                const OutlinedTitle('Levels', size: 30),
                const Spacer(),
                CoinPill(coins: p.coins),
              ]),
            ),
            Expanded(
              child: GridView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisExtent: 84,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: unlocked + 40,
                itemBuilder: (context, i) {
                  final n = i + 1;
                  final open = n <= unlocked;
                  final done = n < unlocked;
                  return GestureDetector(
                    onTap: !open
                        ? null
                        : () async {
                            widget.services.sfx.play(Sound.button);
                            await widget.services.progress.clearBoard();
                            if (!context.mounted) return;
                            await Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => GameScreen(
                                    services: widget.services, level: n),
                              ),
                            );
                          },
                    child: _LevelTile(n: n, open: open, done: done),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int n;
  final bool open;
  final bool done;
  const _LevelTile({required this.n, required this.open, required this.done});

  @override
  Widget build(BuildContext context) {
    final colors = !open
        ? const [Color(0xFF5A6A8E), Color(0xFF3A476A), Color(0xFF263052)]
        : done
            ? const [Color(0xFF8CF0FF), AppColors.button, AppColors.buttonDark]
            : const [Color(0xFFFF8DB5), AppColors.accent, AppColors.accentDark];
    return Container(
      decoration: ShapeDecoration(
        shape: const HexBorder(),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      alignment: Alignment.center,
      child: open
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$n',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              if (done)
                const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
            ])
          : const Icon(Icons.lock_rounded, color: Colors.white54, size: 26),
    );
  }
}
