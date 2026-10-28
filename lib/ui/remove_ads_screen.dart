import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/billing.dart';
import '../services/services.dart';
import '../services/sfx.dart';
import 'settings_dialog.dart';
import 'theme.dart';
import 'widgets.dart';

/// Monthly Remove Ads subscription (₹299 / month via Google Play).
class RemoveAdsScreen extends StatefulWidget {
  final Services services;
  const RemoveAdsScreen({super.key, required this.services});

  @override
  State<RemoveAdsScreen> createState() => _RemoveAdsScreenState();
}

class _RemoveAdsScreenState extends State<RemoveAdsScreen> {
  StreamSubscription<BillingNotice>? _sub;
  bool _busy = false;

  Services get s => widget.services;
  BillingService get billing => s.billing;

  @override
  void initState() {
    super.initState();
    _sub = billing.notices.listen(_onNotice);
    billing.premium.addListener(_refresh);
    billing.pending.addListener(_refresh);
    // Fetch the localized price if it isn't loaded yet.
    if (billing.product == null) {
      billing.loadProduct().whenComplete(_refresh);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    billing.premium.removeListener(_refresh);
    billing.pending.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onNotice(BillingNotice n) {
    if (!mounted) return;
    final key = switch (n) {
      BillingNotice.success => 'ra_success',
      BillingNotice.pending => 'ra_pending',
      BillingNotice.canceled => 'ra_canceled',
      BillingNotice.failed => 'ra_failed',
      BillingNotice.verifyFailed => 'ra_verify_failed',
      BillingNotice.restoredOk => 'ra_restore_ok',
      BillingNotice.restoredNone => 'ra_restore_none',
      BillingNotice.expired => 'ra_expired',
      BillingNotice.storeUnavailable => 'ra_store_unavailable',
      BillingNotice.productUnavailable => 'ra_product_unavailable',
    };
    if (n == BillingNotice.success || n == BillingNotice.restoredOk) {
      s.sfx.play(Sound.coin);
    }
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr(key))));
  }

  Future<void> _subscribe() async {
    s.sfx.play(Sound.button);
    setState(() => _busy = true);
    // The Play purchase sheet leaves the app; don't greet the player with
    // an app-open ad when they come back.
    s.ads.skipNextAppOpen();
    await billing.buy();
    // The result arrives via notices; stop the spinner if nothing came.
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted && _busy) setState(() => _busy = false);
    });
  }

  Future<void> _restore() async {
    s.sfx.play(Sound.button);
    setState(() => _busy = true);
    await billing.recheck();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = s.progress;
    final premium = billing.premium.value;
    final price = billing.priceLabel;
    return Scaffold(
      body: GameBackground(
        animate: p.backgroundFx,
        theme: p.theme,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: Row(
                  children: [
                    RoundButton(
                      icon: Icons.arrow_back_rounded,
                      size: 44,
                      semanticLabel: tr('back'),
                      onTap: () {
                        s.sfx.play(Sound.button);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: FittedBox(
                        child: OutlinedTitle(tr('remove_ads'), size: 28),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    const _Hero(),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        tr('ra_headline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _benefit(Icons.view_day_rounded, tr('ra_benefit_banner')),
                    _benefit(
                      Icons.fullscreen_exit_rounded,
                      tr('ra_benefit_interstitial'),
                    ),
                    _benefit(
                      Icons.rocket_launch_rounded,
                      tr('ra_benefit_appopen'),
                    ),
                    const SizedBox(height: 18),
                    if (premium) _activeCard() else _planCard(price),
                    const SizedBox(height: 16),
                    if (!premium && billing.pending.value)
                      _note(
                        Icons.hourglass_top_rounded,
                        tr('ra_pending'),
                        AppColors.gold,
                      ),
                    if (!premium) ...[
                      _subscribeButton(price),
                      const SizedBox(height: 12),
                      Text(
                        tr('ra_terms', {'price': price}),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _busy ? null : _restore,
                          icon: const Icon(
                            Icons.restore_rounded,
                            color: AppColors.boardLine,
                          ),
                          label: Text(
                            tr('ra_restore'),
                            style: const TextStyle(
                              color: AppColors.boardLine,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => openExternal(
                            context,
                            s,
                            BillingService.manageUri(),
                          ),
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: AppColors.boardLine,
                          ),
                          label: Text(
                            tr('ra_manage'),
                            style: const TextStyle(
                              color: AppColors.boardLine,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x332FB58A),
          ),
          child: Icon(icon, color: const Color(0xFF6CF0B8), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(Icons.check_rounded, color: Color(0xFF6CF0B8)),
      ],
    ),
  );

  Widget _planCard(String price) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5B2A9E), Color(0xFF2A1A6E)],
      ),
      border: Border.all(color: AppColors.gold, width: 2),
    ),
    child: Column(
      children: [
        Text(
          tr('ra_plan').toUpperCase(),
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 13,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              tr('ra_per_month'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tr('ra_duration'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    ),
  );

  Widget _activeCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: const Color(0xFF2FB58A).withValues(alpha: 0.25),
      border: Border.all(color: const Color(0xFF6CF0B8), width: 2),
    ),
    child: Column(
      children: [
        const Icon(Icons.verified_rounded, color: Color(0xFF6CF0B8), size: 44),
        const SizedBox(height: 8),
        Text(
          tr('ra_active'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('ra_active_detail'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _subscribeButton(String price) => GestureDetector(
    onTap: _busy ? null : _subscribe,
    child: Opacity(
      opacity: _busy ? 0.7 : 1,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF8DB5), AppColors.accent, AppColors.accentDark],
          ),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              offset: Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: _busy
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                tr('ra_subscribe', {'price': '$price ${tr('ra_per_month')}'}),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    ),
  );

  Widget _note(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

/// Crossed-out "AD" badge over a soft glow.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 130,
        height: 130,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const ShapeDecoration(
                shape: HexBorder(),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFD45E), Color(0xFFF08A00)],
                ),
                shadows: [BoxShadow(color: Color(0x88FFC52E), blurRadius: 30)],
              ),
            ),
            const Text(
              'AD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
            Transform.rotate(
              angle: -0.75,
              child: Container(
                width: 110,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5243B),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
