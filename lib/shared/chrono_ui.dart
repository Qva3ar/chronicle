/// Chrono Design System — reusable UI components
///
/// Principles extracted from [ReminderTimelineWidget]:
///   • Cards with subtle borders and rounded corners
///   • Section headers with icon + label + badge
///   • Badges for counts and statuses
///   • Colour-coded left indicators for type/priority
///   • Consistent spacing (12–20 px horizontal, 8–14 px vertical)
///   • Montserrat font, letterSpacing 0.3–0.5 for small labels

import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ChronoCard — the universal card wrapper
// ═══════════════════════════════════════════════════════════════════════════

class ChronoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final double borderWidth;

  /// Optional left-side colour indicator (4 px strip).
  final Color? leftIndicator;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChronoCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 12,
    this.borderWidth = 1,
    this.leftIndicator,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? cardColor2,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? cardBorder.withValues(alpha: 0.4),
          width: borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Row(
          children: [
            if (leftIndicator != null)
              Container(
                width: 4,
                constraints: const BoxConstraints(minHeight: 48),
                color: leftIndicator,
              ),
            Expanded(
              child: Padding(
                padding:
                    padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      content = GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ChronoSectionHeader
// ═══════════════════════════════════════════════════════════════════════════

class ChronoSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int? count;
  final Color? countColor;
  final Widget? trailing;

  const ChronoSectionHeader({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = MyColors.orangeDivider,
    this.count,
    this.countColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textSecondary.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            ChronoBadge(
              label: count.toString(),
              color: countColor ?? iconColor,
            ),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ChronoBadge
// ═══════════════════════════════════════════════════════════════════════════

class ChronoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final IconData? icon;

  const ChronoBadge({
    super.key,
    required this.label,
    this.color = MyColors.orangeDivider,
    this.fontSize = 10,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color.withValues(alpha: 0.9)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ChronoSheetHeader — unified header for bottom-sheet screens
// ═══════════════════════════════════════════════════════════════════════════

class ChronoSheetHeader extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final int? itemCount;
  final List<Widget>? actions;

  const ChronoSheetHeader({
    super.key,
    required this.title,
    this.titleIcon,
    this.itemCount,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 2),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: MyColors.forthyColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              if (titleIcon != null) ...[
                Icon(titleIcon, size: 20, color: MyColors.orangeDivider),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              if (itemCount != null && itemCount! > 0) ...[
                const SizedBox(width: 10),
                ChronoBadge(
                  label: '$itemCount',
                  color: MyColors.fivyColor,
                ),
              ],
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ChronoEmptyState
// ═══════════════════════════════════════════════════════════════════════════

class ChronoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const ChronoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cardColor2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cardBorder.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, size: 40, color: textMuted),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              if (buttonLabel != null && onButton != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onButton,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(buttonLabel!),
                  style: FilledButton.styleFrom(
                    backgroundColor: MyColors.secondaryColor,
                    foregroundColor: textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: cardBorder.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ChronoSettingsGroup — card wrapper for grouped settings rows
// ═══════════════════════════════════════════════════════════════════════════

class ChronoSettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const ChronoSettingsGroup({
    super.key,
    this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                color: textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: cardColor2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cardBorder.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    color: cardBorder.withValues(alpha: 0.2),
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ChronoSettingsRow — individual action row inside a ChronoSettingsGroup
// ═══════════════════════════════════════════════════════════════════════════

class ChronoSettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const ChronoSettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = textSecondary,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: textMuted),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ChronoDateSeparator — styled date header for grouped lists
// ═══════════════════════════════════════════════════════════════════════════

class ChronoDateSeparator extends StatelessWidget {
  final String dateLabel;
  final bool isToday;

  const ChronoDateSeparator({
    super.key,
    required this.dateLabel,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isToday ? accentGlow : cardColor2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isToday
                    ? MyColors.orangeDivider.withValues(alpha: 0.3)
                    : cardBorder.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              dateLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isToday ? MyColors.orangeDivider : textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: cardBorder.withValues(alpha: 0.2),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
