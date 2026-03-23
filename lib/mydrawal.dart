import 'package:chrono/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:chrono/instuction_page.dart';
import 'package:chrono/shared/api-key-popup.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/features/checkin/presentation/widgets/checkin_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'colors.dart';
import 'shared/chrono_ui.dart';
import 'package:chrono/screens/settings/insights_settings_screen.dart';
import 'package:chrono/features/checkin/presentation/screens/checkin_time_settings_screen.dart';

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
                    icon: Icons.auto_awesome,
                    iconColor: MyColors.orangeDivider,
                    label: 'AI Insights Settings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InsightsSettingsScreen()),
                    ),
                  ),
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

              const SizedBox(height: 20),

              // ── Check-ins ──
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'CHECK-INS',
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
                    icon: Icons.access_time,
                    iconColor: MyColors.contactDivider,
                    label: 'Check-in Time Settings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckinTimeSettingsScreen()),
                    ),
                  ),
                  ChronoSettingsRow(
                    icon: Icons.wb_sunny_outlined,
                    iconColor: MyColors.orangeDivider,
                    label: 'Morning Check-in',
                    onTap: () {
                      Navigator.pop(context);
                      CheckinDialog.show(context, CheckinType.morning);
                    },
                  ),
                  ChronoSettingsRow(
                    icon: Icons.nightlight_outlined,
                    iconColor: MyColors.contactDivider,
                    label: 'Evening Check-in',
                    onTap: () {
                      Navigator.pop(context);
                      CheckinDialog.show(context, CheckinType.evening);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

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
