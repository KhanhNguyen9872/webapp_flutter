import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String _localeKey = 'locale';
  static const String _themeModeKey = 'themeMode';

  Locale _locale = const Locale('vi');
  ThemeMode _themeMode = ThemeMode.system;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  SettingsProvider() {
    _loadSettings();
  }

  void setLocale(Locale locale) {
    if (!L10n.all.contains(locale)) return;
    _locale = locale;
    _saveSettings();
    notifyListeners();
  }

  void setThemeMode(ThemeMode themeMode) {
    _themeMode = themeMode;
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, _locale.languageCode);
    await prefs.setInt(_themeModeKey, _themeMode.index);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Locale
    final localeCode = prefs.getString(_localeKey) ?? 'vi';
    _locale = Locale(localeCode);

    // Load ThemeMode
    final themeModeIndex =
        prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeModeIndex];

    notifyListeners();
  }
}

class L10n {
  static final all = [
    const Locale('en'),
    const Locale('vi'),
  ];
}
