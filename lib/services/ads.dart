import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import 'billing.dart';
import 'sfx.dart';

/// AdMob: consent, app-open, interstitial and banner ads.
///
/// Rules:
/// * Nothing loads before the consent (UMP) check allows it.
/// * Remove Ads subscribers see no ads of any kind.
/// * Only one full-screen ad at a time, and no app-open ad within 30 s of
///   another full-screen ad, after tapping an ad, or when returning from the
///   purchase sheet or an external link.
class AdsService {
  final BillingService billing;
  final Sfx sfx;
  final bool enabled;

  /// True once the SDK may serve ads (consent resolved, SDK started).
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// True once the consent/SDK start-up has finished, whatever the outcome.
  final ValueNotifier<bool> settled = ValueNotifier(false);

  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  bool _appOpenLoading = false;
  InterstitialAd? _interstitial;
  bool _interstitialLoading = false;

  bool _fullScreenShowing = false;
  DateTime _lastFullScreenEnd = DateTime.fromMillisecondsSinceEpoch(0);
  bool _skipNextAppOpen = false;
  StreamSubscription<AppState>? _appState;
  final Completer<void> _initDone = Completer();

  AdsService({required this.billing, required this.sfx, this.enabled = true});

  bool get _adsAllowed => enabled && ready.value && !billing.premium.value;

  Future<void> init() async {
    if (!enabled || defaultTargetPlatform != TargetPlatform.android) {
      settled.value = true;
      _initDone.complete();
      return;
    }
    try {
      await _gatherConsent().timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
        ready.value = true;
        if (!billing.premium.value) {
          _loadAppOpen();
          _loadInterstitial();
        }
        AppStateEventNotifier.startListening();
        _appState = AppStateEventNotifier.appStateStream.listen((s) {
          if (s == AppState.foreground) showAppOpenIfAvailable();
        });
      }
    } catch (_) {
      // Ads are optional; the game must work without them.
    }
    billing.premium.addListener(_onPremiumChanged);
    settled.value = true;
    if (!_initDone.isCompleted) _initDone.complete();
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!done.isCompleted) done.complete();
      }),
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  /// Whether Settings should offer "Ad privacy choices" (EEA/UK users).
  Future<bool> privacyOptionsRequired() async {
    if (!enabled) return false;
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) => done.complete());
    return done.future;
  }

  void _onPremiumChanged() {
    if (billing.premium.value) {
      _appOpen?.dispose();
      _appOpen = null;
      _interstitial?.dispose();
      _interstitial = null;
    } else if (ready.value) {
      _loadAppOpen();
      _loadInterstitial();
    }
  }

  /// Call before leaving the app on purpose (purchase sheet, links, email),
  /// so coming back doesn't trigger an app-open ad.
  void skipNextAppOpen() => _skipNextAppOpen = true;

  void dispose() {
    _appState?.cancel();
    billing.premium.removeListener(_onPremiumChanged);
    _appOpen?.dispose();
    _interstitial?.dispose();
  }

  // ---- app open -----------------------------------------------------------

  void _loadAppOpen() {
    if (_appOpenLoading || _appOpen != null || !_adsAllowed) return;
    _appOpenLoading = true;
    AppOpenAd.load(
      adUnitId: kAppOpenAdUnit,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenLoading = false;
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (_) => _appOpenLoading = false,
      ),
    );
  }

  bool get _appOpenFresh =>
      _appOpen != null &&
      DateTime.now().difference(_appOpenLoadedAt!) < const Duration(hours: 4);

  /// Shows the app-open ad on a cold start if one loads within [wait].
  /// Completes when the game may continue.
  Future<void> showAppOpenOnLaunch({
    Duration wait = const Duration(seconds: 5),
  }) async {
    if (!enabled) return;
    await _initDone.future.timeout(wait, onTimeout: () {});
    final deadline = DateTime.now().add(wait);
    while (_adsAllowed && !_appOpenFresh && DateTime.now().isBefore(deadline)) {
      if (!_appOpenLoading) _loadAppOpen();
      await Future.delayed(const Duration(milliseconds: 150));
    }
    await showAppOpenIfAvailable(onLaunch: true);
  }

  Future<void> showAppOpenIfAvailable({bool onLaunch = false}) async {
    if (_skipNextAppOpen && !onLaunch) {
      _skipNextAppOpen = false;
      return;
    }
    if (!_adsAllowed || _fullScreenShowing) return;
    if (DateTime.now().difference(_lastFullScreenEnd) <
        const Duration(seconds: 30))
      return;
    if (!_appOpenFresh) {
      _appOpen?.dispose();
      _appOpen = null;
      _loadAppOpen();
      return;
    }
    final ad = _appOpen!;
    _appOpen = null;
    await _showFullScreen((onEnd) {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          onEnd();
        },
        onAdFailedToShowFullScreenContent: (a, _) {
          a.dispose();
          onEnd();
        },
        onAdClicked: (_) => _skipNextAppOpen = true,
      );
      ad.show();
    });
    _loadAppOpen();
  }

  // ---- interstitial -------------------------------------------------------

  void _loadInterstitial() {
    if (_interstitialLoading || _interstitial != null || !_adsAllowed) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: kInterstitialAdUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (_) => _interstitialLoading = false,
      ),
    );
  }

  bool get interstitialReady => _adsAllowed && _interstitial != null;

  /// Shows a preloaded interstitial. Returns true if one was shown; always
  /// completes once the player is back in the game.
  Future<bool> showInterstitial() async {
    if (!_adsAllowed || _fullScreenShowing) return false;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    var shown = false;
    await _showFullScreen((onEnd) {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) => shown = true,
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          onEnd();
        },
        onAdFailedToShowFullScreenContent: (a, _) {
          a.dispose();
          onEnd();
        },
        onAdClicked: (_) => _skipNextAppOpen = true,
      );
      ad.show();
    });
    _loadInterstitial();
    return shown;
  }

  /// Runs a full-screen ad: pauses music, blocks other ads, and completes
  /// when the ad ends (with a safety timeout so the game never hangs).
  Future<void> _showFullScreen(void Function(VoidCallback onEnd) start) async {
    _fullScreenShowing = true;
    sfx.setAdShowing(true);
    final done = Completer<void>();
    void end() {
      if (!done.isCompleted) done.complete();
    }

    try {
      start(end);
    } catch (_) {
      end();
    }
    await done.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    _fullScreenShowing = false;
    _lastFullScreenEnd = DateTime.now();
    sfx.setAdShowing(false);
  }
}

/// Standard 320×50 banner. Reserves exactly the banner's height while it
/// loads or shows, and collapses to nothing for subscribers or if no ad fills,
/// so content never jumps under an ad or leaves a stray gap.
class AdBanner extends StatefulWidget {
  final AdsService ads;
  const AdBanner({super.key, required this.ads});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;

  AdsService get ads => widget.ads;

  @override
  void initState() {
    super.initState();
    ads.ready.addListener(_sync);
    ads.settled.addListener(_sync);
    ads.billing.premium.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    ads.ready.removeListener(_sync);
    ads.settled.removeListener(_sync);
    ads.billing.premium.removeListener(_sync);
    _ad?.dispose();
    super.dispose();
  }

  /// No space is kept once it's clear no ad can come (subscriber, no fill,
  /// or consent didn't allow ads).
  bool get _wanted =>
      ads.enabled &&
      !ads.billing.premium.value &&
      !_failed &&
      !(ads.settled.value && !ads.ready.value);

  void _sync() {
    if (!_wanted) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
    } else if (ads.ready.value && _ad == null) {
      _ad = BannerAd(
        size: AdSize.banner,
        adUnitId: kBannerAdUnit,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _ad = null;
              _failed = true;
            });
          },
          onAdClicked: (_) => ads.skipNextAppOpen(),
        ),
      )..load();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_wanted) return const SizedBox.shrink();
    final h = AdSize.banner.height.toDouble();
    return SizedBox(
      height: h,
      width: double.infinity,
      child: _loaded && _ad != null
          ? Center(
              child: SizedBox(
                width: AdSize.banner.width.toDouble(),
                height: h,
                child: AdWidget(ad: _ad!),
              ),
            )
          : null,
    );
  }
}
