import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'theme.dart';
import 'widgets.dart';

/// Pick one of the eight languages; the whole game switches immediately and
/// the choice is remembered.
class LanguagesScreen extends StatelessWidget {
  final Services services;
  const LanguagesScreen({super.key, required this.services});

  Future<void> _pick(AppLang lang) async {
    services.sfx.play(Sound.button);
    await services.progress.setLanguageCode(lang.name);
    appLang.value = lang;
  }

  @override
  Widget build(BuildContext context) {
    final p = services.progress;
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(children: [
                RoundButton(
                  icon: Icons.arrow_back_rounded,
                  size: 44,
                  semanticLabel: tr('back'),
                  onTap: () {
                    services.sfx.play(Sound.button);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),
                Flexible(child: FittedBox(child: OutlinedTitle(tr('language'), size: 28))),
              ]),
            ),
            Expanded(
              child: ValueListenableBuilder<AppLang>(
                valueListenable: appLang,
                builder: (context, current, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  children: [
                    for (final lang in AppLang.values)
                      _LangTile(
                        lang: lang,
                        selected: lang == current,
                        onTap: () => _pick(lang),
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final AppLang lang;
  final bool selected;
  final VoidCallback onTap;
  const _LangTile({required this.lang, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.accent : Colors.white.withValues(alpha: 0.12),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const ShapeDecoration(
                  shape: HexBorder(),
                  color: Color(0x33FFFFFF),
                ),
                child: Text(lang.name.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lang.nativeName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(lang.englishName,
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ]),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? Colors.white : Colors.white38,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
