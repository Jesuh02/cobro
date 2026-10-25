import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/chips_indicadores.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

enum AccionCredito {
  modificar,
  refinanciar,
  cuota,
  eliminar,
}

/// Tarjeta limpia y compacta para listas de créditos.
///
/// Muestra métricas clave en una sola fila (Saldo, Cuota, Progreso) y
/// barra de abono delgada. Al tocar la tarjeta despliega la ficha modal
/// de detalle completa con las acciones pertinentes.
class TarjetaCreditoRegistro extends StatelessWidget {
  const TarjetaCreditoRegistro({
    super.key,
    required this.credito,
    required this.puedeModificar,
    required this.puedeEliminar,
    required this.onModificar,
    required this.onEliminar,
    required this.onRefinanciar,
    this.onTap,
  });

  final CreditoRegistro credito;
  final bool puedeModificar;
  final bool puedeEliminar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;
  final VoidCallback? onRefinanciar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final double progreso = credito.valorTotal <= 0
        ? 0
        : (credito.totalAbonado / credito.valorTotal).clamp(0.0, 1.0).toDouble();

    final String subtitulo = <String>[
      if ((credito.cedula ?? '').isNotEmpty) 'CC ${credito.cedula!}',
      if ((credito.negocio ?? '').isNotEmpty) credito.negocio!,
      credito.ruta,
    ].join(' · ');

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Fila 1: Cliente, Subtítulo (CC · Ruta), Estado y Chevron
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      credito.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: clay.subtleText,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              EstadoCreditoChip(credito: credito),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: clay.subtleText.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Fila 2: 3 Métricas Financieras Principales
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _MetricaCard(
                etiqueta: 'Saldo',
                valor: formatMoney(credito.saldo),
                destacado: true,
              ),
              _MetricaCard(
                etiqueta: 'Cuota',
                valor: formatMoney(credito.valorCuota),
              ),
              _MetricaCard(
                etiqueta: 'Cuotas',
                valor: '${credito.cuotasRestantes} / ${credito.numeroCuotas}',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fila 3: Barra de progreso sutil y delgada (3.5px)
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 3.5,
              value: progreso,
              backgroundColor: clay.progressBackground,
              valueColor: AlwaysStoppedAnimation<Color>(
                progreso >= 1.0 ? CobroAppTheme.success : CobroAppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricaCard extends StatelessWidget {
  const _MetricaCard({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: clay.subtleText,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          valor,
          style: TextStyle(
            fontSize: destacado ? 14 : 12.5,
            fontWeight: destacado ? FontWeight.w900 : FontWeight.w700,
            color: destacado
                ? (creditoColor(clay))
                : (clay.text.withValues(alpha: 0.9)),
          ),
        ),
      ],
    );
  }

  Color creditoColor(ClayTokens clay) {
    return clay.text;
  }
}
