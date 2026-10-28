import 'package:block_hexa_puzzle/main.dart';
import 'package:block_hexa_puzzle/services/progress.dart';
import 'package:block_hexa_puzzle/services/services.dart';
import 'package:block_hexa_puzzle/services/sfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home opens level 1 and shows the board', (tester) async {
    SharedPreferences.setMockInitialValues({'bgfx': false});
    final progress = await Progress.load();
    // Skip audio init: no platform audio in widget tests.
    final services = Services(progress, Sfx(progress));
    await progress.setSound(false);
    await progress.setVibration(false);

    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(HexaApp(services: services));
    expect(find.text('Level 1'), findsWidgets);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Level 1'), findsWidgets);
    expect(find.textContaining('Drag the blocks'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);
  });
}
