import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'progress.dart';

enum Sound { pick, place, fail, button, hint, win }

/// Short sound effects and haptics, both switchable in Settings.
class Sfx {
  final Progress progress;
  final Map<Sound, AudioPlayer> _players = {};

  Sfx(this.progress);

  Future<void> init() async {
    for (final s in Sound.values) {
      final p = AudioPlayer(playerId: 'sfx_${s.name}');
      try {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sfx/${s.name}.wav'));
      } catch (_) {
        // Audio is cosmetic; never let a device quirk break the game.
      }
      _players[s] = p;
    }
  }

  void play(Sound s) {
    if (progress.soundOn) {
      final p = _players[s];
      if (p != null) {
        p.stop().then((_) => p.resume()).catchError((_) {});
      }
    }
    if (progress.vibrationOn) {
      switch (s) {
        case Sound.place:
          HapticFeedback.lightImpact();
        case Sound.fail:
          HapticFeedback.mediumImpact();
        case Sound.win:
          HapticFeedback.heavyImpact();
        default:
          break;
      }
    }
  }
}
