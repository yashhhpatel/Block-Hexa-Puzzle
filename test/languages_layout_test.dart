import 'package:block_hexa_puzzle/l10n/l10n.dart';
import 'package:block_hexa_puzzle/services/progress.dart';
import 'package:block_hexa_puzzle/services/services.dart';
import 'package:block_hexa_puzzle/ui/chapters_screen.dart';
import 'package:block_hexa_puzzle/ui/daily_screen.dart';
import 'package:block_hexa_puzzle/ui/game_screen.dart';
import 'package:block_hexa_puzzle/ui/home_screen.dart';
import 'package:block_hexa_puzzle/ui/how_to_play_screen.dart';
import 'package:block_hexa_puzzle/ui/languages_screen.dart';
import 'package:block_hexa_puzzle/ui/quests_screen.dart';
import 'package:block_hexa_puzzle/ui/remove_ads_screen.dart';
import 'package:block_hexa_puzzle/ui/settings_dialog.dart';
import 'package:block_hexa_puzzle/ui/shop_screen.dart';
import 'package:block_hexa_puzzle/ui/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every main screen, in every language, on a small phone: any text that
/// overflows its space fails the test.
void main() {
  late Services services;

  setUp(() async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'bgfx': false,
      'sound': false,
      'music': false,
      'loginLast': now.year * 10000 + now.month * 100 + now.day,
      'unlocked': 130,
      'current': 125,
    });
    services = Services.offline(await Progress.load());
  });

  tearDown(() => appLang.value = AppLang.en);

  Widget app(Widget home) => MaterialApp(
        locale: appLang.value.locale,
        supportedLocales: [for (final l in AppLang.values) l.locale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      );

  for (final lang in AppLang.values) {
    testWidgets('all screens fit in ${lang.englishName}', (tester) async {
      appLang.value = lang;
      await tester.binding.setSurfaceSize(const Size(360, 640));
      final screens = <String, Widget>{
        'home': HomeScreen(services: services),
        'chapters': ChaptersScreen(services: services),
        'daily': DailyScreen(services: services),
        'quests': QuestsScreen(services: services),
        'shop': ShopScreen(services: services),
        'remove ads': RemoveAdsScreen(services: services),
        'how to play': HowToPlayScreen(services: services),
        'languages': LanguagesScreen(services: services),
        'statistics': StatsScreen(services: services),
        'game': GameScreen(services: services, level: 3),
      };
      for (final e in screens.entries) {
        await tester.pumpWidget(app(e.value), duration: Duration.zero);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final err = tester.takeException();
        if (err != null) {
          final lines = err is FlutterError
              ? err.toStringDeep().split('\n').where(
                  (l) => l.contains('creator') || l.contains('overflowed'))
              : ['$err'];
          // ignore: avoid_print
          print('OVERFLOW ${e.key} ${lang.name}: ${lines.join(' | ')}');
        }
        expect(err, isNull, reason: '${e.key} in ${lang.name}');
      }

      // Settings is a dialog over the home screen.
      await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showSettingsDialog(context, services),
              child: const Text('open'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: 'settings in ${lang.name}');
      expect(find.text(tr('language')), findsOneWidget);
      // Unmount so periodic timers stop before the test ends.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
