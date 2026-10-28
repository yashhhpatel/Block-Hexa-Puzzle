import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../config.dart';
import 'play_signature.dart';
import 'progress.dart';

/// Outcomes the Remove Ads screen tells the player about.
enum BillingNotice {
  success,
  pending,
  canceled,
  failed,
  verifyFailed,
  restoredOk,
  restoredNone,
  expired,
  storeUnavailable,
  productUnavailable,
}

/// Google Play Billing for the monthly Remove Ads subscription.
///
/// * Buying: launches the Play purchase sheet for the base plan.
/// * Verifying: checks the purchase signature (if a license key is set) and
///   that it is for our product, then acknowledges it so Play doesn't refund.
/// * Status: on every start and resume, asks Play which subscriptions are
///   active. Play only returns subscriptions still in their paid period
///   (including cancelled-but-not-yet-ended and grace period), so anything
///   missing has expired, been refunded or revoked, and ads come back.
class BillingService {
  final Progress progress;

  /// False in tests/previews: no Google Play connection is ever opened.
  final bool enabled;
  final InAppPurchase? _iapOverride;
  late final InAppPurchase _iap = _iapOverride ?? InAppPurchase.instance;

  /// True while ads should be hidden.
  final ValueNotifier<bool> premium;

  /// True while a purchase is waiting on payment (e.g. cash/UPI pending).
  final ValueNotifier<bool> pending = ValueNotifier(false);

  final _notices = StreamController<BillingNotice>.broadcast();
  Stream<BillingNotice> get notices => _notices.stream;

  ProductDetails? product;
  bool available = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _buying = false;

  BillingService(this.progress, {this.enabled = true, InAppPurchase? iap})
    : _iapOverride = iap,
      premium = ValueNotifier(progress.premiumCached);

  bool get _active =>
      enabled && defaultTargetPlatform == TargetPlatform.android;

  String get priceLabel => product?.price ?? kRemoveAdsFallbackPrice;

  Future<void> init() async {
    if (!_active) return;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    try {
      available = await _iap.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!available) return;
    await loadProduct();
    await recheck(silent: true);
  }

  void dispose() {
    _sub?.cancel();
    _notices.close();
  }

  Future<void> loadProduct() async {
    if (!_active) return;
    try {
      final r = await _iap.queryProductDetails({kRemoveAdsProductId});
      // A subscription comes back once per offer; prefer the plain base plan.
      final offers = r.productDetails
          .whereType<GooglePlayProductDetails>()
          .toList();
      if (offers.isEmpty) {
        product = r.productDetails.isEmpty ? null : r.productDetails.first;
        return;
      }
      product = offers.firstWhere((p) {
        final i = p.subscriptionIndex;
        final details = p.productDetails.subscriptionOfferDetails;
        return i != null && details != null && details[i].offerId == null;
      }, orElse: () => offers.first);
    } catch (_) {
      product = null;
    }
  }

  Future<void> buy() async {
    if (!_active) return _notify(BillingNotice.storeUnavailable);
    if (!available) {
      available = await _safeAvailable();
      if (!available) return _notify(BillingNotice.storeUnavailable);
    }
    if (product == null) await loadProduct();
    final p = product;
    if (p == null) return _notify(BillingNotice.productUnavailable);
    _buying = true;
    try {
      await _iap.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: p,
          offerToken: p is GooglePlayProductDetails ? p.offerToken : null,
        ),
      );
    } on PlatformException catch (_) {
      _buying = false;
      _notify(BillingNotice.failed);
    }
  }

  Future<bool> _safeAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Asks Google Play for active subscriptions and updates ad status.
  /// With [silent] false the player is told what was found.
  Future<void> recheck({bool silent = false}) async {
    if (!_active) {
      if (!silent) _notify(BillingNotice.storeUnavailable);
      return;
    }
    if (!available) available = await _safeAvailable();
    if (!available) {
      if (!silent) _notify(BillingNotice.storeUnavailable);
      return; // offline: keep the last known state
    }
    final addition = _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final QueryPurchaseDetailsResponse response;
    try {
      response = await addition.queryPastPurchases();
    } catch (_) {
      if (!silent) _notify(BillingNotice.storeUnavailable);
      return;
    }
    if (response.error != null) {
      if (!silent) _notify(BillingNotice.storeUnavailable);
      return; // don't drop premium because of a transient error
    }

    var active = false;
    var isPending = false;
    for (final p in response.pastPurchases) {
      if (p.productID != kRemoveAdsProductId) continue;
      final state = p.billingClientPurchase.purchaseState;
      if (state == PurchaseStateWrapper.pending) {
        isPending = true;
        continue;
      }
      if (state != PurchaseStateWrapper.purchased || !_verify(p)) continue;
      active = true;
      if (!p.billingClientPurchase.isAcknowledged) await _complete(p);
    }

    final wasPremium = premium.value;
    pending.value = isPending && !active;
    await _setPremium(active);
    if (silent) {
      if (wasPremium && !active) _notify(BillingNotice.expired);
    } else {
      _notify(active ? BillingNotice.restoredOk : BillingNotice.restoredNone);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != kRemoveAdsProductId) {
        if (p.pendingCompletePurchase) await _complete(p);
        continue;
      }
      switch (p.status) {
        case PurchaseStatus.pending:
          pending.value = true;
          _notify(BillingNotice.pending);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          pending.value = false;
          if (_verify(p)) {
            await _setPremium(true);
            if (p.pendingCompletePurchase) await _complete(p);
            if (p.status == PurchaseStatus.purchased && _buying) {
              _notify(BillingNotice.success);
            }
          } else {
            _notify(BillingNotice.verifyFailed);
          }
        case PurchaseStatus.canceled:
          pending.value = false;
          _notify(BillingNotice.canceled);
        case PurchaseStatus.error:
          pending.value = false;
          // "Already owned" means Play thinks it's active: re-sync instead.
          if (p.error?.message.contains('itemAlreadyOwned') ?? false) {
            await recheck();
          } else {
            _notify(BillingNotice.failed);
          }
      }
      if (p.status != PurchaseStatus.pending) _buying = false;
    }
  }

  /// The purchase must be ours and, when a license key is configured, carry
  /// a valid Google Play signature.
  bool _verify(PurchaseDetails p) {
    if (p.productID != kRemoveAdsProductId) return false;
    if (kPlayLicenseKey.isEmpty) return true;
    if (p is! GooglePlayPurchaseDetails) return false;
    final purchase = p.billingClientPurchase;
    return verifyPlaySignature(
      base64PublicKey: kPlayLicenseKey,
      signedData: purchase.originalJson,
      signature: purchase.signature,
    );
  }

  /// Acknowledges the purchase; Google refunds unacknowledged ones after 3 days.
  Future<void> _complete(PurchaseDetails p) async {
    try {
      await _iap.completePurchase(p);
    } catch (_) {
      // Retried on the next recheck, which sees isAcknowledged == false.
    }
  }

  Future<void> _setPremium(bool v) async {
    premium.value = v;
    await progress.setPremium(v);
  }

  void _notify(BillingNotice n) {
    if (!_notices.isClosed) _notices.add(n);
  }

  /// Play Store page where the player can cancel or change the plan.
  static Uri manageUri() => Uri.parse(
    'https://play.google.com/store/account/subscriptions?sku=$kRemoveAdsProductId&package=$kAndroidPackage',
  );
}
