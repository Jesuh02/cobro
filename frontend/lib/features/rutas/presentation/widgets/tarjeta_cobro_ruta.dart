import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/chips_indicadores.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

/// Tarjeta compacta para la lista de cobros en ruta.
///
/// Presenta la información esencial del cobro en una sola vista escaneable:
/// - Cliente, Cédula y Ruta con chip de estado.
/// - 4 métricas clave en una sola fila (Cuota destacada, Saldo, Cuotas restantes y Próxima).
/// - Barra de progreso sutil de 3.5px.
/// - Botón principal 'Registrar pago' optimizado para el pulgar.
class TarjetaCobroRuta extends StatelessWidget {
  const TarjetaCobroRuta({
    super.key,
    required this.cobro,
    required this.pagoEnProceso,
    required this.pagoAplicadoInstantaneo,
    this.onRegistrarPago,
    this.onGuardarUbicacion,
    this.guardandoUbicacion = false,
  });

  final CobroRuta cobro;
  final bool pagoEnProceso;
  final bool pagoAplicadoInstantaneo;
  final VoidCallback? onRegistrarPago;
  final VoidCallback? onGuardarUbicacion;
  final bool guardandoUbicacion;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final double progreso = cobro.valorTotal <= 0
        ? 0.0
        : (cobro.totalAbonado / cobro.valorTotal).clamp(0.0, 1.0);

    final String cedula = (cobro.cedula ?? '').trim();
    final String negocio = (cobro.negocio ?? '').trim();
    final String ruta = cobro.ruta.trim();

    final String infoCliente = <String>[
      if (cedula.isNotEmpty) 'CC $cedula',
      if (negocio.isNotEmpty) negocio,
    ].join(' · ');

    final bool cobroCompletado = cobro.saldo <= 0.009;
    final bool deshabilitado =
        pagoEnProceso || pagoAplicadoInstantaneo || cobroCompletado;

    return ClaySurface(
      radius: ClayRadius.surface,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Fila 1: Cliente, Subtítulo y Estado
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cobro.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 2),
                    if (infoCliente.isNotEmpty) ...<Widget>[
                      Text(
                        infoCliente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: clay.subtleText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 1),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.alt_route_rounded,
                          size: 13,
                          color: clay.subtleText.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            ruta.isEmpty ? 'Sin ruta' : ruta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: clay.subtleText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              EstadoChip(estado: cobro.estadoCobro),
            ],
          ),
          const SizedBox(height: 10),

          // Fila 2: 4 Métricas Clave en una sola fila
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _MetricaRuta(
                etiqueta: 'Cuota',
                valor: formatMoney(cobro.valorCuota),
                destacado: true,
              ),
              _MetricaRuta(
                etiqueta: 'Saldo',
                valor: formatMoney(cobro.saldo),
              ),
              _MetricaRuta(
                etiqueta: 'Restantes',
                valor: '${cobro.cuotasRestantes} / ${cobro.numeroCuotas}',
              ),
              _MetricaRuta(
                etiqueta: 'Próxima',
                valor: formatDateLabel(cobro.proximaFechaPago),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fila 3: Barra de progreso delgada (3.5px)
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
          const SizedBox(height: 10),

          // Fila 4: Pie con progreso textual y botón principal 'Registrar pago'
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${formatMoney(cobro.totalAbonado)} abonado de ${formatMoney(cobro.valorTotal)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: clay.subtleText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: deshabilitado ? null : onRegistrarPago,
                icon: pagoEnProceso
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : pagoAplicadoInstantaneo
                        ? const Icon(Icons.check_circle_rounded, size: 16)
                        : const Icon(Icons.payments_rounded, size: 16),
                label: Text(
                  pagoEnProceso
                      ? 'Aplicando'
                      : pagoAplicadoInstantaneo
                          ? 'Aplicado'
                          : cobroCompletado
                              ? 'Pagado'
                              : 'Registrar pago',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ClayRadius.control),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricaRuta extends StatelessWidget {
  const _MetricaRuta({
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
            fontSize: destacado ? 13.5 : 12,
            fontWeight: destacado ? FontWeight.w900 : FontWeight.w700,
            color: destacado
                ? CobroAppTheme.primary
                : clay.text.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
