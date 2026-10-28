import 'dart:math' as math;
import 'dart:ui';

import 'package:block_hexa_puzzle/l10n/l10n.dart';
import 'package:block_hexa_puzzle/meta/cosmetics.dart';
import 'package:block_hexa_puzzle/services/progress.dart';
import 'package:block_hexa_puzzle/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG contrast ratio between two opaque colours (1..21).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const newIds = ['aurora', 'sakura', 'glacier', 'lava', 'royal'];

  tearDown(() => appLang.value = AppLang.en);

  test('ten themes with unique ids, original five unchanged', () {
    final themes = Cosmetics.themes;
    expect(themes.length, 10);
    expect(themes.map((t) => t.id).toSet().length, 10);
    expect(themes.take(5).map((t) => t.id),
        ['ocean', 'galaxy', 'forest', 'sunset', 'midnight']);
    // Original themes keep their prices and star gates.
    expect(Cosmetics.theme('galaxy').price, 200);
    expect(Cosmetics.theme('midnight').starsRequired, 60);
    // Without a flare colour, a theme glows in its line colour as before.
    expect(Cosmetics.theme('ocean').flare, Cosmetics.theme('ocean').line);
    for (final id in newIds) {
      expect(Cosmetics.theme(id).id, id);
    }
  });

  test('every theme looks different', () {
    final looks = Cosmetics.themes.map((t) => (t.bgTop, t.line)).toSet();
    expect(looks.length, Cosmetics.themes.length);
  });

  test('board lines and every block colour stay readable on each theme', () {
    for (final t in Cosmetics.themes) {
      expect(_contrast(t.line, t.cell), greaterThan(4.5),
          reason: '${t.id}: board outline vs cells');
      for (final c in kBlockColors) {
        expect(_contrast(c, t.cell), greaterThan(2.5),
            reason: '${t.id}: block $c vs cells');
      }
    }
  });

  test('new theme names are translated in every language', () {
    for (final lang in AppLang.values) {
      appLang.value = lang;
      final names = <String>{};
      for (final id in newIds) {
        final name = Cosmetics.theme(id).name;
        expect(name, isNot(startsWith('theme_')), reason: '${lang.name}.$id');
        names.add(name);
      }
      expect(names.length, newIds.length, reason: '${lang.name} names unique');
    }
  });

  test('new themes can be bought, unlocked with stars and equipped', () async {
    SharedPreferences.setMockInitialValues({'coins': 1000});
    final p = await Progress.load();
    final aurora = Cosmetics.theme('aurora');
    final lava = Cosmetics.theme('lava');

    expect(p.isUnlocked(aurora), isFalse);
    expect(await p.unlock(aurora), isTrue);
    expect(p.coins, 1000 - aurora.price);
    await p.equip(aurora);
    expect(p.themeId, 'aurora');
    expect(p.theme.flare, aurora.flare);

    // Lava is earned with stars, not coins.
    expect(p.isUnlocked(lava), isFalse);
    expect(await p.unlock(lava), isFalse);
    final stars = <String, int>{for (var n = 1; n <= 40; n++) '$n': 3};
    SharedPreferences.setMockInitialValues({
      'stars': '{${stars.entries.map((e) => '"${e.key}":${e.value}').join(',')}}',
    });
    final p2 = await Progress.load();
    expect(p2.totalStars, 120);
    expect(p2.isUnlocked(lava), isTrue);
  });
}
