import 'package:flutter/material.dart';
import 'package:chrono/l10n/app_localizations.dart';
import '../models/goal.model.dart';
import '../db_manager.dart';
import '../services/productivity_service.dart';
import '../colors.dart';
import '../shared/chrono_ui.dart';

class AddGoalScreen extends StatefulWidget {
  final Goal? existingGoal;

  const AddGoalScreen({
    Key? key,
    this.existingGoal,
  }) : super(key: key);

  @override
  _AddGoalScreenState createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _hoursController;
  late TextEditingController _minutesController;
  late TextEditingController _sessionMinutesController;
  int _priority = 2;
  final List<bool> _daysOfWeek = List.filled(7, true);
  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingGoal?.title ?? '');
    _hoursController = TextEditingController(text: widget.existingGoal?.hours.toString() ?? '');
    _minutesController = TextEditingController(text: widget.existingGoal?.minutes.toString() ?? '');
    _sessionMinutesController =
        TextEditingController(text: widget.existingGoal?.sessionMinutes.toString() ?? '');
    _priority = widget.existingGoal?.priority ?? 2;
    if (widget.existingGoal != null) {
      _daysOfWeek.setAll(0, widget.existingGoal!.daysOfWeek);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _sessionMinutesController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textMuted),
      helperText: helperText,
      helperStyle: const TextStyle(color: textHint, fontSize: 12),
      helperMaxLines: 2,
      errorMaxLines: 1,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: MyColors.orangeDivider, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: MyColors.remove),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: MyColors.remove, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          _isEditing
              ? AppLocalizations.of(context).goalEditTitle
              : AppLocalizations.of(context).goalNewTitle,
          style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: _saveGoal,
            child: Text(
              _isEditing
                  ? AppLocalizations.of(context).commonSave
                  : AppLocalizations.of(context).commonCreate,
              style: const TextStyle(
                color: MyColors.orangeDivider,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // ── Basic Info ──
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: textPrimary, fontSize: 16),
              decoration: _inputDecoration(AppLocalizations.of(context).goalTitleLabel, helperText: ' '),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(context).goalTitleRequired;
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 24),

            // ── Time settings ──
            ChronoSettingsGroup(
              title: AppLocalizations.of(context).goalTimeTarget,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _hoursController,
                          style: const TextStyle(color: textPrimary),
                          decoration: _inputDecoration(AppLocalizations.of(context).goalHours, helperText: ' '),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            final hours = int.tryParse(value);
                            if (hours == null || hours < 0) return AppLocalizations.of(context).validatorInvalid;
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _minutesController,
                          style: const TextStyle(color: textPrimary),
                          decoration: _inputDecoration(AppLocalizations.of(context).goalMinutes, helperText: ' '),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final hours = int.tryParse(_hoursController.text);
                            final hasHours = hours != null && hours > 0;

                            if (!hasHours && (value == null || value.isEmpty)) {
                              return AppLocalizations.of(context).validatorRequired;
                            }

                            if (value != null && value.isNotEmpty) {
                              final minutes = int.tryParse(value);
                              if (minutes == null || minutes < 0 || minutes >= 60) return AppLocalizations.of(context).goalMinutesRange;
                            }
                            
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  child: TextFormField(
                    controller: _sessionMinutesController,
                    style: const TextStyle(color: textPrimary),
                    decoration: _inputDecoration(AppLocalizations.of(context).goalSessionDuration, helperText: AppLocalizations.of(context).goalSessionDurationHelper),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context).validatorRequired;
                      final sessionMinutes = int.tryParse(value);
                      if (sessionMinutes == null || sessionMinutes <= 0) return AppLocalizations.of(context).validatorInvalid;
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Days of week ──
            ChronoSettingsGroup(
              title: AppLocalizations.of(context).routineDaysOfWeek,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: _buildDaysOfWeekPicker(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Priority ──
            ChronoSettingsGroup(
              title: AppLocalizations.of(context).goalImportance,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                  child: _buildPrioritySlider(),
                ),
              ],
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saveGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.orangeDivider,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _isEditing
                    ? AppLocalizations.of(context).goalUpdate
                    : AppLocalizations.of(context).goalCreate,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _priorityLabels = {
    1: 'Необязательно',
    2: 'Стандарт',
    3: 'Важно',
    4: 'Ключевая',
  };

  static const _priorityDescriptions = {
    1: 'Пропуск почти не влияет на индекс',
    2: 'Обычная повседневная активность',
    3: 'Важно выполнить для продуктивности',
    4: 'Критически важно, сильно влияет на индекс',
  };

  Widget _buildDaysOfWeekPicker() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final raw = (constraints.maxWidth - 6 * gap) / 7;
        final diameter = raw.clamp(32.0, 44.0);
        final fontSize = (diameter * 0.38).clamp(12.0, 15.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (i) {
            final isSelected = _daysOfWeek[i];
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _daysOfWeek[i] = !isSelected;
                    });
                  },
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: diameter,
                    height: diameter,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? MyColors.orangeDivider.withValues(alpha: 0.15)
                          : cardColor3,
                      border: Border.all(
                        color: isSelected
                            ? MyColors.orangeDivider.withValues(alpha: 0.5)
                            : cardBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      dayLetters[i],
                      style: TextStyle(
                        color: isSelected ? MyColors.orangeDivider : textMuted,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: fontSize,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPrioritySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _priorityColor(_priority),
            inactiveTrackColor: cardBorder,
            thumbColor: _priorityColor(_priority),
            overlayColor: _priorityColor(_priority).withValues(alpha: 0.2),
            valueIndicatorColor: _priorityColor(_priority),
            trackHeight: 4,
          ),
          child: Slider(
            value: _priority.toDouble(),
            min: 1,
            max: 4,
            divisions: 3,
            label: _priorityLabels[_priority],
            onChanged: (value) {
              setState(() {
                _priority = value.round();
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _priorityLabels[_priority] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _priorityColor(_priority),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _priorityDescriptions[_priority] ?? '',
                  style: const TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return textMuted;
      case 2:
        return infoColor;
      case 3:
        return warningColor;
      case 4:
        return MyColors.remove;
      default:
        return infoColor;
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final sessionMinutes = int.parse(_sessionMinutesController.text);

    // Check that total time is greater than 0
    if (hours == 0 && minutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).goalSpecifyTime),
          backgroundColor: MyColors.remove,
        ),
      );
      return;
    }

    // Require at least one scheduled day of week
    if (!_daysOfWeek.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).routineSelectDay),
          backgroundColor: MyColors.remove,
        ),
      );
      return;
    }

    final db = DatabaseHelper.instance;

    try {
      if (_isEditing) {
        final updatedGoal = widget.existingGoal!.copyWith(
          title: _titleController.text.trim(),
          hours: hours,
          minutes: minutes,
          sessionMinutes: sessionMinutes,
          priority: _priority,
          daysOfWeek: List<bool>.from(_daysOfWeek),
        );
        await db.updateGoal(updatedGoal);
      } else {
        final newGoal = Goal(
          title: _titleController.text.trim(),
          hours: hours,
          minutes: minutes,
          sessionMinutes: sessionMinutes,
          timeSpentSeconds: 0,
          isActive: false,
          priority: _priority,
          daysOfWeek: List<bool>.from(_daysOfWeek),
        );
        await db.insertGoal(newGoal);
      }

      await ProductivityService.instance.createOrUpdateDailyRecord();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).goalErrorSaving(e.toString()))),
        );
      }
    }
  }
}
