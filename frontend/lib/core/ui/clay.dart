<import 'package:flutter/material.dart';

class ClayRadius {
  const ClayRadius._();

  static const double small = 12;
  static const double control = 16;
  static const double surface = 20;
  static const double dialog = 22;
  static const double sheet = 24;
}

@immutable
class ClayTokens extends ThemeExtension<ClayTokens> {
  const ClayTokens({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceLow,
    required this.border,
    required this.text,
    required this.subtleText,
    required this.shadow,
    required this.highlight,
    required this.warningSurface,
    required this.warningBorder,
    required this.chartBackground,
    required this.progressBackground,
    required this.inactiveBar,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceLow;
  final Color border;
  final Color text;
  final Color subtleText;
  final Color shadow;
  final Color highlight;
  final Color warningSurface;
  final Color warningBorder;
  final Color chartBackground;
  final Color progressBackground;
  final Color inactiveBar;

  bool get isDark => background.computeLuminance() < 0.22;

  List<BoxShadow> get raisedShadow {
    return <BoxShadow>[
      BoxShadow(
        color: highlight.withValues(alpha: isDark ? 0.24 : 0.82),
        blurRadius: 12,
        spreadRadius: -2,
        offset: const Offset(-4, -4),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: isDark ? 0.46 : 0.19),
        blurRadius: 20,
        spreadRadius: -3,
        offset: const Offset(7, 9),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: isDark ? 0.26 : 0.08),
        blurRadius: 4,
        spreadRadius: -1,
        offset: const Offset(1, 2),
      ),
    ];
  }

  List<BoxShadow> get floatingShadow {
    return <BoxShadow>[
      BoxShadow(
        color: highlight.withValues(alpha: isDark ? 0.28 : 0.9),
        blurRadius: 18,
        spreadRadius: -3,
        offset: const Offset(-6, -6),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: isDark ? 0.58 : 0.25),
        blurRadius: 28,
        spreadRadius: -4,
        offset: const Offset(10, 13),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: isDark ? 0.3 : 0.1),
        blurRadius: 6,
        spreadRadius: -1,
        offset: const Offset(2, 3),
      ),
    ];
  }

  List<BoxShadow> get pressedShadow {
    return <BoxShadow>[
      BoxShadow(
        color: shadow.withValues(alpha: isDark ? 0.38 : 0.14),
        blurRadius: 7,
        spreadRadius: -1,
        offset: const Offset(2, 3),
      ),
    ];
  }

  @override
  ClayTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceLow,
    Color? border,
    Color? text,
    Color? subtleText,
    Color? shadow,
    Color? highlight,
    Color? warningSurface,
    Color? warningBorder,
    Color? chartBackground,
    Color? progressBackground,
    Color? inactiveBar,
  }) {
    return ClayTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      border: border ?? this.border,
      text: text ?? this.text,
      subtleText: subtleText ?? this.subtleText,
      shadow: shadow ?? this.shadow,
      highlight: highlight ?? this.highlight,
      warningSurface: warningSurface ?? this.warningSurface,
      warningBorder: warningBorder ?? this.warningBorder,
      chartBackground: chartBackground ?? this.chartBackground,
      progressBackground: progressBackground ?? this.progressBackground,
      inactiveBar: inactiveBar ?? this.inactiveBar,
    );
  }

  @override
  ClayTokens lerp(ThemeExtension<ClayTokens>? other, double t) {
    if (other is! ClayTokens) {
      return this;
    }

    return ClayTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      chartBackground: Color.lerp(chartBackground, other.chartBackground, t)!,
      progressBackground:
          Color.lerp(progressBackground, other.progressBackground, t)!,
      inactiveBar: Color.lerp(inactiveBar, other.inactiveBar, t)!,
    );
  }
}

extension ClayContext on BuildContext {
  ClayTokens get clay => Theme.of(this).extension<ClayTokens>()!;
}

class ClaySurface extends StatefulWidget {
  const ClaySurface({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.radius = ClayRadius.surface,
    this.color,
    this.borderColor,
    this.gradient,
    this.elevated = true,
    this.pressed = false,
    this.onTap,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final bool elevated;
  final bool pressed;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  State<ClaySurface> createState() => _ClaySurfaceState();
}

class _ClaySurfaceState extends State<ClaySurface> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool visuallyPressed = widget.pressed || _isPressed;
    final BorderRadius borderRadius = BorderRadius.circular(widget.radius);
    final Color baseColor = widget.color ?? clay.surface;
    final bool isNeutralSurface = widget.color == null ||
        baseColor == clay.surface ||
        baseColor == clay.surfaceHigh ||
        baseColor == clay.surfaceLow;
    final double leadingHighlight = clay.isDark
        ? 0.1
        : isNeutralSurface
            ? 0.5
            : 0.22;
    final Gradient effectiveGradient = widget.gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const <double>[0, 0.52, 1],
          colors: <Color>[
            Color.alphaBlend(
              clay.highlight.withValues(alpha: leadingHighlight),
              baseColor,
            ),
            Color.alphaBlend(
              clay.highlight.withValues(alpha: clay.isDark ? 0.025 : 0.12),
              baseColor,
            ),
            Color.alphaBlend(
              clay.shadow.withValues(alpha: clay.isDark ? 0.1 : 0.055),
              baseColor,
            ),
          ],
        );

    final Widget content = Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: widget.child,
    );

    final Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      constraints: widget.constraints,
      clipBehavior: widget.clipBehavior,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: borderRadius,
        border: Border.all(
          color: widget.borderColor ?? clay.border,
          width: 0.9,
        ),
        boxShadow: widget.elevated
            ? visuallyPressed
                ? clay.pressedShadow
                : clay.raisedShadow
            : const <BoxShadow>[],
      ),
      child: widget.onTap == null
          ? Material(
              type: MaterialType.transparency,
              child: content,
            )
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: borderRadius,
                onTap: widget.onTap,
                onHighlightChanged: (bool value) {
                  if (_isPressed != value) {
                    setState(() => _isPressed = value);
                  }
                },
                child: content,
              ),
            ),
    );

    return MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: AnimatedScale(
        scale: visuallyPressed && widget.onTap != null ? 0.985 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: surface,
      ),
    );
  }
}

class ClayIcon extends StatelessWidget {
  const ClayIcon({
    required this.icon,
    super.key,
    this.color,
    this.backgroundColor,
    this.size = 42,
    this.iconSize = 22,
    this.radius = 14,
  });

  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool usePrimaryGradient = backgroundColor == null;
    final Color iconColor =
        color ?? (usePrimaryGradient ? Colors.white : primary);

    return ClaySurface(
      width: size,
      height: size,
      radius: radius,
      color: backgroundColor,
      borderColor: usePrimaryGradient
          ? Colors.white.withValues(alpha: 0.32)
          : iconColor.withValues(alpha: 0.16),
      gradient: usePrimaryGradient
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF45A3FF),
                Color(0xFF1683F3),
                Color(0xFF0A69DD),
              ],
            )
          : null,
      elevated: true,
      child: Center(child: Icon(icon, color: iconColor, size: iconSize)),
    );
  }
}

class ClayGradientButton extends StatelessWidget {
  const ClayGradientButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expanded = false,
    this.loading = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool enabled = onPressed != null && !loading;
    final bool activeSurface = onPressed != null || loading;
    final Color primary = Theme.of(context).colorScheme.primary;
    final BorderRadius borderRadius = BorderRadius.circular(ClayRadius.control);

    final Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        gradient: activeSurface
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF45A3FF),
                  Color(0xFF1683F3),
                  Color(0xFF0A69DD),
                ],
              )
            : LinearGradient(
                colors: <Color>[clay.surfaceLow, clay.surfaceLow],
              ),
        borderRadius: borderRadius,
        border: Border.all(
          color: activeSurface
              ? Colors.white.withValues(alpha: 0.26)
              : clay.border,
        ),
        boxShadow: activeSurface
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.white.withValues(
                    alpha: clay.isDark ? 0.06 : 0.5,
                  ),
                  blurRadius: 8,
                  spreadRadius: -2,
                  offset: const Offset(-3, -3),
                ),
                BoxShadow(
                  color: primary.withValues(alpha: clay.isDark ? 0.34 : 0.3),
                  blurRadius: 18,
                  spreadRadius: -3,
                  offset: const Offset(0, 9),
                ),
              ]
            : clay.pressedShadow,
      ),
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          minimumSize: Size(0, height),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: clay.subtleText,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: loading
              ? const SizedBox(
                  key: ValueKey<String>('loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  key: const ValueKey<String>('label'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: 20),
                      const SizedBox(width: 9),
                    ],
                    Text(label),
                  ],
                ),
        ),
      ),
    );

    return SizedBox(width: expanded ? double.infinity : null, child: button);
  }
}
