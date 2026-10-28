import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local, offline save data: level progress, coins, settings and the
/// in-progress board of the level being played.
class Progress {
  static const hintCost = 25;
  static const levelReward = 5;
  static const startingCoins = 100;

  final SharedPreferences _prefs;
  Progress._(this._prefs);

  static Future<Progress> load() async =>
      Progress._(await SharedPreferences.getInstance());

  /// Highest level the player may open (the next one to beat).
  int get unlockedLevel => _prefs.getInt('unlocked') ?? 1;
  int get currentLevel => _prefs.getInt('current') ?? unlockedLevel;
  int get coins => _prefs.getInt('coins') ?? startingCoins;

  bool get soundOn => _prefs.getBool('sound') ?? true;
  bool get vibrationOn => _prefs.getBool('vibration') ?? true;
  bool get backgroundFx => _prefs.getBool('bgfx') ?? true;
  bool get tutorialSeen => _prefs.getBool('tutorial') ?? false;
  bool get decoyTipSeen => _prefs.getBool('decoyTip') ?? false;

  Future<void> setCurrentLevel(int n) => _prefs.setInt('current', n);
  Future<void> setCoins(int c) => _prefs.setInt('coins', c);
  Future<void> setSound(bool v) => _prefs.setBool('sound', v);
  Future<void> setVibration(bool v) => _prefs.setBool('vibration', v);
  Future<void> setBackgroundFx(bool v) => _prefs.setBool('bgfx', v);
  Future<void> setTutorialSeen() => _prefs.setBool('tutorial', true);
  Future<void> setDecoyTipSeen() => _prefs.setBool('decoyTip', true);

  bool spendCoins(int amount) {
    if (coins < amount) return false;
    setCoins(coins - amount);
    return true;
  }

  /// Records a win; rewards coins only the first time a level is beaten.
  Future<bool> completeLevel(int n) async {
    await clearBoard();
    final firstClear = n >= unlockedLevel;
    if (firstClear) {
      await _prefs.setInt('unlocked', n + 1);
      await setCoins(coins + levelReward);
    }
    return firstClear;
  }

  Map<String, dynamic>? get savedBoard {
    final s = _prefs.getString('board');
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBoard(Map<String, dynamic> json) =>
      _prefs.setString('board', jsonEncode(json));
  Future<void> clearBoard() => _prefs.remove('board');
}
