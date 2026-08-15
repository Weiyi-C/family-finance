import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

final colorThemeProvider =
    StateNotifierProvider<ColorThemeNotifier, String>((ref) {
  return ColorThemeNotifier();
});

class ColorThemeNotifier extends StateNotifier<String> {
  ColorThemeNotifier() : super('sakura') {
    _loadColor();
  }

  Color get primaryColor =>
      AppTheme.presetColors[state] ?? AppTheme.defaultPrimaryColor;

  Future<void> _loadColor() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('colorTheme') ?? 'sakura';
  }

  Future<void> setColor(String key) async {
    state = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorTheme', key);
  }
}
