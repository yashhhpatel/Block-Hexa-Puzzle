import '../l10n/l10n.dart';
import 'ads.dart';
import 'billing.dart';
import 'progress.dart';
import 'sfx.dart';

/// App-wide services, created once at startup and passed to screens.
class Services {
  final Progress progress;
  final Sfx sfx;
  final BillingService billing;
  final AdsService ads;

  Services(this.progress, this.sfx, this.billing, this.ads);

  /// Offline, ad-free services for tests and previews.
  factory Services.offline(Progress progress) {
    final sfx = Sfx(progress);
    final billing = BillingService(progress, enabled: false);
    return Services(
      progress,
      sfx,
      billing,
      AdsService(billing: billing, sfx: sfx, enabled: false),
    );
  }

  static Future<Services> create({required AppLang deviceLang}) async {
    final progress = await Progress.load();
    appLang.value = AppLang.byCode(progress.languageCode) ?? deviceLang;
    final sfx = Sfx(progress);
    final billing = BillingService(progress);
    final ads = AdsService(billing: billing, sfx: sfx);
    // Audio, billing and ads start in the background so the first screen
    // appears at once. They run side by side: subscribers are already known
    // from the saved status, so no ad shows while billing is still checking.
    sfx.init();
    billing.init();
    ads.init();
    return Services(progress, sfx, billing, ads);
  }
}
