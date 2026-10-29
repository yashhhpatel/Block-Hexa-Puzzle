import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/services.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Loading screen shown on every cold start. It waits for the ads SDK and
/// the app-open ad, shows the ad, then finishes the bar over a few seconds
/// before the home screen appears.
class SplashScreen extends StatefulWidget {
  final Services services;
  const SplashScreen({super.key, required this.services});

  /// How long the bar takes to finish after the launch ad closes.
  static const afterAd = Duration(milliseconds: 2500);

  /// Finish time when no ad is shown (subscriber, offline, no fill).
  static const noAd = Duration(milliseconds: 700);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Creeps towards 75% while the ad loads; it can't know the real wait.
  late final AnimationController _wait = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..forward();

  /// Final stretch from wherever the bar is to 100%.
  late final AnimationController _finish = AnimationController(vsync: this);
  double _from = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _wait.dispose();
    _finish.dispose();
    super.dispose();
  }

  double get _waitValue => 0.75 * (1 - math.exp(-_wait.value * 30 / 2.5));

  double get _progress => _finishing
      ? _from + (1 - _from) * Curves.easeOut.transform(_finish.value)
      : _waitValue;

  Future<void> _run() async {
    final shown = await widget.services.ads.showAppOpenOnLaunch();
    if (!mounted) return;
    _wait.stop();
    setState(() {
      _from = _waitValue;
      _finishing = true;
    });
    _finish.duration = shown ? SplashScreen.afterAd : SplashScreen.noAd;
    await _finish.forward();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => HomeScreen(services: widget.services),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.services.progress;
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const ShapeDecoration(
                      shape: HexBorder(),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFF8DB5),
                          AppColors.accent,
                          AppColors.accentDark,
                        ],
                      ),
                      shadows: [
                        BoxShadow(color: Color(0x99FF4F8B), blurRadius: 30),
                      ],
                    ),
                    child: const Icon(
                      Icons.hexagon_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FittedBox(child: OutlinedTitle(tr('app_title'), size: 30)),
                  const SizedBox(height: 40),
                  Text(
                    tr('loading'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: Listenable.merge([_wait, _finish]),
                    builder: (_, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        color: AppColors.gold,
                        semanticsLabel: tr('loading'),
                        semanticsValue: '${(_progress * 100).round()}%',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
