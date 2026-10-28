import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'how_to_play_screen.dart';
import 'languages_screen.dart';
import 'remove_ads_screen.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showSettingsDialog(BuildContext context, Services services) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: tr('settings'),
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => _SettingsPanel(services: services),
    transitionBuilder: (_, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}

/// Opens an external link or email app; tells the player if nothing could.
Future<void> openExternal(BuildContext context, Services services, Uri uri,
    {String? failMessage}) async {
  services.ads.skipNextAppOpen();
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failMessage ?? tr('link_error'))),
    );
  }
}

class _SettingsPanel extends StatefulWidget {
  final Services services;
  const _SettingsPanel({required this.services});

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  bool _adPrivacy = false;

  Services get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.ads.privacyOptionsRequired().then((v) {
      if (mounted) setState(() => _adPrivacy = v);
    });
  }

  Future<void> _push(Widget screen) async {
    s.sfx.play(Sound.button);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  Future<void> _contact() async {
    s.sfx.play(Sound.button);
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      query: _encodeQuery({
        'subject': tr('contact_subject'),
        'body': '${tr('contact_body')}\n\n\n'
            '— ${tr('app_title')} · ${appLang.value.englishName}',
      }),
    );
    await openExternal(context, s, uri,
        failMessage: tr('contact_no_email', {'email': kSupportEmail}));
  }

  // mailto needs %20 for spaces, which Uri.queryParameters doesn't produce.
  static String _encodeQuery(Map<String, String> q) => q.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');

  @override
  Widget build(BuildContext context) {
    final p = s.progress;
    final size = MediaQuery.sizeOf(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          constraints: BoxConstraints(maxHeight: size.height * 0.86),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF233F9A), Color(0xFF15276A)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.boardLine, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Center(
                      child: FittedBox(child: OutlinedTitle(tr('settings'), size: 26))),
                ),
                IconButton(
                  tooltip: tr('close'),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _toggle(tr('music'), Icons.music_note_rounded, p.musicOn, (v) async {
                    await p.setMusic(v);
                    s.sfx.updateMusic();
                  }),
                  _toggle(tr('sound_effects'), Icons.volume_up_rounded, p.soundOn,
                      p.setSound),
                  _toggle(tr('vibration'), Icons.vibration_rounded, p.vibrationOn,
                      p.setVibration),
                  _toggle(tr('background_effect'), Icons.auto_awesome_rounded,
                      p.backgroundFx, p.setBackgroundFx),
                  const SizedBox(height: 10),
                  _RemoveAdsTile(
                    premium: s.billing.premium.value,
                    onTap: () => _push(RemoveAdsScreen(services: s)),
                  ),
                  const SizedBox(height: 8),
                  _row(Icons.translate_rounded, tr('language'),
                      trailing: appLang.value.nativeName,
                      onTap: () => _push(LanguagesScreen(services: s))),
                  _row(Icons.school_rounded, tr('how_to_play'),
                      onTap: () => _push(HowToPlayScreen(services: s))),
                  _row(Icons.mail_rounded, tr('contact_us'), onTap: _contact),
                  _row(Icons.privacy_tip_rounded, tr('privacy_policy'), onTap: () {
                    s.sfx.play(Sound.button);
                    openExternal(context, s, Uri.parse(kPrivacyPolicyUrl));
                  }),
                  if (_adPrivacy)
                    _row(Icons.shield_rounded, tr('ad_privacy'), onTap: () {
                      s.sfx.play(Sound.button);
                      s.ads.showPrivacyOptions();
                    }),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _toggle(String label, IconData icon, bool value,
      Future<void> Function(bool) save) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Switch(
          value: value,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.accent,
          onChanged: (v) async {
            await save(v);
            s.sfx.play(Sound.button);
            setState(() {});
          },
        ),
      ]),
    );
  }

  Widget _row(IconData icon, String label, {String? trailing, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Icon(icon, color: AppColors.boardLine, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(trailing,
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RemoveAdsTile extends StatelessWidget {
  final bool premium;
  final VoidCallback onTap;
  const _RemoveAdsTile({required this.premium, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: premium
                ? const [Color(0xFF2FB58A), Color(0xFF1B7F62)]
                : const [Color(0xFFFFB648), Color(0xFFFF6A3D)],
          ),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Row(children: [
          Icon(premium ? Icons.verified_rounded : Icons.block_rounded,
              color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(premium ? tr('ra_active') : tr('remove_ads'),
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
    );
  }
}
