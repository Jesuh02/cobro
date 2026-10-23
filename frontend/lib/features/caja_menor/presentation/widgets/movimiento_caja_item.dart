import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

class MovimientoCajaItem extends StatelessWidget {
  const MovimientoCajaItem({
    super.key,
    required this.movimiento,
    required this.puedeModificar,
    this.onTap,
    required this.onModificar,
  });

  final MovimientoCaja movimiento;
  final bool puedeModificar;
  final VoidCallback? onTap;
  final VoidCallback onModificar;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _MovimientoIcono(movimiento: movimiento),
          const SizedBox(width: 12),
          Expanded(child: _MovimientoInfo(movimiento: movimiento)),
          const SizedBox(width: 8),
          _MovimientoMonto(
            movimiento: movimiento,
            puedeModificar: puedeModificar,
            onModificar: onModificar,
          ),
        ],
      ),
    );
  }
}

class _MovimientoIcono extends StatelessWidget {
  const _MovimientoIcono({required this.movimiento});

  final MovimientoCaja movimiento;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool salida = movimiento.tipoMovimiento.naturaleza == 'S';
    final bool auditoria = movimiento.esAuditoria;
    final Color color = auditoria
        ? clay.subtleText
        : salida
            ? CobroAppTheme.danger
            : CobroAppTheme.success;

    final IconData icono = auditoria
        ? Icons.history_rounded
        : movimiento.esPago
            ? Icons.payments_rounded
            : salida
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded;

    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icono, color: color, size: 20),
    );
  }
}

class _MovimientoInfo extends StatelessWidget {
  const _MovimientoInfo({required this.movimiento});

  final MovimientoCaja movimiento;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final String? cliente = movimiento.cliente?.trim().isEmpty ?? true
        ? null
        : movimiento.cliente!.trim();
    final String? identificacion =
        movimiento.clienteIdentificacion?.trim().isEmpty ?? true
            ? null
            : movimiento.clienteIdentificacion!.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          movimiento.motivoVisible,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: clay.text,
              ),
        ),
        if (cliente != null) ...<Widget>[
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Icon(
                Icons.person_outline_rounded,
                size: 13,
                color: clay.subtleText,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  identificacion != null ? '$cliente (CC $identificacion)' : cliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: clay.subtleText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 2),
        Row(
          children: <Widget>[
            Icon(
              Icons.calendar_today_outlined,
              size: 12,
              color: clay.subtleText,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                formatDateLabel(movimiento.fechaMovimiento),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: clay.subtleText,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '·',
                style: TextStyle(
                  color: clay.subtleText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                movimiento.cajaMenor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: clay.subtleText,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MovimientoMonto extends StatelessWidget {
  const _MovimientoMonto({
    required this.movimiento,
    required this.puedeModificar,
    required this.onModificar,
  });

  final MovimientoCaja movimiento;
  final bool puedeModificar;
  final VoidCallback onModificar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool salida = movimiento.tipoMovimiento.naturaleza == 'S';
    final bool auditoria = movimiento.esAuditoria;
    final Color color = auditoria
        ? clay.subtleText
        : salida
            ? CobroAppTheme.danger
            : CobroAppTheme.success;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          formatMoney(movimiento.montoConNaturaleza),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
        if (puedeModificar && movimiento.esEditablePorAdmin) ...<Widget>[
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              tooltip: 'Modificar',
              iconSize: 18,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.edit_outlined),
              onPressed: onModificar,
            ),
          ),
        ],
      ],
    );
  }
}
