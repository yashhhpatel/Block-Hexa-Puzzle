import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'progress.dart';

enum Sound { pick, place, fail, button, hint, win, star, coin, undo }

/// Sound effects, background music and haptics, each switchable in Settings.
class Sfx {
  final Progress progress;
  final Map<Sound, AudioPlayer> _players = {};
  AudioPlayer? _music;
  bool _appVisible = true;
  bool _adShowing = false;

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
    try {
      final m = AudioPlayer(playerId: 'music');
      await m.setReleaseMode(ReleaseMode.loop);
      await m.setVolume(0.35);
      await m.setSource(AssetSource('music/calm.wav'));
      // Don't steal audio focus from the player's own music apps.
      await m.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.music,
          ),
        ),
      );
      _music = m;
    } catch (_) {}
    updateMusic();
  }

  /// Starts or pauses music to match the setting and app visibility.
  void updateMusic() {
    final m = _music;
    if (m == null) return;
    if (progress.musicOn && _appVisible && !_adShowing) {
      m.setVolume(0.35 * progress.musicVolume).catchError((_) {});
      m.resume().catchError((_) {});
    } else {
      m.pause().catchError((_) {});
    }
  }

  /// Full-screen ads have their own sound, so music pauses meanwhile.
  void setAdShowing(bool showing) {
    _adShowing = showing;
    updateMusic();
  }

  void setAppVisible(bool visible) {
    _appVisible = visible;
    updateMusic();
  }

  void play(Sound s) {
    if (progress.soundOn) {
      final p = _players[s];
      if (p != null) {
        p
            .stop()
            .then((_) => p.setVolume(progress.soundVolume))
            .then((_) => p.resume())
            .catchError((_) {});
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
        case Sound.star:
          HapticFeedback.selectionClick();
        default:
          break;
      }
    }
  }
}
