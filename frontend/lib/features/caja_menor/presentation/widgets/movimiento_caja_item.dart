import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

enum AccionMovimientoCaja {
  modificar,
  eliminar,
}

class MovimientoCajaItem extends StatelessWidget {
  const MovimientoCajaItem({
    super.key,
    required this.movimiento,
    required this.puedeModificar,
    required this.puedeEliminar,
    required this.onModificar,
    required this.onEliminar,
  });

  final MovimientoCaja movimiento;
  final bool puedeModificar;
  final bool puedeEliminar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final bool salida = movimiento.tipoMovimiento.naturaleza == 'S';
    final bool auditoria = movimiento.esAuditoria;
    final Color color = auditoria
        ? context.clay.subtleText
        : salida
            ? CobroAppTheme.danger
            : CobroAppTheme.success;
    final String? cliente = movimiento.cliente?.trim().isEmpty ?? true
        ? null
        : movimiento.cliente!.trim();
    final String? identificacion =
        movimiento.clienteIdentificacion?.trim().isEmpty ?? true
            ? null
            : movimiento.clienteIdentificacion!.trim();
    final String detalle = <String>[
      if (cliente != null) 'Cliente: $cliente',
      if (identificacion != null) 'Identificacion: $identificacion',
      movimiento.cajaMenor,
      movimiento.tipoMovimiento.nombre,
      formatDateLabel(movimiento.fechaMovimiento),
      if (movimiento.usuario != null) movimiento.usuario!.nombreCompleto,
    ].join(' - ');

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          ClayIcon(
            icon: auditoria
                ? Icons.history_rounded
                : movimiento.esPago
                    ? Icons.payments_rounded
                    : salida
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  movimiento.motivoVisible,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  detalle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatMoney(movimiento.montoConNaturaleza),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          if ((puedeModificar || puedeEliminar) &&
              movimiento.esEditablePorAdmin) ...<Widget>[
            const SizedBox(width: 4),
            PopupMenuButton<AccionMovimientoCaja>(
              tooltip: 'Acciones',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (AccionMovimientoCaja accion) {
                switch (accion) {
                  case AccionMovimientoCaja.modificar:
                    onModificar();
                  case AccionMovimientoCaja.eliminar:
                    onEliminar();
                }
              },
              itemBuilder: (BuildContext context) {
                return <PopupMenuEntry<AccionMovimientoCaja>>[
                  if (puedeModificar)
                    const PopupMenuItem<AccionMovimientoCaja>(
                      value: AccionMovimientoCaja.modificar,
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 12),
                          Text('Modificar'),
                        ],
                      ),
                    ),
                  if (puedeEliminar)
                    const PopupMenuItem<AccionMovimientoCaja>(
                      value: AccionMovimientoCaja.eliminar,
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
    );
  }
}
