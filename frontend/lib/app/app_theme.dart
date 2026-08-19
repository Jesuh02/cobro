import 'package:flutter/material.dart';

import '../core/ui/clay.dart';

class CobroAppTheme {
  const CobroAppTheme._();

  static const Color primary = Color(0xFF1683F3);
  static const Color primaryLight = Color(0xFF45A3FF);
  static const Color primaryDark = Color(0xFF0A69DD);
  static const Color success = Color(0xFF0E9F6E);
  static const Color danger = Color(0xFFE34B6F);
  static const Color warning = Color(0xFFF59E0B);
  static const Color violet = Color(0xFF8B5CF6);

  static ThemeData light() {
    return _build(
      brightness: Brightness.light,
      clay: const ClayTokens(
        background: Color(0xFFEEF1F4),
        surface: Color(0xFFF7F9FB),
        surfaceHigh: Color(0xFFFFFFFF),
        surfaceLow: Color(0xFFE5E9EE),
        border: Color(0xFFDCE2E8),
        text: Color(0xFF182234),
        subtleText: Color(0xFF667181),
        shadow: Color(0xFF8793A3),
        highlight: Color(0xFFFFFFFF),
        warningSurface: Color(0xFFFFF5D7),
        warningBorder: Color(0xFFFFD979),
        chartBackground: Color(0xFFE9EDF2),
        progressBackground: Color(0xFFDCE3EA),
        inactiveBar: Color(0xFFB8DDFB),
      ),
    );
  }

  static ThemeData dark() {
    return _build(
      brightness: Brightness.dark,
      clay: const ClayTokens(
        background: Color(0xFF101720),
        surface: Color(0xFF182330),
        surfaceHigh: Color(0xFF202D3C),
        surfaceLow: Color(0xFF111923),
        border: Color(0xFF344559),
        text: Color(0xFFF4F7FA),
        subtleText: Color(0xFFAFBBC9),
        shadow: Color(0xFF03070B),
        highlight: Color(0xFF34485E),
        warningSurface: Color(0xFF352C17),
        warningBorder: Color(0xFF725A1E),
        chartBackground: Color(0xFF111923),
        progressBackground: Color(0xFF304257),
        inactiveBar: Color(0xFF294F70),
      ),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required ClayTokens clay,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      secondary: success,
      tertiary: danger,
      surface: clay.surface,
    ).copyWith(
      primary: primary,
      primaryContainer:
          isDark ? const Color(0xFF123C67) : const Color(0xFFDCEEFF),
      secondary: success,
      tertiary: danger,
      error: danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: clay.text,
      outline: clay.border,
      outlineVariant: clay.border.withValues(alpha: isDark ? 0.72 : 0.82),
      surfaceContainerLow: clay.surface,
      surfaceContainer: clay.surface,
      surfaceContainerHighest: clay.surfaceHigh,
    );

    final InputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: clay.border.withValues(alpha: isDark ? 0.92 : 0.88),
      ),
    );
    final InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: clay.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      constraints: const BoxConstraints(minHeight: 52),
      hintStyle: TextStyle(
        color: clay.subtleText.withValues(alpha: 0.9),
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(color: clay.subtleText),
      floatingLabelStyle: const TextStyle(
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      prefixIconColor: clay.subtleText,
      suffixIconColor: clay.subtleText,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: clay.border.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: danger, width: 1.6),
      ),
      errorStyle: const TextStyle(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[clay],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: clay.background,
      canvasColor: clay.background,
      cardColor: clay.surface,
      dividerColor: clay.border,
      shadowColor: clay.shadow,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.standard,
      textTheme: _textTheme(brightness, clay),
      iconTheme: IconThemeData(color: clay.subtleText, size: 22),
      dividerTheme: DividerThemeData(
        color: clay.border.withValues(alpha: isDark ? 0.78 : 0.86),
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: clay.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: clay.shadow.withValues(alpha: isDark ? 0.48 : 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: clay.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        backgroundColor: clay.background,
        foregroundColor: clay.text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: clay.text,
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: clay.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: clay.shadow.withValues(alpha: isDark ? 0.68 : 0.28),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: clay.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: primary,
        headerForegroundColor: Colors.white,
        elevation: 24,
        shadowColor: clay.shadow.withValues(alpha: isDark ? 0.65 : 0.28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        dayShape: const WidgetStatePropertyAll<OutlinedBorder>(
          CircleBorder(),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: clay.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 28,
        shadowColor: clay.shadow.withValues(alpha: isDark ? 0.76 : 0.3),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          color: clay.text,
          fontFamily: 'Inter',
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: clay.surfaceHigh,
        contentTextStyle: TextStyle(
          color: clay.text,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 12,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? clay.surfaceHigh : clay.text,
          borderRadius: BorderRadius.circular(12),
          boxShadow: clay.raisedShadow,
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: inputDecorationTheme,
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(44, 44)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.all(10),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return clay.surfaceLow;
              }
              return clay.surfaceHigh;
            },
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(clay.text),
          overlayColor: WidgetStatePropertyAll<Color>(
            primary.withValues(alpha: isDark ? 0.2 : 0.11),
          ),
          elevation: WidgetStateProperty.resolveWith<double>(
            (Set<WidgetState> states) =>
                states.contains(WidgetState.pressed) ? 1 : 5,
          ),
          shadowColor: WidgetStatePropertyAll<Color>(
            clay.shadow.withValues(alpha: isDark ? 0.46 : 0.2),
          ),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: clay.border),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: clay.subtleText,
        textColor: clay.text,
        selectedColor: primary,
        selectedTileColor: primary.withValues(alpha: isDark ? 0.2 : 0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: clay.surfaceLow,
          disabledForegroundColor: clay.subtleText,
          minimumSize: const Size(0, 52),
          elevation: 7,
          shadowColor: primary.withValues(alpha: isDark ? 0.36 : 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: clay.text,
          backgroundColor: clay.surfaceHigh,
          disabledForegroundColor: clay.subtleText.withValues(alpha: 0.6),
          minimumSize: const Size(0, 52),
          elevation: 5,
          shadowColor: clay.shadow.withValues(alpha: isDark ? 0.46 : 0.18),
          side: BorderSide(color: clay.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 10,
        focusElevation: 11,
        hoverElevation: 13,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: clay.surface,
        height: 72,
        elevation: 16,
        shadowColor: clay.shadow.withValues(alpha: isDark ? 0.62 : 0.24),
        indicatorColor: primary.withValues(alpha: isDark ? 0.24 : 0.13),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : clay.subtleText,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? primary
                : clay.subtleText,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 48)),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return primary.withValues(alpha: isDark ? 0.22 : 0.13);
              }
              return clay.surfaceHigh;
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return isDark ? const Color(0xFF8ED0F4) : primary;
              }
              return clay.text;
            },
          ),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: clay.border),
          ),
          elevation: const WidgetStatePropertyAll<double>(3),
          shadowColor: WidgetStatePropertyAll<Color>(
            clay.shadow.withValues(alpha: isDark ? 0.44 : 0.18),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return clay.subtleText;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return clay.surfaceLow;
          },
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected) ? primary : null;
        }),
        side: BorderSide(color: clay.border, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? primary
              : clay.subtleText;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: clay.progressBackground,
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness, ClayTokens clay) {
    final Typography typography = Typography.material2021();
    final TextTheme base =
        brightness == Brightness.dark ? typography.white : typography.black;

    final TextTheme themed = base.apply(
      fontFamily: 'Inter',
      bodyColor: clay.text,
      displayColor: clay.text,
      decorationColor: clay.text,
    );

    return themed.copyWith(
      headlineLarge: themed.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      headlineMedium: themed.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      headlineSmall: themed.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleLarge: themed.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: themed.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: themed.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
