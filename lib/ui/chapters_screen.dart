import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

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
          child: Column(
            children: [
              _TopBar(services: widget.services, title: tr('chapters_title')),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  // Every named chapter (so players see what lies ahead),
                  // then Grandmaster chapters as they are reached.
                  itemCount: math.max(Chapters.fixedCount, current + 2),
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
                          ? () {
                              widget.services.sfx.play(Sound.fail);
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tr('chapter_locked', {
                                        'name': Chapters.at(i - 1).name,
                                      }),
                                    ),
                                  ),
                                );
                            }
                          : () async {
                              widget.services.sfx.play(Sound.button);
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LevelGridScreen(
                                    services: widget.services,
                                    chapter: c,
                                  ),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                    );
                  },
                ),
              ),
            ],
          ),
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
      child: Row(
        children: [
          RoundButton(
            icon: Icons.arrow_back_rounded,
            size: 44,
            semanticLabel: tr('back'),
            onTap: () {
              services.sfx.play(Sound.button);
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 10),
          Flexible(child: FittedBox(child: OutlinedTitle(title, size: 28))),
          const Spacer(),
          CoinPill(coins: services.progress.coins),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final bool open;
  final int cleared;
  final int stars;
  final VoidCallback onTap;

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
    // 10-step difficulty meter; endless Grandmaster chapters are maxed out.
    final level = (c.index + 1).clamp(1, 10);
    return Pressable(
      pressedScale: 0.97,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: open
                ? [c.color.withValues(alpha: 0.55), c.style.deep]
                : [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.35),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: open ? c.color : Colors.white.withValues(alpha: 0.15),
            width: open ? 2 : 1,
          ),
          boxShadow: open
              ? [
                  BoxShadow(
                    color: c.color.withValues(alpha: 0.35),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: ShapeDecoration(
                      shape: const HexBorder(),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: open
                            ? [
                                Color.lerp(c.color, Colors.white, 0.3)!,
                                c.style.deep,
                              ]
                            : const [Color(0x33FFFFFF), Color(0x22000000)],
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: open ? 1 : 0.35,
                    child: Text(c.emoji, style: const TextStyle(fontSize: 28)),
                  ),
                  if (!open)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  if (done)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF6CF0B8),
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: TextStyle(
                      color: open ? Colors.white : Colors.white60,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    tr('levels_range', {'a': c.first, 'b': c.last}),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < 10; i++)
                        Expanded(
                          child: Container(
                            height: 5,
                            margin: const EdgeInsets.only(right: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i < level
                                  ? (open ? c.color : Colors.white38)
                                  : Colors.white12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (open) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: cleared / c.count,
                        minHeight: 7,
                        backgroundColor: Colors.white12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$cleared/${c.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.gold,
                          size: 15,
                        ),
                        Text(
                          ' $stars/${c.maxStars}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      tr('chapter_locked', {
                        'name': Chapters.at(c.index - 1).name,
                      }),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Levels inside one chapter, with their best star ratings.
class LevelGridScreen extends StatefulWidget {
  final Services services;
  final Chapter chapter;
  const LevelGridScreen({
    super.key,
    required this.services,
    required this.chapter,
  });

  @override
  State<LevelGridScreen> createState() => _LevelGridScreenState();
}

class _LevelGridScreenState extends State<LevelGridScreen> {
  late final ScrollController _scroll;

  Progress get p => widget.services.progress;

  @override
  void initState() {
    super.initState();
    final row = ((p.unlockedLevel - widget.chapter.first) ~/ 4).clamp(
      0,
      1 << 20,
    );
    _scroll = ScrollController(
      initialScrollOffset: ((row - 2).clamp(0, 1 << 20)) * 98.0,
    );
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
          child: Column(
            children: [
              _TopBar(services: widget.services, title: c.title),
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
                          ? () {
                              widget.services.sfx.play(Sound.fail);
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tr('chapter_locked', {
                                        'name': Chapters.at(i - 1).name,
                                      }),
                                    ),
                                  ),
                                );
                            }
                          : () async {
                              widget.services.sfx.play(Sound.button);
                              if (n != p.currentLevel) await p.clearBoard();
                              if (!context.mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GameScreen(
                                    services: widget.services,
                                    level: n,
                                  ),
                                ),
                              );
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
            ],
          ),
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
        : [
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ];
    return Column(
      children: [
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
                  ? Text(
                      '$n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 3)],
                      ),
                    )
                  : const Icon(
                      Icons.lock_rounded,
                      color: Colors.white54,
                      size: 24,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        if (open && !current)
          StarRow(earned: stars, size: 15)
        else
          const SizedBox(height: 15),
      ],
    );
  }
}
