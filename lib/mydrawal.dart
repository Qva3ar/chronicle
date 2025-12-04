import 'package:chrono/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:chrono/instuction_page.dart';
import 'package:chrono/shared/api-key-popup.dart';
import 'package:chrono/screens/routine_manager_screen.dart';
import 'package:chrono/screens/goal_manager_screen.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/features/checkin/presentation/widgets/checkin_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'colors.dart';
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
      margin: EdgeInsets.only(top: 55),
      child: Drawer(
        backgroundColor: MyColors.drawalBackground,
        // Add a ListView to the drawer. This ensures the user can scroll
        // through the options in the drawer if there isn't enough vertical
        // space to fit everything.
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: [
            Divider(
              color: MyColors.drawalDivider,
              height: 2,
              thickness: 2,
            ),
            ListTile(
              title: const Text(
                'AI INSIGHTS SETTINGS',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InsightsSettingsScreen()),
                );
              },
            ),
            Divider(
              color: MyColors.drawalDivider,
              height: 2,
              thickness: 2,
            ),
            ListTile(
              title: const Text(
                'CHECKIN TIME SETTINGS',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckinTimeSettingsScreen()),
                );
              },
            ),
            Divider(
              color: MyColors.drawalDivider,
              height: 2,
              thickness: 2,
            ),
            ListTile(
              title: const Text(
                'PROMPTS',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => InstructionsPage()));
              },
            ),
            Divider(
              color: MyColors.drawalDivider,
              height: 2,
              thickness: 2,
            ),
            ListTile(
              title: const Text(
                'GPT SETTINGS',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                _showApiKeyPopup(context);
                // Navigator.push(
                //     context, MaterialPageRoute(builder: (_) => AddRecord()));
              },
            ),
            Divider(
              color: MyColors.drawalDivider,
              height: 2,
              thickness: 2,
            ),
            ListTile(
              title: const Text(
                'SETTINGS',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()));
              },
            ),

            Divider(
              color: MyColors.drawalDivider,
              height: 2,
              thickness: 2,
            ),
            ListTile(
              leading: const Icon(
                Icons.wb_sunny_outlined,
                color: MyColors.orangeDivider,
              ),
              title: const Text(
                'MORNING CHECKIN',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer first
                CheckinDialog.show(context, CheckinType.morning);
              },
            ),
            Divider(
              color: MyColors.drawalDivider,
              height: 2,
              thickness: 2,
            ),
            ListTile(
              leading: const Icon(
                Icons.nightlight_outlined,
                color: MyColors.contactDivider,
              ),
              title: const Text(
                'EVENING CHECKIN',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer first
                CheckinDialog.show(context, CheckinType.evening);
              },
            ),
            Divider(
              color: MyColors.drawalDivider,
              height: 2,
              thickness: 2,
            ),
            ListTile(
              title: const Text(
                'PRIVACY POLICY',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                _launchUrl();
                // Navigator.push(
                //     context, MaterialPageRoute(builder: (_) => AddRecord()));
              },
            ),
            Divider(
              color: MyColors.drawalDivider,
              height: 2,
              thickness: 2,
            ),
            // ListTile(
            //   title: const Text(
            //     'Contact List',
            //     style: TextStyle(color: Colors.white),
            //   ),
            //   onTap: () {
            //     Navigator.push(context, MaterialPageRoute(builder: (_) => ContactList()));
            //   },
            // ),
            // Divider(
            //   color: MyColors.drawalDivider,
            //   height: 2,
            //   thickness: 2,
            // ),
          ],
        ),
      ),
    );
  }
}
