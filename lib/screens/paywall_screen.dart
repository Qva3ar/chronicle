import 'package:chrono/colors.dart';
import 'package:chrono/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            PaywallContent(
              onFinish: () => Navigator.pop(context),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cardColor2,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: textSecondary, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
