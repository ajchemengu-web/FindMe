import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'findme:theme_mode';

/// New -- the app previously had no theme preference at all, just an always-dark
/// MaterialApp.theme. Defaults to ThemeMode.system (follows the OS/browser preference)
/// rather than defaulting to dark, per feedback that dark shouldn't be forced on
/// everyone.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      state = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
