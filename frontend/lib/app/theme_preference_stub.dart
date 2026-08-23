import 'package:flutter/material.dart';

ThemeMode? _themeMode;

Future<ThemeMode?> loadPreferredThemeMode() async {
  return _themeMode;
}

Future<void> savePreferredThemeMode(ThemeMode themeMode) async {
  _themeMode = themeMode;
}
