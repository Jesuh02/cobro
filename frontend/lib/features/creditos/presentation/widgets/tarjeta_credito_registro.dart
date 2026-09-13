import 'package:flutter/material.dart';

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

class TarjetaCreditoRegistro extends StatelessWidget {
  const TarjetaCreditoRegistro({
    super.key,
    required this.credito,
    required this.puedeModificar,
    required this.puedeEliminar,
    required this.onModificar,
    required this.onEliminar,
    required this.onRefinanciar,
  });

  final CreditoRegistro credito;
  final bool puedeModificar;
  final bool puedeEliminar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;
  final VoidCallback? onRefinanciar;

  @override
  Widget build(BuildContext context) {
    final CreditoRefinanciacion? refinanciacion = credito.refinanciacion;
    final DateTime? fechaModificacion = credito.fechaModificacionVisible;
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
                      credito.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if ((credito.cedula ?? '').isNotEmpty)
                          'CC ${credito.cedula!}',
                        if ((credito.negocio ?? '').isNotEmpty)
                          credito.negocio!,
                        credito.ruta,
                      ].join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.clay.subtleText,
                          ),
                    ),
                  ],
                ),
              ),
              EstadoCreditoChip(credito: credito),
              if (puedeModificar || puedeEliminar) ...<Widget>[
                const SizedBox(width: 4),
                PopupMenuButton<AccionCredito>(
                  tooltip: 'Acciones',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (AccionCredito accion) {
                    switch (accion) {
                      case AccionCredito.modificar:
                        onModificar();
                      case AccionCredito.eliminar:
                        onEliminar();
                      case AccionCredito.refinanciar:
                        onRefinanciar?.call();
                      case AccionCredito.cuota:
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<AccionCredito>>[
                      if (puedeModificar)
                        const PopupMenuItem<AccionCredito>(
                          value: AccionCredito.modificar,
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 12),
                              Text('Modificar'),
                            ],
                          ),
                        ),
                      if (puedeEliminar)
                        const PopupMenuItem<AccionCredito>(
                          value: AccionCredito.eliminar,
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.delete_outline_rounded),
                              SizedBox(width: 12),
                              Text('Eliminar'),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ],
          ),
          if (refinanciacion != null) ...<Widget>[
            const SizedBox(height: 10),
            EtiquetaRefinanciacion(refinanciacion: refinanciacion),
          ],
          if (fechaModificacion != null) ...<Widget>[
            const SizedBox(height: 10),
            EtiquetaCreditoModificado(fecha: fechaModificacion),
          ],
          const SizedBox(height: 14),
          BarraSaldo(
            abonado: credito.totalAbonado,
            total: credito.valorTotal,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              DatoResumen(
                label: 'Principal',
                value: formatMoney(credito.valorPrincipal),
              ),
              DatoResumen(label: 'Saldo', value: formatMoney(credito.saldo)),
              DatoResumen(label: 'Cuota', value: formatMoney(credito.valorCuota)),
              DatoResumen(
                label: 'Cuotas',
                value: '${credito.cuotasRestantes} / ${credito.numeroCuotas}',
              ),
              DatoResumen(
                label: 'Inicio',
                value: formatDateLabel(credito.fechaInicio),
              ),
              DatoResumen(
                label: 'Maxima',
                value: formatDateLabel(credito.fechaMaxima),
              ),
            ],
          ),
          if ((credito.cajaMenor ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Caja menor: ${credito.cajaMenor}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.clay.subtleText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          if (onRefinanciar != null) ...<Widget>[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onRefinanciar,
                icon: const Icon(Icons.currency_exchange_rounded),
                label: const Text('Refinanciar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
