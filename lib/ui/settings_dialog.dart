import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'how_to_play_screen.dart';
import 'languages_screen.dart';
import 'remove_ads_screen.dart';
import 'stats_screen.dart';
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
Future<void> openExternal(
  BuildContext context,
  Services services,
  Uri uri, {
  String? failMessage,
}) async {
  services.ads.skipNextAppOpen();
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failMessage ?? tr('link_error'))));
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
        'body':
            '${tr('contact_body')}\n\n\n'
            '— ${tr('app_title')} · ${appLang.value.englishName}',
      }),
    );
    await openExternal(
      context,
      s,
      uri,
      failMessage: tr('contact_no_email', {'email': kSupportEmail}),
    );
  }

  Future<void> _rate() async {
    s.sfx.play(Sound.button);
    s.ads.skipNextAppOpen();
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse('market://details?id=$kAndroidPackage'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (ok || !mounted) return;
    await openExternal(
      context,
      s,
      Uri.parse(
        'https://play.google.com/store/apps/details?id=$kAndroidPackage',
      ),
    );
  }

  void _about() {
    s.sfx.play(Sound.button);
    showAboutDialog(
      context: context,
      applicationName: tr('app_title'),
      applicationVersion: tr('version', {'v': kAppVersion}),
      applicationIcon: const Icon(
        Icons.hexagon_rounded,
        color: AppColors.accent,
        size: 44,
      ),
      applicationLegalese: kSupportEmail,
    );
  }

  /// Two confirmations, since a reset cannot be undone.
  Future<void> _reset() async {
    s.sfx.play(Sound.button);
    Future<bool> ask(String body) async =>
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF15276A),
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF7A6E),
              size: 40,
            ),
            title: Text(
              tr('reset_confirm_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE5483B),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('reset_btn')),
              ),
            ],
          ),
        ) ??
        false;

    if (!await ask(tr('reset_confirm_body')) || !mounted) return;
    if (!await ask(tr('reset_confirm_final')) || !mounted) return;
    await s.progress.resetProgress();
    await s.reminders.reschedule();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    messenger.showSnackBar(SnackBar(content: Text(tr('reset_done'))));
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    const SizedBox(width: 32),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          child: OutlinedTitle(tr('settings'), size: 26),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('close'),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _slider(
                        tr('music'),
                        Icons.music_note_rounded,
                        Icons.music_off_rounded,
                        p.musicVolume,
                        (v) async {
                          await p.setMusicVolume(v);
                          s.sfx.updateMusic();
                        },
                      ),
                      _slider(
                        tr('sound_effects'),
                        Icons.volume_up_rounded,
                        Icons.volume_off_rounded,
                        p.soundVolume,
                        p.setSoundVolume,
                        // A short click so the new loudness can be heard.
                        onDone: () => s.sfx.play(Sound.button),
                      ),
                      _toggle(
                        tr('vibration'),
                        Icons.vibration_rounded,
                        p.vibrationOn,
                        p.setVibration,
                      ),
                      _toggle(
                        tr('background_effect'),
                        Icons.auto_awesome_rounded,
                        p.backgroundFx,
                        p.setBackgroundFx,
                      ),
                      _toggle(
                        tr('reduce_motion'),
                        Icons.motion_photos_off_rounded,
                        p.reduceMotion,
                        p.setReduceMotion,
                      ),
                      _toggle(
                        tr('color_blind'),
                        Icons.category_rounded,
                        p.colorBlind,
                        p.setColorBlind,
                      ),
                      _toggle(
                        tr('daily_reminder'),
                        Icons.notifications_active_rounded,
                        p.remindersOn,
                        (v) async {
                          await p.setReminders(v);
                          if (v) await s.reminders.requestPermission();
                          await s.reminders.reschedule();
                        },
                      ),
                      const SizedBox(height: 10),
                      _RemoveAdsTile(
                        premium: s.billing.premium.value,
                        onTap: () => _push(RemoveAdsScreen(services: s)),
                      ),
                      const SizedBox(height: 8),
                      _row(
                        Icons.bar_chart_rounded,
                        tr('statistics'),
                        onTap: () => _push(StatsScreen(services: s)),
                      ),
                      _row(
                        Icons.translate_rounded,
                        tr('language'),
                        trailing: appLang.value.nativeName,
                        onTap: () => _push(LanguagesScreen(services: s)),
                      ),
                      _row(
                        Icons.school_rounded,
                        tr('how_to_play'),
                        onTap: () => _push(HowToPlayScreen(services: s)),
                      ),
                      _row(
                        Icons.mail_rounded,
                        tr('contact_us'),
                        onTap: _contact,
                      ),
                      _row(
                        Icons.privacy_tip_rounded,
                        tr('privacy_policy'),
                        onTap: () {
                          s.sfx.play(Sound.button);
                          openExternal(
                            context,
                            s,
                            Uri.parse(kPrivacyPolicyUrl),
                          );
                        },
                      ),
                      _row(
                        Icons.star_rate_rounded,
                        tr('rate_us'),
                        onTap: _rate,
                      ),
                      _row(
                        Icons.info_outline_rounded,
                        tr('about'),
                        trailing: tr('version', {'v': kAppVersion}),
                        onTap: _about,
                      ),
                      _row(
                        Icons.restart_alt_rounded,
                        tr('reset_progress'),
                        danger: true,
                        onTap: _reset,
                      ),
                      if (_adPrivacy)
                        _row(
                          Icons.shield_rounded,
                          tr('ad_privacy'),
                          onTap: () {
                            s.sfx.play(Sound.button);
                            s.ads.showPrivacyOptions();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(
    String label,
    IconData icon,
    bool value,
    Future<void> Function(bool) save,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
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
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    IconData icon,
    IconData offIcon,
    double value,
    Future<void> Function(double) save, {
    VoidCallback? onDone,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(value == 0 ? offIcon : icon, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: value,
                    divisions: 10,
                    semanticFormatterCallback: (v) => '${(v * 100).round()}%',
                    onChanged: (v) async {
                      await save(v);
                      setState(() {});
                    },
                    onChangeEnd: (_) => onDone?.call(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label, {
    String? trailing,
    bool danger = false,
    required VoidCallback onTap,
  }) {
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
            child: Row(
              children: [
                Icon(
                  icon,
                  color: danger ? const Color(0xFFFF7A6E) : AppColors.boardLine,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: danger ? const Color(0xFFFF9C93) : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        trailing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
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
        child: Row(
          children: [
            Icon(
              premium ? Icons.verified_rounded : Icons.block_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                premium ? tr('ra_active') : tr('remove_ads'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
