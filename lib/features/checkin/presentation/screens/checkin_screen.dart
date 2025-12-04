import 'package:chrono/colors.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:chrono/features/checkin/presentation/providers/edit_mode_provider.dart';
import 'package:chrono/features/checkin/presentation/widgets/hidden_metrics_section.dart';
import 'package:chrono/features/checkin/presentation/widgets/metric_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Main checkin screen for morning or evening checkin
class CheckinScreen extends StatelessWidget {
  final CheckinType checkinType;

  const CheckinScreen({
    Key? key,
    required this.checkinType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CheckinProvider(checkinType: checkinType),
        ),
        ChangeNotifierProvider(
          create: (_) => EditModeProvider(),
        ),
      ],
      child: _CheckinScreenContent(checkinType: checkinType),
    );
  }
}

class _CheckinScreenContent extends StatelessWidget {
  final CheckinType checkinType;

  const _CheckinScreenContent({
    required this.checkinType,
  });

  @override
  Widget build(BuildContext context) {
    final checkinProvider = context.watch<CheckinProvider>();
    final editModeProvider = context.watch<EditModeProvider>();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: MyColors.primaryColor,
        title: Text(
          checkinType.displayName,
          style: const TextStyle(
            color: white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Edit button
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
      body: checkinProvider.isLoading
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

                  // Save button (only when not in edit mode)
                  if (!editModeProvider.isEditMode)
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

                                // Navigate back
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
    );
  }
}
