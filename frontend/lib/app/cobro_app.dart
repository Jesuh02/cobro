import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/dashboard/presentation/home_page.dart';
import 'app_config.dart';
import 'app_theme.dart';
import 'theme_preference.dart';

class CobroApp extends StatefulWidget {
  const CobroApp({
    required this.config,
    this.initialThemeMode = ThemeMode.light,
    super.key,
  });

  final AppConfig config;
  final ThemeMode initialThemeMode;

  @override
  State<CobroApp> createState() => _CobroAppState();
}

class _CobroAppState extends State<CobroApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Cobros',
      debugShowCheckedModeBanner: false,
      theme: CobroAppTheme.light(),
      darkTheme: CobroAppTheme.dark(),
      themeMode: _themeMode,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('es', 'CO'),
        Locale('es'),
      ],
      locale: const Locale('es', 'CO'),
      home: HomePage(
        apiBaseUrl: widget.config.apiBaseUrl,
        themeMode: _themeMode,
        onThemeModeChanged: (ThemeMode mode) {
          setState(() => _themeMode = mode);
          unawaited(savePreferredThemeMode(mode));
        },
      ),
    );
  }
}
