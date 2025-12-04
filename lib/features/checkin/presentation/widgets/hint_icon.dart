import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';

/// Icon button that shows hint information
class HintIcon extends StatelessWidget {
  final VoidCallback onTap;

  const HintIcon({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: const Icon(
          Icons.help_outline,
          size: 20,
          color: MyColors.fivyColor,
        ),
      ),
    );
  }
}
