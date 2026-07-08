import 'dart:developer';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';

class SubscriptionService {
  SubscriptionService._privateConstructor();

  static final SubscriptionService instance = SubscriptionService._privateConstructor();

  /// `true` — всегда премиум (для разработки). Перед публикацией — `false`.
  static const bool _forcePremiumOverride = true;

  final ValueNotifier<bool> hasSubscription = ValueNotifier(_forcePremiumOverride);

  void _applySubscriptionFlag(bool fromBackend) {
    if (_forcePremiumOverride) {
      hasSubscription.value = true;
      log('[Subscription] force premium override active');
    } else {
      hasSubscription.value = fromBackend;
      log('[Subscription] hasSubscription = $fromBackend');
    }
  }

  Future<void> initialize() async {
    await _activateAdapty();
    await _checkSubscriptionStatus();
    _listenProfileUpdates();
  }

  Future<void> _activateAdapty() async {
    try {
      Adapty().activate(
        configuration: AdaptyConfiguration(
          // TODO: заменить на реальный Adapty API key из дашборда
          apiKey: 'public_live_lPMxt6oX.Of6FWs4YuvUvDYrVPsVc',
        ),
      );
      await Adapty().setLogLevel(AdaptyLogLevel.verbose);
    } on AdaptyError catch (e) {
      log('[Subscription] Adapty activation error: $e');
    }
  }

  Future<List<AdaptyPaywallProduct>?> loadProducts() async {
    try {
      // TODO: заменить на реальный placement ID из Adapty дашборда
      final paywall = await Adapty().getPaywall(placementId: 'chrono_premium_placement');
      final products = await Adapty().getPaywallProducts(paywall: paywall);
      log('[Subscription] Loaded ${products.length} products: ${products.map((p) => p.vendorProductId).join(', ')}');
      return products;
    } catch (e) {
      log('[Subscription] Failed to load products: $e');
      return null;
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    await _refreshPremiumStatus();
  }

  /// Re-fetches the profile and returns the *real* premium entitlement.
  ///
  /// Unlike [hasSubscription] (which honours the dev [_forcePremiumOverride]),
  /// this returns the actual backend state so purchase/restore flows can make
  /// a correct "grant & close paywall" decision.
  Future<bool> _refreshPremiumStatus() async {
    try {
      final profile = await Adapty().getProfile();
      final isActive = profile.accessLevels['premium']?.isActive ?? false;
      _applySubscriptionFlag(isActive);
      return isActive;
    } catch (e) {
      log('[Subscription] Failed to refresh status: $e');
      _applySubscriptionFlag(false);
      return false;
    }
  }

  void _listenProfileUpdates() {
    Adapty().didUpdateProfileStream.listen((profile) {
      final isActive = profile.accessLevels['premium']?.isActive ?? false;
      _applySubscriptionFlag(isActive);
    });
  }

  /// Attempts to purchase [product] and returns `true` when the user ends up
  /// entitled to premium (so the paywall can be dismissed).
  ///
  /// The decision is based on the *actual* entitlement, not only on the
  /// [AdaptyPurchaseResultSuccess] enum. This matters for one-time / lifetime
  /// products where the store may complete the payment while `makePurchase`
  /// still throws (e.g. `itemAlreadyOwned`, or a receipt-validation/network
  /// timeout after the payment sheet closed). Previously those cases returned
  /// `false` and trapped a paying user on the paywall.
  Future<bool> buyProduct(AdaptyPaywallProduct product) async {
    try {
      final result = await Adapty().makePurchase(product: product);
      switch (result) {
        case AdaptyPurchaseResultSuccess(profile: final profile):
          log('[Subscription] Purchase successful');
          final isActive = profile.accessLevels['premium']?.isActive ?? false;
          if (isActive) {
            _applySubscriptionFlag(true);
            return true;
          }
          // Profile may not have propagated yet — verify from backend.
          return await _refreshPremiumStatus();
        case AdaptyPurchaseResultPending():
          log('[Subscription] Purchase pending');
          return false;
        case AdaptyPurchaseResultUserCancelled():
          log('[Subscription] Purchase cancelled by user');
          return false;
      }
    } on AdaptyError catch (e) {
      log('[Subscription] Purchase error: code=${e.code} $e');
      // User explicitly cancelled — keep the paywall open.
      if (e.code == AdaptyErrorCode.paymentCancelled) {
        return false;
      }
      // Any other error (e.g. itemAlreadyOwned, billing/validation timeout
      // after a completed payment) may still mean the transaction went
      // through. Verify the real entitlement before giving up.
      return await _refreshPremiumStatus();
    } catch (e) {
      log('[Subscription] Purchase error: $e');
      return await _refreshPremiumStatus();
    }
  }

  Future<void> restorePurchases() async {
    try {
      await Adapty().restorePurchases();
      await _refreshPremiumStatus();
    } catch (e) {
      log('[Subscription] Restore error: $e');
    }
  }
}
