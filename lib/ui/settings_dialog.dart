import 'package:flutter/material.dart';

import '../services/services.dart';
import '../services/sfx.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showSettingsDialog(BuildContext context, Services services) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Settings',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => _SettingsPanel(services: services),
    transitionBuilder: (_, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}

class _SettingsPanel extends StatefulWidget {
  final Services services;
  const _SettingsPanel({required this.services});

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  @override
  Widget build(BuildContext context) {
    final p = widget.services.progress;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
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
              Row(
                children: [
                  const SizedBox(width: 32),
                  const Expanded(
                    child: Center(child: OutlinedTitle('Settings', size: 26)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _toggle('Music', Icons.music_note_rounded, p.musicOn, (v) async {
                await p.setMusic(v);
                widget.services.sfx.updateMusic();
              }),
              _toggle(
                'Sound effects',
                Icons.volume_up_rounded,
                p.soundOn,
                (v) => p.setSound(v),
              ),
              _toggle(
                'Vibration',
                Icons.vibration_rounded,
                p.vibrationOn,
                (v) => p.setVibration(v),
              ),
              _toggle(
                'Background effect',
                Icons.auto_awesome_rounded,
                p.backgroundFx,
                (v) => p.setBackgroundFx(v),
              ),
              const SizedBox(height: 14),
              PillButton(
                label: 'How to play',
                icon: Icons.school_rounded,
                width: 220,
                color: const Color(0xFF7A55F0),
                dark: const Color(0xFF4A2BB0),
                onTap: () => _howTo(context),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              widget.services.sfx.play(Sound.button);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void _howTo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF15276A),
        title: const Text(
          'How to play',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          '• Drag blocks from the tray onto the board.\n'
          '• Fill every empty cell to clear the level.\n'
          '• Blocks cannot be rotated.\n'
          '• Drag a placed block to move it or put it back.\n'
          '• Some tricky levels have spare blocks you won\'t need.\n'
          '• Stuck? Undo is free; a hint places one block for 25 coins.\n'
          '• Earn up to 3 stars: clear it, use no hints, beat the target time.\n'
          '• Come back daily for the Daily Puzzle, quests and login rewards.',
          style: TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
