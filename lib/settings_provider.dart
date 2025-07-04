import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';

import 'config.dart';

class SettingsProvider with ChangeNotifier {
  static const String _localeKey = 'locale';
  static const String _themeModeKey = 'themeMode';

  Locale _locale = defaultLocale;
  ThemeMode _themeMode = defaultThemeMode;
  bool _settingsChanged = false;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get settingsChanged => _settingsChanged;

  void clearSettingsChangedFlag() {
    _settingsChanged = false;
  }

  SettingsProvider() {
    _loadSettings();
  }

  void setLocale(Locale locale, {bool syncToWebView = true}) {
    if (!L10n.all.contains(locale) || _locale == locale) return;
    _locale = locale;
    _settingsChanged = true;
    _saveSettings();
    notifyListeners();
    if (syncToWebView) {
      _syncLangWithWebView(locale);
    }
  }

  void setThemeMode(ThemeMode themeMode) {
    if (_themeMode == themeMode) return;
    _themeMode = themeMode;
    _settingsChanged = true;
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
    final localeCode =
        prefs.getString(_localeKey) ?? defaultLocale.languageCode;
    _locale = Locale(localeCode);

    // Load ThemeMode
    final themeModeIndex =
        prefs.getInt(_themeModeKey) ?? defaultThemeMode.index;
    var loadedThemeMode = ThemeMode.values[themeModeIndex];

    // If a user had 'system' saved from a previous version, default them to 'light'.
    if (loadedThemeMode == ThemeMode.system) {
      loadedThemeMode = defaultThemeMode;
    }
    _themeMode = loadedThemeMode;

    notifyListeners();
    // Sync language with webview on initial app load
    _syncLangWithWebView(_locale);
  }

  Future<void> _syncLangWithWebView(Locale locale) async {
    try {
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(url: WebUri(baseUrl));
      final cookieString =
          cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');

      final dio = Dio();
      await dio.get(
        '$baseUrl/lang/${locale.languageCode}',
        options: Options(headers: {
          HttpHeaders.cookieHeader: cookieString,
        }),
      );
    } catch (e) {
      // Silently fail to not disrupt user experience
      debugPrint('Failed to sync language with webview: $e');
    }
  }
}

class L10n {
  static final all = [
    const Locale('en'),
    const Locale('vi'),
  ];
}
