import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models/models.dart';
import '../formatters/app_formatters.dart';
import 'clay.dart';

class EstadoCreditoChip extends StatelessWidget {
  const EstadoCreditoChip({super.key, required this.credito});

  final CreditoRegistro credito;

  @override
  Widget build(BuildContext context) {
    final Color color =
        credito.activo ? CobroAppTheme.success : context.clay.subtleText;
    return ClaySurface(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: color.withValues(alpha: 0.1),
      borderColor: color.withValues(alpha: 0.25),
      elevated: false,
      child: Text(
        credito.estado.nombre,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class EtiquetaRefinanciacion extends StatelessWidget {
  const EtiquetaRefinanciacion({super.key, required this.refinanciacion});

  final CreditoRefinanciacion refinanciacion;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CobroAppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CobroAppTheme.warning.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          'Refinanciado ${formatMoney(refinanciacion.valorAnterior)} a '
          '${formatMoney(refinanciacion.valorNuevo)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: CobroAppTheme.warning,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class EtiquetaCreditoModificado extends StatelessWidget {
  const EtiquetaCreditoModificado({super.key, required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CobroAppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CobroAppTheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          'Modificado ${formatDateTimeLabel(fecha)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: CobroAppTheme.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class BarraSaldo extends StatelessWidget {
  const BarraSaldo({super.key, required this.abonado, required this.total});

  final double abonado;
  final double total;

  @override
  Widget build(BuildContext context) {
    final double progreso =
        total <= 0 ? 0 : (abonado / total).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: progreso,
            backgroundColor: context.clay.progressBackground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatMoney(abonado)} abonado de ${formatMoney(total)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.clay.subtleText,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.estado});

  final EstadoCobro estado;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: estado.color.withValues(alpha: 0.1),
      borderColor: estado.color.withValues(alpha: 0.25),
      elevated: false,
      child: Text(
        estado.etiqueta,
        style: TextStyle(
          color: estado.color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class DatoResumen extends StatelessWidget {
  const DatoResumen({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.clay.subtleText,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

