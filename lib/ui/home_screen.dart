import 'package:flutter/material.dart';

import '../services/services.dart';
import '../services/sfx.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_dialog.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  final Services services;
  const HomeScreen({super.key, required this.services});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    widget.services.sfx.play(Sound.button);
    await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, _, _) => screen,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.services.progress;
    final level = p.currentLevel;
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(children: [
                RoundButton(
                  icon: Icons.settings_rounded,
                  size: 44,
                  semanticLabel: 'Settings',
                  onTap: () async {
                    widget.services.sfx.play(Sound.button);
                    await showSettingsDialog(context, widget.services);
                    if (mounted) setState(() {});
                  },
                ),
                const Spacer(),
                CoinPill(coins: p.coins),
              ]),
            ),
            const Spacer(flex: 2),
            const _Logo(),
            const Spacer(flex: 3),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                  scale: 1 + 0.05 * Curves.easeInOut.transform(_pulse.value),
                  child: child),
              child: GestureDetector(
                onTap: () => _open(
                    GameScreen(services: widget.services, level: level)),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const ShapeDecoration(
                    shape: HexBorder(),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF8DB5), AppColors.accent, AppColors.accentDark],
                    ),
                    shadows: [
                      BoxShadow(color: Color(0x99FF4F8B), blurRadius: 30),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 86),
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedTitle('Level $level', size: 26),
            const Spacer(flex: 2),
            PillButton(
              label: 'Levels',
              icon: Icons.grid_view_rounded,
              color: AppColors.button,
              dark: AppColors.buttonDark,
              onTap: () => _open(LevelSelectScreen(services: widget.services)),
            ),
            const Spacer(flex: 2),
          ]),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    const letters = 'HEXA';
    const colors = [
      Color(0xFF3EC9F5),
      Color(0xFFFFC93A),
      Color(0xFFFF4D8D),
      Color(0xFF8BE04A),
    ];
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < letters.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 64,
              height: 64,
              decoration: ShapeDecoration(
                shape: const HexBorder(),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(colors[i], Colors.white, 0.35)!, colors[i],
                    Color.lerp(colors[i], Colors.black, 0.25)!],
                ),
              ),
              alignment: Alignment.center,
              child: Text(letters[i],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black38, offset: Offset(0, 2), blurRadius: 3)])),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      const OutlinedTitle('FILL PUZZLE', size: 34),
    ]);
  }
}
