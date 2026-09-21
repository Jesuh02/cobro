import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';

/// Cabecera visual fintech para la pantalla de autenticación.
///
/// Exhibe las tarjetas operativas del sistema (cartera y recaudo WhatsApp),
/// un pin GPS de ruta, una moneda en relieve y elementos celestes/orbitales.
class LoginFintechHeader extends StatefulWidget {
  const LoginFintechHeader({
    required this.themeMode,
    super.key,
  });

  final ThemeMode themeMode;

  @override
  State<LoginFintechHeader> createState() => _LoginFintechHeaderState();
}

class _LoginFintechHeaderState extends State<LoginFintechHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
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
    final bool isDark = widget.themeMode == ThemeMode.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const <Color>[
                    Color(0xFF0D254C),
                    Color(0xFF0F1E38),
                    Color(0xFF0A1324),
                  ]
                : const <Color>[
                    Color(0xFF103366),
                    Color(0xFF0F264C),
                    Color(0xFF0C1D3A),
                  ],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // Trazado de órbita y líneas de ruta viales
            Positioned.fill(
              child: CustomPaint(
                painter: _RouteOrbitPainter(),
              ),
            ),

            // Destello 1 (Arriba Izquierda)
            Positioned(
              top: 24,
              left: 28,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _animation.value;
                    return Opacity(
                      opacity: (0.35 + (0.65 * t)).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.9 + (0.25 * t),
                        child: child,
                      ),
                    );
                  },
                  child: const Text(
                    '✦',
                    style: TextStyle(
                      color: Color(0xFF7DD3FC),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Destello 2 (Arriba Derecha)
            Positioned(
              top: 50,
              right: 28,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _animation.value;
                    return Opacity(
                      opacity: (0.35 + (0.65 * (1.0 - t))).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.9 + (0.25 * (1.0 - t)),
                        child: child,
                      ),
                    );
                  },
                  child: const Text(
                    '✦',
                    style: TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),

            // Destello 3 (Abajo Izquierda)
            Positioned(
              bottom: 48,
              left: 24,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _animation.value;
                    return Opacity(
                      opacity: (0.4 + (0.5 * t)).clamp(0.0, 1.0),
                      child: child,
                    );
                  },
                  child: const Text(
                    '✦',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),

            // Contenido principal de la cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Escenario central de tarjetas y elementos flotantes animados
                  SizedBox(
                    height: 132,
                    width: double.infinity,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (BuildContext context, Widget? child) {
                          final double t = _animation.value;
                          final double card1Dy = -8.0 * t;
                          final double card1Angle =
                              (-13.0 + (2.5 * t)) * (math.pi / 180);

                          final double card2Dy = -10.0 * t;
                          final double card2Angle =
                              (11.0 + (2.0 * t)) * (math.pi / 180);

                          final double coinDy = -11.0 * t;
                          final double coinAngle = (14.0 * t) * (math.pi / 180);

                          final double pinDy = -6.0 * t;
                          final double pinScale = 1.0 + (0.06 * t);

                          return Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              // Pin GPS de Ruta Flotante (Arriba a la derecha)
                              Positioned(
                                top: -6 + pinDy,
                                right: 12,
                                child: Transform.scale(
                                  scale: pinScale,
                                  child: _buildGpsPinBadge(),
                                ),
                              ),

                              // Moneda Dorada 3D con Relieve "$" (Abajo a la izquierda)
                              Positioned(
                                bottom: 2 + coinDy,
                                left: 12,
                                child: Transform.rotate(
                                  angle: coinAngle,
                                  child: _buildGoldenCoin(),
                                ),
                              ),

                              // Tarjeta Trasera: Recaudo & Comprobante WhatsApp
                              Positioned(
                                left: 36,
                                top: 14 + card1Dy,
                                child: Transform.rotate(
                                  angle: card1Angle,
                                  child: const _BackWhatsappCard(),
                                ),
                              ),

                              // Tarjeta Delantera: Credencial de Cartera & Ruta
                              Positioned(
                                right: 34,
                                top: 18 + card2Dy,
                                child: Transform.rotate(
                                  angle: card2Angle,
                                  child: const _FrontCarteraCard(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Badge institucional "Sistema de Cobro & Cartera"
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CobroAppTheme.primary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CobroAppTheme.primaryLight.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: CobroAppTheme.primaryLight,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Sistema de Cobro & Cartera',
                          style: TextStyle(
                            color: Color(0xFFBAE6FD),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsPinBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 0.9,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.location_on_rounded,
            size: 13,
            color: Color(0xFF34D399),
          ),
          SizedBox(width: 3),
          Text(
            'Ruta activa',
            style: TextStyle(
              color: Color(0xFFA7F3D0),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldenCoin() {
    return Container(
      width: 28,
      height: 28,
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
          width: 1.2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66F59E0B),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '\$',
          style: TextStyle(
            color: Color(0xFF78350F),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta trasera que representa el abono y recibo de WhatsApp.
class _BackWhatsappCard extends StatelessWidget {
  const _BackWhatsappCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      height: 92,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF059669),
            Color(0xFF0E9F6E),
            Color(0xFF047857),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFF6EE7B7).withValues(alpha: 0.35),
          width: 0.8,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Fila superior: WhatsApp badge y consecutivo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 8,
                      color: Colors.white,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'WHATSAPP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 6.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '#REC-042',
                style: TextStyle(
                  color: Color(0xFFA7F3D0),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),

          // Centro: Monto del abono registrado
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'ABONO REGISTRADO',
                style: TextStyle(
                  color: Color(0xFFD1FAE5),
                  fontSize: 6.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                r'+$50.000 COP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),

          // Fila inferior: Estado de recaudo y cuota
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '✓ RECAUDADO',
                  style: TextStyle(
                    color: Color(0xFFA7F3D0),
                    fontSize: 6.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Text(
                'Cuota 4/20',
                style: TextStyle(
                  color: Color(0xFFA7F3D0),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta delantera que representa la cartera activa y credencial de cobro.
class _FrontCarteraCard extends StatelessWidget {
  const _FrontCarteraCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      height: 94,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF45A3FF),
            Color(0xFF1683F3),
            Color(0xFF0A69DD),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 0.9,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x550A69DD),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Fila superior: Chip dorado de seguridad + Isotipo Cobro
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 15,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE68A),
                      borderRadius: BorderRadius.circular(2.5),
                      border: Border.all(
                        color: const Color(0xFFD97706),
                        width: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.contactless_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  const Text(
                    'COBRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    child: const Center(
                      child: Text(
                        r'$',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Centro: Monto de la cartera
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'CARTERA DEL DÍA',
                style: TextStyle(
                  color: Color(0xFFDBEAFE),
                  fontSize: 6.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                r'$1.250.000 COP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),

          // Fila inferior: Ruta norte activa y avance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'RUTA NORTE • ACTIVA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 6.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF6EE7B7),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    '85%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dibuja la órbita punteada y líneas de ruteo tenues en el fondo.
class _RouteOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Órbita elíptica
    final Rect rect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.46),
      width: size.width * 0.88,
      height: 110,
    );
    canvas.drawOval(rect, paint);

    // Trazo de ruta vial
    final Paint routePaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final Path path = Path()
      ..moveTo(0, size.height * 0.7)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.45,
        size.width * 0.55,
        size.height * 0.8,
        size.width,
        size.height * 0.35,
      );

    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

