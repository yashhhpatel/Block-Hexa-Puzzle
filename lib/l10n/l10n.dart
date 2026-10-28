import 'package:flutter/widgets.dart';

import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_es.dart';
import 'strings_fr.dart';
import 'strings_hi.dart';
import 'strings_id.dart';
import 'strings_ja.dart';
import 'strings_pt.dart';

/// The eight languages the game ships with.
enum AppLang {
  en('English', 'English', Locale('en')),
  hi('हिन्दी', 'Hindi', Locale('hi')),
  es('Español', 'Spanish', Locale('es')),
  pt('Português', 'Portuguese', Locale('pt', 'BR')),
  fr('Français', 'French', Locale('fr')),
  de('Deutsch', 'German', Locale('de')),
  id('Bahasa Indonesia', 'Indonesian', Locale('id')),
  ja('日本語', 'Japanese', Locale('ja'));

  final String nativeName;
  final String englishName;
  final Locale locale;
  const AppLang(this.nativeName, this.englishName, this.locale);

  static AppLang? byCode(String? code) {
    for (final l in values) {
      if (l.name == code) return l;
    }
    return null;
  }

  /// Best match for the phone's own language, English otherwise.
  static AppLang fromDevice(Locale device) =>
      byCode(device.languageCode) ?? AppLang.en;
}

const Map<AppLang, Map<String, String>> kStrings = {
  AppLang.en: stringsEn,
  AppLang.hi: stringsHi,
  AppLang.es: stringsEs,
  AppLang.pt: stringsPt,
  AppLang.fr: stringsFr,
  AppLang.de: stringsDe,
  AppLang.id: stringsId,
  AppLang.ja: stringsJa,
};

/// Current language. Changing it rebuilds the whole app (see main.dart).
final ValueNotifier<AppLang> appLang = ValueNotifier(AppLang.en);

/// Looks up [key] in the current language, filling `{name}` placeholders
/// from [args]. Falls back to English, then to the key itself.
String tr(String key, [Map<String, Object> args = const {}]) {
  var s = kStrings[appLang.value]![key] ?? stringsEn[key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// "Oct 28" in the current language.
String shortDate(DateTime d) =>
    tr('date_short', {'m': tr('month_short_${d.month}'), 'd': d.day});

/// "October 2026" in the current language.
String monthYear(DateTime d) =>
    tr('month_year', {'m': tr('month_${d.month}'), 'y': d.year});
