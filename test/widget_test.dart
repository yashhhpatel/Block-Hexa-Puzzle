import 'package:block_hexa_puzzle/l10n/l10n.dart';
import 'package:block_hexa_puzzle/main.dart';
import 'package:block_hexa_puzzle/services/progress.dart';
import 'package:block_hexa_puzzle/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Services> _services() async {
  // Login reward already claimed today, so no popup gets in the way.
  final now = DateTime.now();
  SharedPreferences.setMockInitialValues({
    'bgfx': false,
    'sound': false,
    'music': false,
    'vibration': false,
    'loginLast': now.year * 10000 + now.month * 100 + now.day,
  });
  return Services.offline(await Progress.load());
}

/// The home screen animates forever, so wait a fixed time instead of
/// pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => appLang.value = AppLang.en);

  testWidgets('home opens level 1 and shows the board', (tester) async {
    final services = await _services();
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(HexaApp(services: services));
    await tester.pump();
    expect(find.text('Level 1'), findsWidgets);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Level 1'), findsWidgets);
    expect(find.textContaining('Drag the blocks'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);
  });

  testWidgets('choosing a language switches every visible screen and is saved',
      (tester) async {
    final services = await _services();
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(HexaApp(services: services));
    await tester.pump();

    // Settings shows all the new entries.
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await _settle(tester);
    for (final label in ['Statistics', 'Language', 'Remove Ads', 'How to play', 'Contact us', 'Privacy policy']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    await tester.tap(find.text('Language'));
    await _settle(tester);
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('日本語'), findsOneWidget);

    await tester.tap(find.text('Español'));
    await _settle(tester);
    expect(find.text('Idioma'), findsWidgets, reason: 'this screen switched');
    expect(services.progress.languageCode, 'es');

    // Screens underneath switched too.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _settle(tester);
    expect(find.text('Ajustes'), findsWidgets);
    expect(find.text('Quitar anuncios'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await _settle(tester);
    expect(find.text('Nivel 1'), findsWidgets);
    expect(find.text('Tienda'), findsOneWidget);
  });

  testWidgets('remove ads page shows the monthly price and duration', (tester) async {
    final services = await _services();
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(HexaApp(services: services));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await _settle(tester);
    await tester.tap(find.text('Remove Ads'));
    await _settle(tester);
    expect(find.text('₹299'), findsOneWidget);
    expect(find.text('/ month'), findsOneWidget);
    expect(find.textContaining('1 month'), findsOneWidget);
    expect(find.textContaining('Subscribe for ₹299'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Restore purchases'), 200);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('how to play walks through all six steps', (tester) async {
    final services = await _services();
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(HexaApp(services: services));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await _settle(tester);
    await tester.tap(find.text('How to play'));
    await _settle(tester);
    expect(find.text('Drag the blocks'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Next'));
      await _settle(tester);
    }
    expect(find.text('Come back daily'), findsOneWidget);
    expect(find.text("Let's play!"), findsOneWidget);
  });

  testWidgets('hints: first is free, then a video is required', (tester) async {
    final services = await _services();
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(HexaApp(services: services));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _settle(tester);
    expect(find.text('FREE'), findsOneWidget);

    // Free hint: placed straight away.
    await tester.tap(find.byIcon(Icons.lightbulb_rounded));
    await _settle(tester);
    expect(find.text('FREE'), findsNothing);
    expect(find.byIcon(Icons.ondemand_video_rounded), findsOneWidget);

    // Second hint: asks to watch a video.
    await tester.tap(find.byIcon(Icons.lightbulb_rounded));
    await _settle(tester);
    expect(find.text('Need another hint?'), findsOneWidget);
    await tester.tap(find.text('Watch video'));
    await _settle(tester);
    // No video can load in tests, so no hint may be granted.
    expect(find.textContaining('No video is available'), findsOneWidget);

    // Cancelling the dialog grants nothing either.
    await tester.tap(find.byIcon(Icons.lightbulb_rounded));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(find.text('Need another hint?'), findsNothing);
  });

  testWidgets('reaching an achievement tier shows the unlock toast',
      (tester) async {
    final services = await _services();
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(HexaApp(services: services));
    await tester.pump();
    await tester.runAsync(() => services.progress.recordBlocksPlaced(100));
    await _settle(tester);
    expect(find.text('ACHIEVEMENT UNLOCKED!'), findsOneWidget);
    expect(find.text('Master Builder'), findsOneWidget);
    expect(find.text('Place 100 blocks'), findsOneWidget);
    // It slides away by itself.
    await tester.pump(const Duration(seconds: 4));
    await _settle(tester);
    expect(find.text('Master Builder'), findsNothing);
  });
}
