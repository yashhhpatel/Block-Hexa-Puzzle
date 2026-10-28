/// App-wide identifiers. Swap the test ad unit ids for your real ones (and
/// set kUseTestAds = false) before publishing.
library;

/// Google Play subscription that removes ads. Create it in Play Console under
/// Monetize > Subscriptions with a monthly auto-renewing base plan at ₹299.
const String kRemoveAdsProductId = 'remove_ads_monthly';

/// Shown only if Google Play can't be reached to fetch the localized price.
const String kRemoveAdsFallbackPrice = '₹299';

/// Base64 RSA public key from Play Console > Monetize > Monetization setup.
/// Used to check purchase signatures on the device. Leave empty to skip the
/// check (purchases are then trusted as reported by Google Play).
const String kPlayLicenseKey = '';

const String kSupportEmail = 'yashpatel4611@gmail.com';
const String kPrivacyPolicyUrl =
    'https://yashhhpatel.github.io/Block-Hexa-Puzzle/privacy-policy.html';
const String kAndroidPackage = 'com.yashpatel.block_hexa_puzzle';

/// Google's public test ad units. They always fill and never pay out.
const bool kUseTestAds = true;
const String kAppOpenAdUnit = 'ca-app-pub-3940256099942544/9257395921';
const String kInterstitialAdUnit = 'ca-app-pub-3940256099942544/1033173712';
const String kBannerAdUnit = 'ca-app-pub-3940256099942544/6300978111';

/// Show an interstitial after every Nth completed level.
const int kInterstitialEveryLevels = 2;
