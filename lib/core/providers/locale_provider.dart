import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide locale. `null` means follow the device/system language.
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  static const _key = 'app_locale';

  /// Languages the app ships with, in display order.
  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && mounted) {
      state = Locale(code);
    }
  }

  /// Pass `null` to follow the system language.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (ref) => LocaleNotifier(),
);
