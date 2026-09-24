import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's language: either "follow the system" (overrideLocale
/// is null, Flutter picks based on the phone's language) or a manually
/// chosen language that persists across app restarts.
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'app_locale_override';

  Locale? _overrideLocale;
  Locale? get overrideLocale => _overrideLocale;

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      _overrideLocale = Locale(saved);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? locale) async {
    _overrideLocale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}

/// A single shared instance — both apps' main.dart and language-switcher
/// UI read/write through this same controller.
final localeController = LocaleController();
