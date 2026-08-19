import 'package:flutter/material.dart';

import '../features/dashboard/presentation/home_page.dart';
import 'app_config.dart';
import 'app_theme.dart';

class CobroApp extends StatefulWidget {
  const CobroApp({required this.config, super.key});

  final AppConfig config;

  @override
  State<CobroApp> createState() => _CobroAppState();
}

class _CobroAppState extends State<CobroApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cobros',
      debugShowCheckedModeBanner: false,
      theme: CobroAppTheme.light(),
      darkTheme: CobroAppTheme.dark(),
      themeMode: _themeMode,
      home: HomePage(
        apiBaseUrl: widget.config.apiBaseUrl,
        themeMode: _themeMode,
        onThemeModeChanged: (ThemeMode mode) {
          setState(() => _themeMode = mode);
        },
      ),
    );
  }
}
