import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current [Locale] and persists the user's choice.
///
/// A `null` [locale] means "follow the system locale" — [MaterialApp] then
/// resolves the best match from [supportedLocales].
class LocaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_locale';

  /// Locales the app ships translations for.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ru'),
  ];

  Locale? _locale;
  Locale? get locale => _locale;

  /// Loads the persisted locale (if any) before the first frame.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    }
    notifyListeners();
  }

  /// Sets the locale. Pass `null` to fall back to the system locale.
  Future<void> setLocale(Locale? locale) async {
    if (locale != null &&
        !supportedLocales.any((l) => l.languageCode == locale.languageCode)) {
      return;
    }
    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}
