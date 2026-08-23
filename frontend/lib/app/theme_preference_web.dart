import 'dart:js_interop';

import 'package:flutter/material.dart';

const String _themeModeKey = 'cobro.themeMode';

@JS('window.localStorage')
external _LocalStorage get _localStorage;

extension type _LocalStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
}

Future<ThemeMode?> loadPreferredThemeMode() async {
  try {
    return switch (_localStorage.getItem(_themeModeKey.toJS)?.toDart) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

Future<void> savePreferredThemeMode(ThemeMode themeMode) async {
  try {
    final String value = switch (themeMode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    _localStorage.setItem(_themeModeKey.toJS, value.toJS);
  } catch (_) {
    return;
  }
}
