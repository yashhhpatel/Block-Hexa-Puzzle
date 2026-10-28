import 'dart:async';

import 'package:block_hexa_puzzle/game/hex.dart';
import 'package:block_hexa_puzzle/game/level.dart';
import 'package:block_hexa_puzzle/l10n/l10n.dart';
import 'package:block_hexa_puzzle/services/progress.dart';
import 'package:block_hexa_puzzle/services/services.dart';
import 'package:block_hexa_puzzle/services/sfx.dart';
import 'package:block_hexa_puzzle/ui/chapters_screen.dart';
import 'package:block_hexa_puzzle/ui/win_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Level _level() => Level(
  number: 7,
  board: {const Hex(0, 0)},
  pieces: [Piece([const Hex(0, 0)], 0)],
  solution: [const Hex(0, 0)],
);

WinSummary _summary(int coins) => WinSummary(
  stars: 2,
  previousStars: 0,
  firstClear: true,
  noHints: true,
  underPar: false,
  coins: coins,
  chestProgress: 3,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Sfx sfx;

  setUp(() async {
    appLang.value = AppLang.en;
    SharedPreferences.setMockInitialValues({'sound': false, 'vibration': false});
    sfx = Sfx(await Progress.load());
  });

  Future<void> pump(
    WidgetTester tester, {
    int coins = 8,
    Future<bool> Function()? onDouble,
    VoidCallback? onHome,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              WinOverlay(
                level: _level(),
                summary: _summary(coins),
                seconds: 42,
                sfx: sfx,
                onNext: () {},
                onReplay: () {},
                onHome: onHome ?? () {},
                onDoubleCoins: onDouble,
              ),
            ],
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('Home button goes home', (tester) async {
    var home = 0;
    await pump(tester, onHome: () => home++);
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pump();
    expect(home, 1);
  });

  testWidgets('coins double only after a completed video', (tester) async {
    await pump(tester, onDouble: () async => true);
    expect(find.text('8'), findsOneWidget);
    await tester.tap(find.text('Watch ad for 2× coins'));
    await _settle(tester);
    expect(find.text('Coins doubled!'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('Watch ad for 2× coins'), findsNothing,
        reason: 'the offer is gone once claimed');
  });

  testWidgets('a skipped or failed video leaves coins unchanged', (tester) async {
    var calls = 0;
    await pump(tester, onDouble: () async {
      calls++;
      return false;
    });
    await tester.tap(find.text('Watch ad for 2× coins'));
    await _settle(tester);
    expect(calls, 1);
    expect(find.text('Coins doubled!'), findsNothing);
    expect(find.text('8'), findsOneWidget);
    // The player may try again.
    expect(find.text('Watch ad for 2× coins'), findsOneWidget);
  });

  testWidgets('taps during the video cannot claim twice', (tester) async {
    final video = Completer<bool>();
    var calls = 0;
    await pump(tester, onDouble: () {
      calls++;
      return video.future;
    });
    await tester.tap(find.text('Watch ad for 2× coins'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.ondemand_video_rounded),
        warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    video.complete(true);
    await _settle(tester);
    expect(find.text('16'), findsOneWidget);
  });

  testWidgets('no 2× offer when the win paid no coins', (tester) async {
    await pump(tester, coins: 0);
    expect(find.text('Watch ad for 2× coins'), findsNothing);
  });

  testWidgets('locked chapters explain how to unlock them', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'bgfx': false,
      'sound': false,
      'loginLast': now.year * 10000 + now.month * 100 + now.day,
      'unlocked': 450, // inside Insane
    });
    final services = Services.offline(await Progress.load());
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(
      MaterialApp(home: ChaptersScreen(services: services)),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Nightmare'), 300);
    await _settle(tester);
    expect(find.text('Finish Insane to unlock'), findsWidgets);
    await tester.tap(find.text('Nightmare'));
    await _settle(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    // The chapter in progress opens normally.
    await tester.scrollUntilVisible(find.text('Insane'), -300);
    await tester.tap(find.text('Insane'));
    await _settle(tester);
    expect(find.text('451'), findsOneWidget, reason: 'next level in Insane');
  });
}
