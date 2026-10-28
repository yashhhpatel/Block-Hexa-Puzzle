import 'dart:ui';
import 'package:block_hexa_puzzle/l10n/l10n.dart';
import 'package:block_hexa_puzzle/l10n/strings_en.dart';
import 'package:flutter_test/flutter_test.dart';

final _placeholder = RegExp(r'\{(\w+)\}');

Set<String> _params(String s) =>
    _placeholder.allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  test('there are exactly 9 languages', () {
    expect(AppLang.values.length, 9);
    expect(kStrings.keys.toSet(), AppLang.values.toSet());
  });

  for (final lang in AppLang.values) {
    test('${lang.englishName} has every key with matching placeholders', () {
      final table = kStrings[lang]!;
      final missing = stringsEn.keys
          .where((k) => !table.containsKey(k))
          .toList();
      final extra = table.keys.where((k) => !stringsEn.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'missing in ${lang.name}');
      expect(extra, isEmpty, reason: 'unknown keys in ${lang.name}');
      for (final k in stringsEn.keys) {
        expect(
          _params(table[k]!),
          _params(stringsEn[k]!),
          reason: '${lang.name}.$k placeholders',
        );
        expect(table[k]!.trim(), isNotEmpty, reason: '${lang.name}.$k empty');
      }
    });
  }

  test('tr fills placeholders and follows the current language', () {
    appLang.value = AppLang.en;
    expect(tr('level_n', {'n': 7}), 'Level 7');
    appLang.value = AppLang.de;
    expect(tr('level_n', {'n': 7}), 'Level 7');
    appLang.value = AppLang.es;
    expect(tr('level_n', {'n': 7}), 'Nivel 7');
    appLang.value = AppLang.ja;
    expect(monthYear(DateTime(2026, 10, 3)), '2026年10月');
    expect(shortDate(DateTime(2026, 10, 3)), '10月3日');
    appLang.value = AppLang.zh;
    expect(tr('level_n', {'n': 7}), '第 7 关');
    expect(monthYear(DateTime(2026, 10, 3)), '2026年10月');
    appLang.value = AppLang.en;
    expect(shortDate(DateTime(2026, 10, 3)), 'Oct 3');
  });

  test('device locale picks a supported language or falls back to English', () {
    expect(AppLang.fromDevice(const Locale('hi', 'IN')), AppLang.hi);
    expect(AppLang.fromDevice(const Locale('pt', 'PT')), AppLang.pt);
    expect(AppLang.fromDevice(const Locale('ko')), AppLang.en);
    expect(AppLang.fromDevice(const Locale('zh', 'CN')), AppLang.zh);
    expect(AppLang.fromDevice(const Locale('zh', 'TW')), AppLang.zh);
  });
}
