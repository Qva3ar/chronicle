import 'dart:convert';
import 'dart:developer';
import 'package:chrono/features/checkin/data/models/checkin_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository for managing checkin configuration (hidden metrics)
/// Stores configuration in SharedPreferences
class CheckinConfigRepository {
  static const String _configKey = 'checkin_config';

  /// Load checkin configuration from SharedPreferences
  Future<CheckinConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? configJson = prefs.getString(_configKey);

      if (configJson == null) {
        // Return default empty config
        return const CheckinConfig();
      }

      final Map<String, dynamic> json = jsonDecode(configJson);
      return CheckinConfig.fromJson(json);
    } catch (e) {
      // If there's an error loading, return default config
      log('Error loading checkin config: $e');
      return const CheckinConfig();
    }
  }

  /// Save checkin configuration to SharedPreferences
  Future<void> saveConfig(CheckinConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String configJson = jsonEncode(config.toJson());
      await prefs.setString(_configKey, configJson);
    } catch (e) {
      log('Error saving checkin config: $e');
      rethrow;
    }
  }

  /// Clear all configuration (reset to default)
  Future<void> clearConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_configKey);
    } catch (e) {
      log('Error clearing checkin config: $e');
      rethrow;
    }
  }
}
