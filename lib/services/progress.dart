import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../game/level.dart';
import '../meta/chapters.dart';
import '../meta/cosmetics.dart';
import '../meta/quests.dart';

int dayKeyOf(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
DateTime dateOfKey(int k) => DateTime(k ~/ 10000, (k ~/ 100) % 100, k % 100);

/// Whole calendar days from [a] to [b] (DST-safe).
int daysBetween(int a, int b) {
  final da = dateOfKey(a), db = dateOfKey(b);
  return DateTime.utc(
    db.year,
    db.month,
    db.day,
  ).difference(DateTime.utc(da.year, da.month, da.day)).inDays;
}

/// Everything that happened when a level was cleared, for the win screen.
class WinSummary {
  final int stars;
  final int previousStars;
  final bool firstClear;
  final bool noHints;
  final bool underPar;
  final int coins;
  final int chestProgress; // after this win, 0..chestSize-1
  final int? chestReward;
  final Chapter? chapterCompleted;
  final int? dailyStreak;
  final int? streakBonus;

  const WinSummary({
    required this.stars,
    required this.previousStars,
    required this.firstClear,
    required this.noHints,
    required this.underPar,
    required this.coins,
    required this.chestProgress,
    this.chestReward,
    this.chapterCompleted,
    this.dailyStreak,
    this.streakBonus,
  });

  bool get newBest => stars > previousStars;
}

/// A newly reached achievement tier, for the unlock notification.
class AchievementUnlock {
  final AchievementDef def;
  final int target;
  final int reward;
  const AchievementUnlock(this.def, this.target, this.reward);
}

class QuestStatus {
  final QuestDef def;
  final int progress;
  final bool claimed;
  QuestStatus(this.def, this.progress, this.claimed);
  bool get done => progress >= def.target;
  bool get claimable => done && !claimed;
}

class AchievementStatus {
  final AchievementDef def;
  final int value;
  final int claimedTiers;
  AchievementStatus(this.def, this.value, this.claimedTiers);

  bool get maxed => claimedTiers >= def.tiers.length;
  int get target => def.tiers[math.min(claimedTiers, def.tiers.length - 1)];
  int get reward => def.rewards[math.min(claimedTiers, def.rewards.length - 1)];
  bool get claimable => !maxed && value >= target;
}

/// Local, offline save data and the rules for earning and spending it.
class Progress {
  static const firstClearReward = 5;
  static const coinsPerNewStar = 3;
  static const startingCoins = 100;
  static const chestSize = 10;
  static const dailyReward = 15;
  static const loginRewards = [10, 15, 20, 25, 30, 40, 75];

  final SharedPreferences _prefs;

  /// Injectable clock so day-based features can be tested.
  final DateTime Function() now;

  Progress._(this._prefs, this.now);

  static Future<Progress> load({DateTime Function()? clock}) async {
    final p = Progress._(
      await SharedPreferences.getInstance(),
      clock ?? DateTime.now,
    );
    await p._seedAchievements();
    return p;
  }

  final _unlocks = StreamController<AchievementUnlock>.broadcast();

  /// Fires whenever play pushes an achievement past a new tier.
  Stream<AchievementUnlock> get achievementUnlocks => _unlocks.stream;

  int get today => dayKeyOf(now());

  // ---- basics -------------------------------------------------------------

  int get unlockedLevel => _prefs.getInt('unlocked') ?? 1;
  int get currentLevel => _prefs.getInt('current') ?? unlockedLevel;
  int get coins => _prefs.getInt('coins') ?? startingCoins;

  Future<void> setCurrentLevel(int n) => _prefs.setInt('current', n);
  Future<void> setCoins(int c) => _prefs.setInt('coins', c);
  Future<void> addCoins(int c) => setCoins(coins + c);

  bool spendCoins(int amount) {
    if (coins < amount) return false;
    setCoins(coins - amount);
    return true;
  }

  // ---- settings -----------------------------------------------------------

  bool get soundOn => _prefs.getBool('sound') ?? true;
  bool get musicOn => _prefs.getBool('music') ?? true;
  bool get vibrationOn => _prefs.getBool('vibration') ?? true;
  bool get backgroundFx => _prefs.getBool('bgfx') ?? true;
  bool get tutorialSeen => _prefs.getBool('tutorial') ?? false;
  bool get decoyTipSeen => _prefs.getBool('decoyTip') ?? false;

  Future<void> setSound(bool v) => _prefs.setBool('sound', v);
  Future<void> setMusic(bool v) => _prefs.setBool('music', v);
  Future<void> setVibration(bool v) => _prefs.setBool('vibration', v);
  Future<void> setBackgroundFx(bool v) => _prefs.setBool('bgfx', v);
  Future<void> setTutorialSeen() => _prefs.setBool('tutorial', true);
  Future<void> setDecoyTipSeen() => _prefs.setBool('decoyTip', true);

  // ---- json helpers -------------------------------------------------------

  Map<String, dynamic> _map(String key) {
    final s = _prefs.getString(key);
    if (s == null) return {};
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _putMap(String key, Map<String, dynamic> m) =>
      _prefs.setString(key, jsonEncode(m));

  // ---- stars --------------------------------------------------------------

  int starsFor(int level) => (_map('stars')['$level'] as int?) ?? 0;

  int get totalStars =>
      _map('stars').values.fold<int>(0, (s, v) => s + (v as int));

  int starsInChapter(Chapter c) {
    final m = _map('stars');
    var t = 0;
    for (var n = c.first; n <= c.last; n++) {
      t += (m['$n'] as int?) ?? 0;
    }
    return t;
  }

  /// 1 star for clearing, +1 for no hints, +1 for beating the target time.
  static int starsFor3(bool noHints, bool underPar) =>
      1 + (noHints ? 1 : 0) + (underPar ? 1 : 0);

  // ---- stats --------------------------------------------------------------

  int stat(Stat s) => (_map('stats')[s.name] as int?) ?? 0;

  /// Adds to a lifetime stat and to today's quest counters.
  Future<void> _bump(Stat s, int by) async {
    if (by <= 0) return;
    final stats = _map('stats');
    stats[s.name] = ((stats[s.name] as int?) ?? 0) + by;
    await _putMap('stats', stats);

    final q = _questState();
    final prog = (q['progress'] as Map<String, dynamic>);
    prog[s.name] = ((prog[s.name] as int?) ?? 0) + by;
    await _putMap('quests', q);
    await _checkUnlocks(s);
  }

  int _tiersReached(AchievementDef a) {
    final v = stat(a.stat);
    return a.tiers.where((t) => v >= t).length;
  }

  /// Marks tiers that were already reached before this version as seen, so
  /// updating the game doesn't fire a burst of old unlocks.
  Future<void> _seedAchievements() async {
    final seen = _map('achSeen');
    var changed = false;
    for (final a in Quests.achievements) {
      if (seen.containsKey(a.id)) continue;
      seen[a.id] = _tiersReached(a);
      changed = true;
    }
    if (changed) await _putMap('achSeen', seen);
  }

  Future<void> _checkUnlocks(Stat s) async {
    final seen = _map('achSeen');
    var changed = false;
    for (final a in Quests.achievements) {
      if (a.stat != s) continue;
      final reached = _tiersReached(a);
      final before = (seen[a.id] as int?) ?? 0;
      if (reached <= before) continue;
      seen[a.id] = reached;
      changed = true;
      if (!_unlocks.isClosed) {
        _unlocks.add(
          AchievementUnlock(a, a.tiers[reached - 1], a.rewards[reached - 1]),
        );
      }
    }
    if (changed) await _putMap('achSeen', seen);
  }

  Future<void> _setMax(Stat s, int value) async {
    final stats = _map('stats');
    if (((stats[s.name] as int?) ?? 0) >= value) return;
    stats[s.name] = value;
    await _putMap('stats', stats);
    await _checkUnlocks(s);
  }

  /// Counts blocks placed during play (feeds quests and achievements).
  Future<void> recordBlocksPlaced(int n) => _bump(Stat.blocksPlaced, n);

  // ---- level wins ---------------------------------------------------------

  /// Records a cleared main level. Only first clears and star improvements
  /// count toward quests and rewards, so replaying easy levels can't farm.
  Future<WinSummary> recordLevelWin(
    Level level, {
    required int seconds,
    required int hintsUsed,
  }) async {
    final n = level.number;
    await clearBoard();
    final noHints = hintsUsed == 0;
    final underPar = seconds <= level.parSeconds;
    final stars = starsFor3(noHints, underPar);
    final prev = starsFor(n);
    final firstClear = n >= unlockedLevel;
    var coinsWon = 0;

    if (stars > prev) {
      final m = _map('stars')..['$n'] = stars;
      await _putMap('stars', m);
      await _bump(Stat.starsEarned, stars - prev);
      coinsWon += (stars - prev) * coinsPerNewStar;
      if (stars == 3) await _bump(Stat.threeStarLevels, 1);
    }

    int? chestReward;
    Chapter? chapterDone;
    if (firstClear) {
      await _prefs.setInt('unlocked', n + 1);
      coinsWon += firstClearReward;
      await _bump(Stat.levelsCleared, 1);

      var chest = (_prefs.getInt('chest') ?? 0) + 1;
      if (chest >= chestSize) {
        chest = 0;
        chestReward = 30 + math.Random(n).nextInt(51); // 30..80
        coinsWon += chestReward;
        await _bump(Stat.chestsOpened, 1);
      }
      await _prefs.setInt('chest', chest);

      final chapter = Chapters.forLevel(n);
      if (n == chapter.last) {
        chapterDone = chapter;
        coinsWon += chapter.reward;
        await _bump(Stat.chaptersCompleted, 1);
      }
    }
    if (firstClear || stars > prev) {
      if (noHints) await _bump(Stat.noHintClears, 1);
      if (underPar) await _bump(Stat.fastClears, 1);
    }

    await addCoins(coinsWon);
    return WinSummary(
      stars: stars,
      previousStars: prev,
      firstClear: firstClear,
      noHints: noHints,
      underPar: underPar,
      coins: coinsWon,
      chestProgress: chestProgress,
      chestReward: chestReward,
      chapterCompleted: chapterDone,
    );
  }

  int get chestProgress => _prefs.getInt('chest') ?? 0;

  // ---- daily puzzle -------------------------------------------------------

  Set<int> get dailySolved =>
      (_prefs.getStringList('dailySolved') ?? const []).map(int.parse).toSet();

  bool isDailySolved(int key) => dailySolved.contains(key);

  /// Current streak; it survives until the end of the day after the last
  /// solve, so it doesn't reset at midnight before the player has had a go.
  int get streak {
    final last = _prefs.getInt('streakLast');
    if (last == null) return 0;
    final gap = daysBetween(last, today);
    return gap <= 1 ? (_prefs.getInt('streak') ?? 0) : 0;
  }

  static int streakBonusFor(int streak) {
    if (streak == 3) return 30;
    if (streak == 7) return 75;
    if (streak == 14) return 120;
    if (streak > 0 && streak % 30 == 0) return 300;
    return 0;
  }

  /// Records a solved daily. Only today's puzzle extends the streak; older
  /// days of this month can be caught up for coins.
  Future<WinSummary> recordDailyWin(
    Level level, {
    required int seconds,
    required int hintsUsed,
  }) async {
    final key = level.dailyKey!;
    final already = isDailySolved(key);
    var coinsWon = 0;
    int? streakNow;
    int? bonus;
    if (!already) {
      final solved = dailySolved..add(key);
      await _prefs.setStringList(
        'dailySolved',
        solved.map((k) => '$k').toList(),
      );
      coinsWon += key == today ? dailyReward : dailyReward ~/ 2;
      await _bump(Stat.dailyPlayed, 1);
      if (hintsUsed == 0 && seconds <= level.parSeconds) {
        await _bump(Stat.dailyPerfect, 1);
      }
      if (key == today) {
        final last = _prefs.getInt('streakLast');
        final s = (last != null && daysBetween(last, today) == 1)
            ? (_prefs.getInt('streak') ?? 0) + 1
            : 1;
        await _prefs.setInt('streak', s);
        await _prefs.setInt('streakLast', today);
        await _setMax(Stat.bestStreak, s);
        streakNow = s;
        bonus = streakBonusFor(s);
        coinsWon += bonus;
      }
    }
    await addCoins(coinsWon);
    final noHints = hintsUsed == 0;
    final underPar = seconds <= level.parSeconds;
    return WinSummary(
      stars: starsFor3(noHints, underPar),
      previousStars: 0,
      firstClear: !already,
      noHints: noHints,
      underPar: underPar,
      coins: coinsWon,
      chestProgress: chestProgress,
      dailyStreak: streakNow,
      streakBonus: (bonus ?? 0) > 0 ? bonus : null,
    );
  }

  // ---- quests & achievements ---------------------------------------------

  /// Today's quest state; rolls over automatically at midnight.
  Map<String, dynamic> _questState() {
    final q = _map('quests');
    if (q['day'] != today) {
      return {
        'day': today,
        'progress': <String, dynamic>{},
        'claimed': <dynamic>[],
      };
    }
    return q;
  }

  List<QuestStatus> get todayQuests {
    final q = _questState();
    final prog = q['progress'] as Map<String, dynamic>;
    final claimed = (q['claimed'] as List<dynamic>).cast<String>();
    return [
      for (final d in Quests.forDay(today))
        QuestStatus(
          d,
          (prog[d.stat.name] as int?) ?? 0,
          claimed.contains(d.id),
        ),
    ];
  }

  bool get allQuestsBonusClaimed =>
      (_questState()['claimed'] as List<dynamic>).contains('all');

  bool get allQuestsBonusClaimable =>
      !allQuestsBonusClaimed && todayQuests.every((q) => q.claimed);

  Future<int> claimQuest(String id) async {
    final q = _questState();
    final claimed = (q['claimed'] as List<dynamic>).cast<String>().toList();
    int reward;
    if (id == 'all') {
      if (!allQuestsBonusClaimable) return 0;
      reward = Quests.allDoneBonus;
    } else {
      final status = todayQuests.firstWhere((s) => s.def.id == id);
      if (!status.claimable) return 0;
      reward = status.def.reward;
    }
    claimed.add(id);
    q['claimed'] = claimed;
    await _putMap('quests', q);
    await addCoins(reward);
    if (id != 'all') await _bump(Stat.questsCompleted, 1);
    return reward;
  }

  List<AchievementStatus> get achievements {
    final claimed = _map('achievements');
    return [
      for (final a in Quests.achievements)
        AchievementStatus(a, stat(a.stat), (claimed[a.id] as int?) ?? 0),
    ];
  }

  Future<int> claimAchievement(String id) async {
    final status = achievements.firstWhere((a) => a.def.id == id);
    if (!status.claimable) return 0;
    final claimed = _map('achievements')..[id] = status.claimedTiers + 1;
    await _putMap('achievements', claimed);
    await addCoins(status.reward);
    return status.reward;
  }

  int get claimableRewards =>
      todayQuests.where((q) => q.claimable).length +
      (allQuestsBonusClaimable ? 1 : 0) +
      achievements.where((a) => a.claimable).length;

  // ---- daily login bonus --------------------------------------------------

  /// Index (0..6) of today's login reward, or null if already claimed.
  int? get pendingLoginDay {
    final last = _prefs.getInt('loginLast');
    if (last == today) return null;
    final idx = _prefs.getInt('loginIndex') ?? -1;
    if (last != null && daysBetween(last, today) == 1) {
      return (idx + 1) % loginRewards.length;
    }
    return 0;
  }

  Future<int> claimLoginBonus() async {
    final day = pendingLoginDay;
    if (day == null) return 0;
    await _prefs.setInt('loginLast', today);
    await _prefs.setInt('loginIndex', day);
    await addCoins(loginRewards[day]);
    await _bump(Stat.loginDays, 1);
    return loginRewards[day];
  }

  // ---- shop ---------------------------------------------------------------

  Set<String> get owned => {'gem', 'ocean', ...?_prefs.getStringList('owned')};

  bool isUnlocked(ShopItem item) =>
      owned.contains(item.id) ||
      (item.price == 0 && totalStars >= item.starsRequired);

  /// Buys (or star-unlocks) an item. Returns false if it can't be afforded.
  Future<bool> unlock(ShopItem item) async {
    if (isUnlocked(item)) return true;
    if (item.starsRequired > 0 && totalStars < item.starsRequired) return false;
    if (item.price > 0 && !spendCoins(item.price)) return false;
    await _prefs.setStringList('owned', [...owned, item.id]);
    await _bump(Stat.itemsUnlocked, 1);
    return true;
  }

  String get skinId => _prefs.getString('skin') ?? 'gem';
  String get themeId => _prefs.getString('theme') ?? 'ocean';
  BlockSkin get skin => Cosmetics.skin(skinId);
  BoardTheme get theme => Cosmetics.theme(themeId);

  Future<void> equip(ShopItem item) async {
    if (!isUnlocked(item)) return;
    await _prefs.setString(item is BlockSkin ? 'skin' : 'theme', item.id);
  }

  // ---- language -----------------------------------------------------------

  /// Saved language code, or null to follow the phone's language.
  String? get languageCode => _prefs.getString('lang');
  Future<void> setLanguageCode(String code) => _prefs.setString('lang', code);

  // ---- ads & subscription -------------------------------------------------

  /// Last known Remove Ads state, kept so it works offline.
  bool get premiumCached => _prefs.getBool('premium') ?? false;

  /// When Google Play last confirmed the subscription (ms since epoch).
  int get premiumCheckedAt => _prefs.getInt('premiumChecked') ?? 0;

  Future<void> setPremium(bool active, {bool confirmed = true}) async {
    await _prefs.setBool('premium', active);
    if (confirmed) {
      await _prefs.setInt('premiumChecked', now().millisecondsSinceEpoch);
    }
  }

  /// Completed levels since the last interstitial.
  int get levelsSinceAd => _prefs.getInt('levelsSinceAd') ?? 0;
  Future<void> setLevelsSinceAd(int n) => _prefs.setInt('levelsSinceAd', n);

  // ---- in-progress board --------------------------------------------------

  Map<String, dynamic>? get savedBoard {
    final m = _map('board');
    return m.isEmpty ? null : m;
  }

  Future<void> saveBoard(Map<String, dynamic> json) => _putMap('board', json);
  Future<void> clearBoard() => _prefs.remove('board');
}
