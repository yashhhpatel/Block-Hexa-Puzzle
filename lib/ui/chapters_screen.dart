import 'package:flutter/material.dart';

import '../meta/chapters.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'game_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// List of chapters with progress; chapters keep coming forever.
class ChaptersScreen extends StatefulWidget {
  final Services services;
  const ChaptersScreen({super.key, required this.services});

  @override
  State<ChaptersScreen> createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends State<ChaptersScreen> {
  Progress get p => widget.services.progress;

  @override
  Widget build(BuildContext context) {
    final unlocked = p.unlockedLevel;
    final current = Chapters.forLevel(unlocked).index;
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Column(children: [
            _TopBar(services: widget.services, title: 'Chapters'),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                // All reached chapters plus a peek at the next locked one.
                itemCount: current + 2,
                itemBuilder: (context, i) {
                  final c = Chapters.at(i);
                  final open = c.first <= unlocked;
                  final cleared = (unlocked - c.first).clamp(0, c.count);
                  return _ChapterCard(
                    chapter: c,
                    open: open,
                    cleared: cleared,
                    stars: open ? p.starsInChapter(c) : 0,
                    onTap: !open
                        ? null
                        : () async {
                            widget.services.sfx.play(Sound.button);
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  LevelGridScreen(services: widget.services, chapter: c),
                            ));
                            if (mounted) setState(() {});
                          },
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

class _TopBar extends StatelessWidget {
  final Services services;
  final String title;
  const _TopBar({required this.services, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      child: Row(children: [
        RoundButton(
          icon: Icons.arrow_back_rounded,
          size: 44,
          semanticLabel: 'Back',
          onTap: () {
            services.sfx.play(Sound.button);
            Navigator.pop(context);
          },
        ),
        const SizedBox(width: 10),
        Flexible(child: FittedBox(child: OutlinedTitle(title, size: 28))),
        const Spacer(),
        CoinPill(coins: services.progress.coins),
      ]),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final bool open;
  final int cleared;
  final int stars;
  final VoidCallback? onTap;

  const _ChapterCard({
    required this.chapter,
    required this.open,
    required this.cleared,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = chapter;
    final done = cleared >= c.count;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: open ? 1 : 0.55,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c.color.withValues(alpha: open ? 0.45 : 0.15),
                Colors.black.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.color.withValues(alpha: 0.8), width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 58,
              height: 58,
              decoration: ShapeDecoration(
                shape: const HexBorder(),
                color: open ? c.color : Colors.white24,
              ),
              alignment: Alignment.center,
              child: open
                  ? Icon(done ? Icons.emoji_events_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 30)
                  : const Icon(Icons.lock_rounded, color: Colors.white70),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                Text('Levels ${c.first}–${c.last}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: cleared / c.count,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: c.color,
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Text('$cleared/${c.count}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 15),
                  Text(' $stars/${c.maxStars}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Levels inside one chapter, with their best star ratings.
class LevelGridScreen extends StatefulWidget {
  final Services services;
  final Chapter chapter;
  const LevelGridScreen({super.key, required this.services, required this.chapter});

  @override
  State<LevelGridScreen> createState() => _LevelGridScreenState();
}

class _LevelGridScreenState extends State<LevelGridScreen> {
  late final ScrollController _scroll;

  Progress get p => widget.services.progress;

  @override
  void initState() {
    super.initState();
    final row = ((p.unlockedLevel - widget.chapter.first) ~/ 4).clamp(0, 1 << 20);
    _scroll = ScrollController(initialScrollOffset: ((row - 2).clamp(0, 1 << 20)) * 98.0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chapter;
    final unlocked = p.unlockedLevel;
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Column(children: [
            _TopBar(services: widget.services, title: c.name),
            Expanded(
              child: GridView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisExtent: 90,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: c.count,
                itemBuilder: (context, i) {
                  final n = c.first + i;
                  final open = n <= unlocked;
                  return GestureDetector(
                    onTap: !open
                        ? null
                        : () async {
                            widget.services.sfx.play(Sound.button);
                            if (n != p.currentLevel) await p.clearBoard();
                            if (!context.mounted) return;
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => GameScreen(services: widget.services, level: n),
                            ));
                            if (mounted) setState(() {});
                          },
                    child: _LevelTile(
                      n: n,
                      open: open,
                      current: n == unlocked,
                      stars: p.starsFor(n),
                      color: c.color,
                    ),
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
  final bool current;
  final int stars;
  final Color color;
  const _LevelTile({
    required this.n,
    required this.open,
    required this.current,
    required this.stars,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = !open
        ? const [Color(0xFF5A6A8E), Color(0xFF3A476A), Color(0xFF263052)]
        : current
            ? const [Color(0xFFFF8DB5), AppColors.accent, AppColors.accentDark]
            : [Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.35)!];
    return Column(children: [
      Expanded(
        child: AspectRatio(
          aspectRatio: 0.9,
          child: Container(
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
                ? Text('$n',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 3)]))
                : const Icon(Icons.lock_rounded, color: Colors.white54, size: 24),
          ),
        ),
      ),
      const SizedBox(height: 2),
      if (open && !current) StarRow(earned: stars, size: 15) else const SizedBox(height: 15),
    ]);
  }
}
