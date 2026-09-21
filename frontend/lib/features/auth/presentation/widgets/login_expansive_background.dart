import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Fondo ambiental expansivo que complementa la tarjeta de login.
///
/// Extiende las líneas de ruta, órbitas y auras de luz de la cabecera
/// hacia todo el fondo de la pantalla, incorporando elementos complementarios
/// como monedas doradas secundarias y destellos celestes en pantallas amplias.
class LoginExpansiveBackground extends StatefulWidget {
  const LoginExpansiveBackground({
    required this.isDark,
    super.key,
  });

  final bool isDark;

  @override
  State<LoginExpansiveBackground> createState() =>
      _LoginExpansiveBackgroundState();
}

class _LoginExpansiveBackgroundState extends State<LoginExpansiveBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;
          final bool isWide = screenWidth > 820;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              // Aura esmeralda izquierda (proyectada por la tarjeta WhatsApp)
              Positioned(
                top: screenHeight * 0.20,
                left: screenWidth * 0.5 - (isWide ? 460 : 270),
                child: Container(
                  width: isWide ? 500 : 340,
                  height: isWide ? 500 : 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        (isDark
                                ? const Color(0xFF10B981)
                                : const Color(0xFF34D399))
                            .withValues(
                          alpha: isDark ? 0.16 : 0.30,
                        ),
                        const Color(0xFF10B981).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Aura azul cobalto derecha (proyectada por la tarjeta Cartera)
              Positioned(
                top: screenHeight * 0.30,
                left: screenWidth * 0.5 - (isWide ? -30 : 0),
                child: Container(
                  width: isWide ? 520 : 360,
                  height: isWide ? 520 : 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        (isDark
                                ? const Color(0xFF1683F3)
                                : const Color(0xFF38BDF8))
                            .withValues(
                          alpha: isDark ? 0.18 : 0.32,
                        ),
                        const Color(0xFF1683F3).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Aura ámbar cálida (cercana a las monedas doradas)
              Positioned(
                top: screenHeight * 0.42,
                left: screenWidth * 0.5 - (isWide ? 420 : 200),
                child: Container(
                  width: isWide ? 340 : 220,
                  height: isWide ? 340 : 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        const Color(0xFFFBBF24).withValues(
                          alpha: isDark ? 0.10 : 0.22,
                        ),
                        const Color(0xFFFBBF24).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Trazado de órbitas y rutas viales expansivas
              Positioned.fill(
                child: CustomPaint(
                  painter: _ExpansiveRoutePainter(isDark: isDark),
                ),
              ),

              // Elementos flotantes animados (visibles en pantallas medianas y de escritorio)
              if (isWide) ...<Widget>[
                AnimatedBuilder(
                  animation: _animation,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _animation.value;
                    final double coin1Dy = -12.0 * t;
                    final double coin1Rot = (12.0 * t) * (math.pi / 180);

                    final double coin2Dy = 10.0 * t;
                    final double coin2Rot = (-10.0 * t) * (math.pi / 180);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        // Moneda Dorada 1 (Izquierda)
                        Positioned(
                          left: screenWidth * 0.5 - 340,
                          top: (screenHeight * 0.5 - 140) + coin1Dy,
                          child: Transform.rotate(
                            angle: coin1Rot,
                            child: _buildOuterCoin(
                              size: 32,
                              fontSize: 16,
                              isDark: isDark,
                            ),
                          ),
                        ),

                        // Moneda Dorada 2 (Derecha, más pequeña para dar profundidad)
                        Positioned(
                          left: screenWidth * 0.5 + 280,
                          top: (screenHeight * 0.5 + 130) + coin2Dy,
                          child: Transform.rotate(
                            angle: coin2Rot,
                            child: _buildOuterCoin(
                              size: 22,
                              fontSize: 11,
                              opacity: 0.90,
                              isDark: isDark,
                            ),
                          ),
                        ),

                        // Destello 1 (Arriba a la derecha)
                        Positioned(
                          left: screenWidth * 0.5 + 320,
                          top: screenHeight * 0.5 - 180,
                          child: Opacity(
                            opacity: (isDark
                                    ? 0.3 + (0.6 * t)
                                    : 0.5 + (0.5 * t))
                                .clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.9 + (0.3 * t),
                              child: Text(
                                '✦',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF0284C7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Destello 2 (Izquierda abajo)
                        Positioned(
                          left: screenWidth * 0.5 - 360,
                          top: screenHeight * 0.5 + 160,
                          child: Opacity(
                            opacity: (isDark
                                    ? 0.35 + (0.55 * (1.0 - t))
                                    : 0.55 + (0.45 * (1.0 - t)))
                                .clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.85 + (0.25 * (1.0 - t)),
                              child: Text(
                                '✦',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFF059669),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Destello 3 (Derecha abajo)
                        Positioned(
                          left: screenWidth * 0.5 + 260,
                          top: screenHeight * 0.5 + 220,
                          child: Opacity(
                            opacity: (isDark
                                    ? 0.25 + (0.6 * t)
                                    : 0.5 + (0.5 * t))
                                .clamp(0.0, 1.0),
                            child: Text(
                              '✦',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFD97706),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOuterCoin({
    required double size,
    required double fontSize,
    required bool isDark,
    double opacity = 1.0,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFDE68A),
              Color(0xFFF59E0B),
              Color(0xFFD97706),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFEF3C7),
            width: size > 25 ? 1.2 : 0.8,
          ),
          boxShadow: <BoxShadow>[
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: size * 0.45,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: const Color(0xFFF59E0B)
                  .withValues(alpha: isDark ? 0.35 : 0.45),
              blurRadius: size * 0.45,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            r'$',
            style: TextStyle(
              color: const Color(0xFF78350F),
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpansiveRoutePainter extends CustomPainter {
  const _ExpansiveRoutePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.5, size.height * 0.48);

    // Órbita elíptica primaria (cian #38BDF8 en dark / azul cobalto #0284C7 en light)
    final Paint orbit1Paint = Paint()
      ..color = (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
          .withValues(alpha: isDark ? 0.16 : 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 1.2 : 1.4;

    final Rect orbit1Rect = Rect.fromCenter(
      center: center,
      width: math.min(size.width * 0.88, 920),
      height: 480,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-8 * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    _drawDashedOval(canvas, orbit1Rect, orbit1Paint, 6, 8);
    canvas.restore();

    // Órbita elíptica secundaria mayor (esmeralda #10B981 en dark / esmeralda nítido #059669 en light)
    final Paint orbit2Paint = Paint()
      ..color = (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
          .withValues(alpha: isDark ? 0.13 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 1.0 : 1.3;

    final Rect orbit2Rect = Rect.fromCenter(
      center: center,
      width: math.min(size.width * 0.98, 1140),
      height: 600,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(6 * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    _drawDashedOval(canvas, orbit2Rect, orbit2Paint, 8, 10);
    canvas.restore();

    // Trazados de ruta vial fluida
    final Paint route1Paint = Paint()
      ..color = (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
          .withValues(alpha: isDark ? 0.22 : 0.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 1.6 : 2.0;

    final Path route1Path = Path()
      ..moveTo(0, size.height * 0.62)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.38,
        size.width * 0.40,
        size.height * 0.68,
        size.width * 0.58,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.22,
        size.width * 0.88,
        size.height * 0.54,
        size.width,
        size.height * 0.46,
      );

    _drawDashedPath(canvas, route1Path, route1Paint, 6, 8);

    final Paint route2Paint = Paint()
      ..color = (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
          .withValues(alpha: isDark ? 0.18 : 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 1.3 : 1.7;

    final Path route2Path = Path()
      ..moveTo(0, size.height * 0.36)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.20,
        size.width * 0.44,
        size.height * 0.44,
        size.width * 0.62,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.70,
        size.width * 0.90,
        size.height * 0.35,
        size.width,
        size.height * 0.52,
      );

    _drawDashedPath(canvas, route2Path, route2Paint, 5, 7);

    // Waypoint nodes en las rutas si hay buen ancho
    if (size.width > 700) {
      final Offset node1 = Offset(size.width * 0.24, size.height * 0.45);
      final Offset node2 = Offset(size.width * 0.78, size.height * 0.42);

      final Color node1Color =
          isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
      final Paint nodePaint = Paint()
        ..color = node1Color.withValues(alpha: isDark ? 0.7 : 0.88)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node1, isDark ? 4.5 : 5.0, nodePaint);

      final Paint nodeHalo = Paint()
        ..color = node1Color.withValues(alpha: isDark ? 0.25 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDark ? 1.2 : 1.6;
      canvas.drawCircle(node1, 10, nodeHalo);

      final Color node2Color =
          isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      final Paint node2Paint = Paint()
        ..color = node2Color.withValues(alpha: isDark ? 0.7 : 0.88)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node2, isDark ? 4.5 : 5.0, node2Paint);

      final Paint node2Halo = Paint()
        ..color = node2Color.withValues(alpha: isDark ? 0.25 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDark ? 1.2 : 1.6;
      canvas.drawCircle(node2, 10, node2Halo);
    }
  }

  void _drawDashedOval(
    Canvas canvas,
    Rect rect,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final Path path = Path()..addOval(rect);
    _drawDashedPath(canvas, path, paint, dashWidth, dashSpace);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path source,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double end = math.min(distance + dashWidth, metric.length);
        final Path extract = metric.extractPath(distance, end);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExpansiveRoutePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

