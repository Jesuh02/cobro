import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/cobro_app.dart';
import 'app/theme_preference.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ThemeMode initialThemeMode =
      await loadPreferredThemeMode() ?? ThemeMode.light;
  runApp(
    CobroApp(
      config: AppConfig.fromEnvironment(),
      initialThemeMode: initialThemeMode,
    ),
  );
}
