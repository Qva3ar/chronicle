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
    try {
      final profile = await Adapty().getProfile();
      final isActive = profile.accessLevels['premium']?.isActive ?? false;
      _applySubscriptionFlag(isActive);
    } catch (e) {
      log('[Subscription] Failed to check status: $e');
      _applySubscriptionFlag(false);
    }
  }

  void _listenProfileUpdates() {
    Adapty().didUpdateProfileStream.listen((profile) {
      final isActive = profile.accessLevels['premium']?.isActive ?? false;
      _applySubscriptionFlag(isActive);
    });
  }

  Future<bool> buyProduct(AdaptyPaywallProduct product) async {
    try {
      final result = await Adapty().makePurchase(product: product);
      switch (result) {
        case AdaptyPurchaseResultSuccess(profile: final profile):
          log('[Subscription] Purchase successful');
          final isActive = profile.accessLevels['premium']?.isActive ?? false;
          _applySubscriptionFlag(isActive);
          if (!isActive) {
            // Profile may not have updated yet — re-check
            await _checkSubscriptionStatus();
          }
          return true;
        case AdaptyPurchaseResultPending():
          log('[Subscription] Purchase pending');
        case AdaptyPurchaseResultUserCancelled():
          log('[Subscription] Purchase cancelled by user');
      }
      return false;
    } catch (e) {
      log('[Subscription] Purchase error: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    try {
      await Adapty().restorePurchases();
      await _checkSubscriptionStatus();
    } catch (e) {
      log('[Subscription] Restore error: $e');
    }
  }
}
