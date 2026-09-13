import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/chips_indicadores.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

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
                    Text(
                      cobro.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if ((cobro.cedula ?? '').isNotEmpty)
                          'CC ${cobro.cedula!}',
                        if ((cobro.negocio ?? '').isNotEmpty) cobro.negocio!,
                        cobro.ruta,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.clay.subtleText,
                          ),
                    ),
                  ],
                ),
              ),
              EstadoChip(estado: cobro.estadoCobro),
            ],
          ),
          const SizedBox(height: 14),
          BarraSaldo(
            abonado: cobro.totalAbonado,
            total: cobro.valorTotal,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              DatoResumen(
                label: 'Saldo',
                value: formatMoney(cobro.saldo),
              ),
              DatoResumen(
                label: 'Cuota',
                value: formatMoney(cobro.valorCuota),
              ),
              DatoResumen(
                label: 'Restantes',
                value: '${cobro.cuotasRestantes} / ${cobro.numeroCuotas}',
              ),
              DatoResumen(
                label: 'Próxima',
                value: formatDateLabel(cobro.proximaFechaPago),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (onGuardarUbicacion != null)
                  OutlinedButton.icon(
                    onPressed: guardandoUbicacion ? null : onGuardarUbicacion,
                    icon: guardandoUbicacion
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(
                      guardandoUbicacion
                          ? 'Guardando casa'
                          : cobro.tieneUbicacion
                              ? 'Actualizar casa'
                              : 'Guardar casa',
                    ),
                  ),
                FilledButton.icon(
                  onPressed: pagoEnProceso ||
                          pagoAplicadoInstantaneo ||
                          cobro.saldo <= 0.009
                      ? null
                      : onRegistrarPago,
                  icon: pagoEnProceso
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : pagoAplicadoInstantaneo
                          ? const Icon(Icons.check_circle_rounded)
                          : const Icon(Icons.payments_rounded),
                  label: Text(
                    pagoEnProceso
                        ? 'Aplicando'
                        : pagoAplicadoInstantaneo
                            ? 'Aplicado'
                            : cobro.saldo <= 0.009
                                ? 'Pagado'
                                : 'Registrar pago',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
