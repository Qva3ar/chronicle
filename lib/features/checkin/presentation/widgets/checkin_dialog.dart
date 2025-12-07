import 'package:chrono/colors.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:chrono/features/checkin/presentation/providers/edit_mode_provider.dart';
import 'package:chrono/features/checkin/presentation/widgets/hidden_metrics_section.dart';
import 'package:chrono/features/checkin/presentation/widgets/metric_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Modal dialog for checkin - shown as bottom sheet over current screen
class CheckinDialog {
  /// Show checkin dialog as a modal bottom sheet
  ///
  /// [checkinType] - type of checkin (morning/evening)
  /// [existingRecord] - optional existing record to view/edit
  static Future<void> show(
    BuildContext context,
    CheckinType checkinType, {
    Map<String, dynamic>? existingRecord,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CheckinProvider(
              checkinType: checkinType,
              existingRecord: existingRecord,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => EditModeProvider(),
          ),
        ],
        child: _CheckinDialogContent(checkinType: checkinType),
      ),
    );
  }
}

class _CheckinDialogContent extends StatelessWidget {
  final CheckinType checkinType;

  const _CheckinDialogContent({
    required this.checkinType,
  });

  @override
  Widget build(BuildContext context) {
    final checkinProvider = context.watch<CheckinProvider>();
    final editModeProvider = context.watch<EditModeProvider>();
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.9, // 90% of screen height
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar for dragging
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MyColors.forthyColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: MyColors.trecondaryColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Close button
                IconButton(
                  icon: const Icon(Icons.close, color: white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),

                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        checkinType.displayName,
                        style: const TextStyle(
                          color: white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Read-only indicator
                      if (checkinProvider.isReadOnly)
                        const Text(
                          'Только просмотр',
                          style: TextStyle(
                            color: MyColors.forthyColor,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),

                // Edit button (only if not read-only)
                if (!checkinProvider.isReadOnly)
                  TextButton(
                    onPressed: () {
                      editModeProvider.toggleEditMode();
                    },
                    child: Text(
                      editModeProvider.isEditMode ? 'Готово' : 'Изменить',
                      style: const TextStyle(
                        color: MyColors.orangeDivider,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: checkinProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MyColors.orangeDivider,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Visible metrics
                        ...checkinProvider.visibleMetrics.map(
                          (metric) => MetricCard(
                            metric: metric,
                            isHidden: false,
                          ),
                        ),

                        // Hidden metrics section (only in edit mode)
                        if (editModeProvider.isEditMode)
                          HiddenMetricsSection(
                            hiddenMetrics: checkinProvider.hiddenMetrics,
                          ),

                        const SizedBox(height: 24),

                        // Save button (only when not in edit mode and not read-only)
                        if (!editModeProvider.isEditMode && !checkinProvider.isReadOnly)
                          ElevatedButton(
                            onPressed: checkinProvider.isSaving
                                ? null
                                : () async {
                                    final success = await checkinProvider.saveCheckin();
                                    if (success && context.mounted) {
                                      // Show success message
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Чекин сохранён'),
                                          backgroundColor: MyColors.contactDivider,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );

                                      // Close dialog
                                      Navigator.pop(context);
                                    } else if (!success && context.mounted) {
                                      // Show error message
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Ошибка при сохранении'),
                                          backgroundColor: MyColors.remove,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MyColors.orangeDivider,
                              foregroundColor: MyColors.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: checkinProvider.isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: MyColors.primaryColor,
                                    ),
                                  )
                                : const Text(
                                    'Сохранить',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
