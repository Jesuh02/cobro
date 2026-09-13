import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';
import 'calculo_credito.dart';

class ResumenCreditoAnimado extends StatefulWidget {
  const ResumenCreditoAnimado({
    super.key,
    required this.valorController,
    required this.interesController,
    required this.plazoController,
    required this.frecuencias,
    required this.frecuenciaPagoId,
    required this.fechaInicio,
    required this.omitirDomingos,
  });

  final TextEditingController valorController;
  final TextEditingController interesController;
  final TextEditingController plazoController;
  final List<FrecuenciaPago> frecuencias;
  final int? frecuenciaPagoId;
  final DateTime fechaInicio;
  final bool omitirDomingos;

  @override
  State<ResumenCreditoAnimado> createState() => _ResumenCreditoAnimadoState();
}

class _ResumenCreditoAnimadoState extends State<ResumenCreditoAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacionBilletes;

  @override
  void initState() {
    super.initState();
    _animacionBilletes = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _agregarListeners(widget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reducirMovimiento =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducirMovimiento) {
      _animacionBilletes.stop();
      _animacionBilletes.value = 0.58;
    } else if (!_animacionBilletes.isAnimating) {
      _animacionBilletes.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ResumenCreditoAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valorController != widget.valorController ||
        oldWidget.interesController != widget.interesController ||
        oldWidget.plazoController != widget.plazoController) {
      _quitarListeners(oldWidget);
      _agregarListeners(widget);
    }
  }

  void _agregarListeners(ResumenCreditoAnimado resumen) {
    resumen.valorController.addListener(_actualizarCalculo);
    resumen.interesController.addListener(_actualizarCalculo);
    resumen.plazoController.addListener(_actualizarCalculo);
  }

  void _quitarListeners(ResumenCreditoAnimado resumen) {
    try {
      resumen.valorController.removeListener(_actualizarCalculo);
    } catch (_) {}
    try {
      resumen.interesController.removeListener(_actualizarCalculo);
    } catch (_) {}
    try {
      resumen.plazoController.removeListener(_actualizarCalculo);
    } catch (_) {}
  }

  void _actualizarCalculo() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _quitarListeners(widget);
    _animacionBilletes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FrecuenciaPago? frecuencia = _frecuenciaSeleccionada();
    final CalculoCredito calculo = CalculoCredito.desdeFormulario(
      valor: widget.valorController.text,
      interes: widget.interesController.text,
      plazo: widget.plazoController.text,
      fechaInicio: widget.fechaInicio,
      diasIntervalo: frecuencia?.diasIntervalo ?? 1,
      omitirDomingos: widget.omitirDomingos,
    );
    final ThemeData theme = Theme.of(context);
    final Color acento = CobroAppTheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: acento.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: CobroAppTheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Así se calcula el crédito',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Los valores cambian mientras completas el formulario.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.auto_graph_rounded,
                color: CobroAppTheme.success,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FlujoBilletes(
            animacion: _animacionBilletes,
            capital: calculo.valorPrincipal,
            porcentajeInteres: calculo.porcentajeInteres,
            interes: calculo.valorInteres,
            total: calculo.valorTotal,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: context.clay.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.clay.border),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.event_repeat_rounded,
                  color: CobroAppTheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${formatMoney(calculo.valorTotal)} ÷ '
                        '${calculo.numeroCuotas} cuotas = '
                        '${formatMoney(calculo.valorCuota)} por cuota',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${calculo.numeroCuotas} cuotas '
                        '${etiquetaFrecuencia(frecuencia)} · '
                        'fecha máxima ${formatDateLabel(calculo.fechaMaxima)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.clay.subtleText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    formatMoney(calculo.valorCuota),
                    key: ValueKey<String>(
                      '${calculo.valorCuota}-${calculo.numeroCuotas}',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: CobroAppTheme.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.clay.text,
                height: 1.45,
              ),
              children: <InlineSpan>[
                const TextSpan(text: 'El cliente recibe '),
                _resaltado(formatMoney(calculo.valorPrincipal), acento),
                const TextSpan(text: '. El interés del '),
                _resaltado(
                  '${formatNumber(calculo.porcentajeInteres)}%',
                  CobroAppTheme.warning,
                ),
                const TextSpan(text: ' suma '),
                _resaltado(
                  formatMoney(calculo.valorInteres),
                  CobroAppTheme.warning,
                ),
                const TextSpan(text: ', para un total de '),
                _resaltado(
                  formatMoney(calculo.valorTotal),
                  CobroAppTheme.success,
                ),
                TextSpan(
                  text: ' en ${calculo.numeroCuotas} cuotas '
                      '${etiquetaFrecuencia(frecuencia)} de '
                      '${formatMoney(calculo.valorCuota)}. ',
                ),
                TextSpan(
                  text: widget.omitirDomingos &&
                          (frecuencia?.diasIntervalo ?? 1) == 1
                      ? 'Se omiten ${calculo.domingosOmitidos} domingos.'
                      : 'No se omiten días del calendario.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  FrecuenciaPago? _frecuenciaSeleccionada() {
    for (final FrecuenciaPago frecuencia in widget.frecuencias) {
      if (frecuencia.id == widget.frecuenciaPagoId) {
        return frecuencia;
      }
    }
    return widget.frecuencias.isEmpty ? null : widget.frecuencias.first;
  }

  TextSpan _resaltado(String texto, Color color) {
    return TextSpan(
      text: texto,
      style: TextStyle(color: color, fontWeight: FontWeight.w900),
    );
  }
}

class FlujoBilletes extends StatelessWidget {
  const FlujoBilletes({
    super.key,
    required this.animacion,
    required this.capital,
    required this.porcentajeInteres,
    required this.interes,
    required this.total,
  });

  final Animation<double> animacion;
  final double capital;
  final double porcentajeInteres;
  final double interes;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Animación del dinero desde el capital hasta el total del crédito',
      child: SizedBox(
        height: 150,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  top: 3,
                  left: 5,
                  right: 5,
                  height: 38,
                  child: AnimatedBuilder(
                    animation: animacion,
                    builder: (BuildContext context, Widget? child) {
                      return Stack(
                        children: List<Widget>.generate(3, (int index) {
                          final double fase =
                              (animacion.value + (index * 0.31)) % 1;
                          final double recorrido =
                              math.max(0, constraints.maxWidth - 58);
                          return Positioned(
                            left: recorrido * fase,
                            top: 5 + math.sin(fase * math.pi * 2) * 3,
                            child: Opacity(
                              opacity: 0.48 +
                                  (math.sin(fase * math.pi).abs() * 0.52),
                              child: Transform.rotate(
                                angle: math.sin(fase * math.pi * 2) * 0.08,
                                child: const Billete(),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 46,
                  left: 0,
                  right: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: PasoCalculo(
                          icono: Icons.payments_rounded,
                          etiqueta: 'Capital',
                          valor: formatMoney(capital),
                          color: CobroAppTheme.primary,
                        ),
                      ),
                      const FlechaFlujo(simbolo: '+'),
                      Expanded(
                        child: PasoCalculo(
                          icono: Icons.percent_rounded,
                          etiqueta:
                              '${formatNumber(porcentajeInteres)}% interés',
                          valor: formatMoney(interes),
                          color: CobroAppTheme.warning,
                        ),
                      ),
                      const FlechaFlujo(simbolo: '='),
                      Expanded(
                        child: PasoCalculo(
                          icono: Icons.account_balance_wallet_rounded,
                          etiqueta: 'Total',
                          valor: formatMoney(total),
                          color: CobroAppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class Billete extends StatelessWidget {
  const Billete({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 27,
      decoration: BoxDecoration(
        color: CobroAppTheme.success,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CobroAppTheme.success.withValues(alpha: 0.24),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.attach_money_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class FlechaFlujo extends StatelessWidget {
  const FlechaFlujo({super.key, required this.simbolo});

  final String simbolo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Text(
        simbolo,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.clay.subtleText,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class PasoCalculo extends StatelessWidget {
  const PasoCalculo({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: context.clay.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.clay.subtleText,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
