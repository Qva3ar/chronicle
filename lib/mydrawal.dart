import 'package:Chrono/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:Chrono/instuction_page.dart';
import 'package:Chrono/shared/api-key-popup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'colors.dart';

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
