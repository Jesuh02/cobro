import 'package:flutter/material.dart';

import 'clay.dart';

class SkeletonListaCreditos extends StatefulWidget {
  const SkeletonListaCreditos({super.key});

  @override
  State<SkeletonListaCreditos> createState() => _SkeletonListaCreditosState();
}

class _SkeletonListaCreditosState extends State<SkeletonListaCreditos>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: List<Widget>.generate(
            3,
            (int index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SkeletonTarjetaCredito(progreso: _controller.value),
            ),
          ),
        );
      },
    );
  }
}

class SkeletonTarjetaCredito extends StatelessWidget {
  const SkeletonTarjetaCredito({super.key, required this.progreso});

  final double progreso;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonCreditoBloque(
                      progreso: progreso,
                      width: 210,
                      height: 18,
                    ),
                    const SizedBox(height: 8),
                    SkeletonCreditoBloque(
                      progreso: progreso,
                      width: 280,
                      height: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SkeletonCreditoBloque(
                progreso: progreso,
                width: 78,
                height: 28,
                radius: 999,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SkeletonCreditoBloque(
            progreso: progreso,
            width: double.infinity,
            height: 9,
            radius: 999,
          ),
          const SizedBox(height: 8),
          SkeletonCreditoBloque(
            progreso: progreso,
            width: 230,
            height: 12,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: List<Widget>.generate(
              6,
              (int index) => SkeletonDatoCredito(progreso: progreso),
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonDatoCredito extends StatelessWidget {
  const SkeletonDatoCredito({super.key, required this.progreso});

  final double progreso;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonCreditoBloque(
            progreso: progreso,
            width: 58,
            height: 10,
          ),
          const SizedBox(height: 6),
          SkeletonCreditoBloque(
            progreso: progreso,
            width: 94,
            height: 15,
          ),
        ],
      ),
    );
  }
}

class SkeletonCreditoBloque extends StatelessWidget {
  const SkeletonCreditoBloque({
    super.key,
    required this.progreso,
    required this.width,
    required this.height,
    this.radius = 7,
  });

  final double progreso;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bool oscuro = Theme.of(context).brightness == Brightness.dark;
    final Color base = context.clay.border.withValues(
      alpha: oscuro ? 0.38 : 0.5,
    );
    final Color brillo = Colors.white.withValues(alpha: oscuro ? 0.14 : 0.58);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: base),
            FractionalTranslation(
              translation: Offset((progreso * 2.4) - 1.2, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      brillo,
                      Colors.transparent,
                    ],
                    stops: const <double>[0.24, 0.5, 0.76],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonListaMovimientosCaja extends StatefulWidget {
  const SkeletonListaMovimientosCaja({super.key});

  @override
  State<SkeletonListaMovimientosCaja> createState() =>
      _SkeletonListaMovimientosCajaState();
}

class _SkeletonListaMovimientosCajaState
    extends State<SkeletonListaMovimientosCaja>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: List<Widget>.generate(
            4,
            (int index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SkeletonTarjetaMovimientoCaja(
                progreso: _controller.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class SkeletonTarjetaMovimientoCaja extends StatelessWidget {
  const SkeletonTarjetaMovimientoCaja({super.key, required this.progreso});

  final double progreso;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 380;
        final Widget detalle = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SkeletonCreditoBloque(
              progreso: progreso,
              width: compact ? 150 : 220,
              height: 16,
            ),
            const SizedBox(height: 8),
            SkeletonCreditoBloque(
              progreso: progreso,
              width: double.infinity,
              height: 12,
            ),
            if (compact) ...<Widget>[
              const SizedBox(height: 10),
              SkeletonCreditoBloque(
                progreso: progreso,
                width: 88,
                height: 18,
              ),
            ],
          ],
        );

        return ClaySurface(
          radius: 14,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              SkeletonCreditoBloque(
                progreso: progreso,
                width: 42,
                height: 42,
                radius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(child: detalle),
              if (!compact) ...<Widget>[
                const SizedBox(width: 12),
                SkeletonCreditoBloque(
                  progreso: progreso,
                  width: 88,
                  height: 18,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
