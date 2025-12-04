import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/features/checkin/data/repositories/checkin_time_settings_repository.dart';
import 'package:chrono/services/notification_service.dart';

/// Screen for configuring checkin notification times
class CheckinTimeSettingsScreen extends StatefulWidget {
  const CheckinTimeSettingsScreen({Key? key}) : super(key: key);

  @override
  State<CheckinTimeSettingsScreen> createState() =>
      _CheckinTimeSettingsScreenState();
}

class _CheckinTimeSettingsScreenState extends State<CheckinTimeSettingsScreen> {
  final _repository = CheckinTimeSettingsRepository();
  bool _loading = true;
  TimeOfDay? _morningTime;
  TimeOfDay? _eveningTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final morningTime = await _repository.loadMorningTime();
    final eveningTime = await _repository.loadEveningTime();

    if (mounted) {
      setState(() {
        _morningTime = morningTime;
        _eveningTime = eveningTime;
        _loading = false;
      });
    }
  }

  Future<void> _pickTime({required bool isMorning}) async {
    final initialTime = isMorning ? _morningTime : _eveningTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isMorning) {
          _morningTime = picked;
        } else {
          _eveningTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_morningTime == null || _eveningTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, установите оба времени'),
          backgroundColor: MyColors.remove,
        ),
      );
      return;
    }

    await _repository.saveMorningTime(_morningTime!);
    await _repository.saveEveningTime(_eveningTime!);

    // Reschedule notifications with new times
    await NotificationService().rescheduleCheckinNotifications();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Настройки сохранены'),
          backgroundColor: MyColors.contactDivider,
        ),
      );
      Navigator.pop(context);
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Не установлено';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(color: MyColors.orangeDivider),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: MyColors.primaryColor,
        title: const Text(
          'Настройка времени чекинов',
          style: TextStyle(color: white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MyColors.primaryColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MyColors.orangeDivider.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: MyColors.orangeDivider,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Приложение будет отправлять уведомления в установленное время для напоминания о чекине',
                      style: TextStyle(
                        color: white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Morning time setting
            Card(
              color: MyColors.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: MyColors.orangeDivider,
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: const Icon(
                  Icons.wb_sunny_outlined,
                  color: MyColors.orangeDivider,
                  size: 32,
                ),
                title: const Text(
                  'Утренний чекин',
                  style: TextStyle(
                    color: white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _formatTime(_morningTime),
                  style: const TextStyle(
                    color: MyColors.orangeDivider,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: MyColors.orangeDivider,
                  ),
                  onPressed: () => _pickTime(isMorning: true),
                ),
                onTap: () => _pickTime(isMorning: true),
              ),
            ),

            const SizedBox(height: 16),

            // Evening time setting
            Card(
              color: MyColors.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: MyColors.contactDivider,
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: const Icon(
                  Icons.nightlight_outlined,
                  color: MyColors.contactDivider,
                  size: 32,
                ),
                title: const Text(
                  'Вечерний чекин',
                  style: TextStyle(
                    color: white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _formatTime(_eveningTime),
                  style: const TextStyle(
                    color: MyColors.contactDivider,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: MyColors.contactDivider,
                  ),
                  onPressed: () => _pickTime(isMorning: false),
                ),
                onTap: () => _pickTime(isMorning: false),
              ),
            ),

            const Spacer(),

            // Save button
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.orangeDivider,
                foregroundColor: MyColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Сохранить',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
