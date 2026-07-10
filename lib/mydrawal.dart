import 'package:chrono/settings_page.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:chrono/instuction_page.dart';
import 'package:chrono/shared/api-key-popup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'colors.dart';
import 'shared/chrono_ui.dart';
import 'package:chrono/screens/paywall_screen.dart';
import 'package:chrono/services/subscription_service.dart';
import 'package:chrono/onboarding/onboarding_screen.dart';

class MyDrawal extends StatelessWidget {
  const MyDrawal({
    Key? key,
  }) : super(key: key);

  final policyUrl =
      'https://docs.google.com/document/d/16Yi3piQAQLk3SW5itI1iiIntvVG9amvWDSaZpIX43ts/edit?usp=sharing';

  static const _eulaUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

  Future<void> _showApiKeyPopup(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return ApiKeyPopup();
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 55),
      child: Drawer(
        backgroundColor: MyColors.drawalBackground,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            children: [
              // ── Subscription ──
              ValueListenableBuilder<bool>(
                valueListenable: SubscriptionService.instance.hasSubscription,
                builder: (context, isPremium, _) {
                  return GestureDetector(
                    onTap: isPremium
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PaywallScreen()),
                            ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPremium
                              ? [Color(0xFF2A2210), Color(0xFF1E1A0E)]
                              : [Color(0xFF2A2210), Color(0xFF1A1A1A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: MyColors.orangeDivider.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: MyColors.orangeDivider,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPremium
                                      ? AppLocalizations.of(context).drawerPremium
                                      : AppLocalizations.of(context).drawerPremiumTry,
                                  style: const TextStyle(
                                    color: MyColors.orangeDivider,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  isPremium
                                      ? AppLocalizations.of(context).drawerPremiumActive
                                      : AppLocalizations.of(context).drawerPremiumTrial,
                                  style: const TextStyle(
                                    color: textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isPremium)
                            const Icon(Icons.chevron_right, color: MyColors.orangeDivider, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── AI & Prompts ──
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                child: Text(
                  AppLocalizations.of(context).drawerSectionAiPrompts,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              ChronoSettingsGroup(
                children: [
                  ChronoSettingsRow(
                    icon: Icons.description_outlined,
                    iconColor: infoColor,
                    label: AppLocalizations.of(context).drawerPrompts,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => InstructionsPage()),
                    ),
                  ),
                  ChronoSettingsRow(
                    icon: Icons.smart_toy_outlined,
                    iconColor: successColor,
                    label: AppLocalizations.of(context).drawerGptSettings,
                    onTap: () => _showApiKeyPopup(context),
                  ),
                ],
              ),

              // ── Check-ins ── hidden by user request

              // ── General ──
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  AppLocalizations.of(context).drawerSectionGeneral,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              ChronoSettingsGroup(
                children: [
                  ChronoSettingsRow(
                    icon: Icons.settings_outlined,
                    iconColor: textSecondary,
                    label: AppLocalizations.of(context).commonSettings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SettingsPage()),
                    ),
                  ),
                  ChronoSettingsRow(
                    icon: Icons.slideshow_outlined,
                    iconColor: infoColor,
                    label: AppLocalizations.of(context).drawerShowIntro,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    ),
                  ),
                  ChronoSettingsRow(
                    icon: Icons.policy_outlined,
                    iconColor: textSecondary,
                    label: AppLocalizations.of(context).drawerPrivacyPolicy,
                    onTap: () => _launchUrl(policyUrl),
                  ),
                  ChronoSettingsRow(
                    icon: Icons.gavel_outlined,
                    iconColor: textSecondary,
                    label: AppLocalizations.of(context).drawerTermsOfUse,
                    onTap: () => _launchUrl(_eulaUrl),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
