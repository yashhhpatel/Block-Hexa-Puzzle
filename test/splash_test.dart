import 'package:block_hexa_puzzle/l10n/l10n.dart';
import 'package:block_hexa_puzzle/main.dart';
import 'package:block_hexa_puzzle/services/progress.dart';
import 'package:block_hexa_puzzle/services/services.dart';
import 'package:block_hexa_puzzle/ui/home_screen.dart';
import 'package:block_hexa_puzzle/ui/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Services> _services() async {
  final now = DateTime.now();
  SharedPreferences.setMockInitialValues({
    'bgfx': false,
    'sound': false,
    'music': false,
    'loginLast': now.year * 10000 + now.month * 100 + now.day,
  });
  return Services.offline(await Progress.load());
}

void main() {
  tearDown(() => appLang.value = AppLang.en);

  testWidgets('launch shows Loading... with a progress bar, then home', (
    tester,
  ) async {
    final services = await _services();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    await tester.pumpWidget(HexaApp(services: services));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    // No ad without the ads SDK: the bar fills quickly, then home appears.
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('loading screen fits in every language', (tester) async {
    final services = await _services();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    for (final lang in AppLang.values) {
      appLang.value = lang;
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(services: services)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: lang.name);
      expect(find.text(tr('loading')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
