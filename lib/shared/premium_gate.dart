import 'package:flutter/material.dart';
import 'package:chrono/services/subscription_service.dart';
import 'package:chrono/screens/paywall_screen.dart';

/// Returns `true` if the user has an active subscription.
/// If not, opens the paywall and returns `false`.
bool checkPremiumOrShowPaywall(BuildContext context) {
  if (SubscriptionService.instance.hasSubscription.value) return true;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PaywallScreen()),
  );
  return false;
}
