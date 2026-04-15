import 'package:chrono/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:chrono/instuction_page.dart';
import 'package:chrono/shared/api-key-popup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'colors.dart';
import 'shared/chrono_ui.dart';
import 'package:chrono/screens/paywall_screen.dart';
import 'package:chrono/services/subscription_service.dart';

class MyDrawal extends StatelessWidget {
  const MyDrawal({
    Key? key,
  }) : super(key: key);

  final policyUrl =
      'https://docs.google.com/document/d/16Yi3piQAQLk3SW5itI1iiIntvVG9amvWDSaZpIX43ts/edit?usp=sharing';

  Future<void> _showApiKeyPopup(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return ApiKeyPopup();
      },
    );
  }

  Future<void> _launchUrl() async {
    final url = Uri.parse(policyUrl);

    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
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
                                  isPremium ? 'Chrono Premium' : 'Попробовать Premium',
                                  style: const TextStyle(
                                    color: MyColors.orangeDivider,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  isPremium ? 'Активна' : '3 дня бесплатно',
                                  style: TextStyle(
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
                  'AI & PROMPTS',
                  style: TextStyle(
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
                    label: 'Prompts',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => InstructionsPage()),
                    ),
                  ),
                  ChronoSettingsRow(
                    icon: Icons.smart_toy_outlined,
                    iconColor: successColor,
                    label: 'GPT Settings',
                    onTap: () => _showApiKeyPopup(context),
                  ),
                ],
              ),

              // ── Check-ins ── hidden by user request

              // ── General ──
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'GENERAL',
                  style: TextStyle(
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
                    label: 'Settings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SettingsPage()),
                    ),
                  ),
                  ChronoSettingsRow(
                    icon: Icons.policy_outlined,
                    iconColor: textSecondary,
                    label: 'Privacy Policy',
                    onTap: () => _launchUrl(),
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
