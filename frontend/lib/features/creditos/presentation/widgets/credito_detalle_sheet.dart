import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/chips_indicadores.dart';
import '../../../../core/ui/clay.dart';
import '../../../../core/ui/island_modal_sheet.dart';
import '../../../../data/models/models.dart';

/// Despliega la ficha de detalle de un crédito en un Modal Bottom Sheet flotante
/// (Island Sheet) adaptado a la zona ergonómica del pulgar.
Future<void> mostrarCreditoDetalleSheet({
  required BuildContext context,
  required CreditoRegistro credito,
  required bool puedeModificar,
  required bool puedeEliminar,
  required bool puedeRefinanciar,
  required VoidCallback onModificar,
  required VoidCallback onEliminar,
  VoidCallback? onRefinanciar,
  void Function(String)? mostrarMensaje,
}) async {
  await mostrarIslandModalBottomSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return CreditoDetalleSheet(
        credito: credito,
        puedeModificar: puedeModificar,
        puedeEliminar: puedeEliminar,
        puedeRefinanciar: puedeRefinanciar,
        onModificar: () {
          Navigator.of(sheetContext).pop();
          onModificar();
        },
        onEliminar: () {
          Navigator.of(sheetContext).pop();
          onEliminar();
        },
        onRefinanciar: onRefinanciar != null
            ? () {
                Navigator.of(sheetContext).pop();
                onRefinanciar();
              }
            : null,
        onCopiarDato: (String etiqueta, String valor) {
          copiarDatoAlPortapapeles(
            context: sheetContext,
            etiqueta: etiqueta,
            valor: valor,
            mostrarMensaje: mostrarMensaje,
          );
        },
      );
    },
  );
}

class CreditoDetalleSheet extends StatelessWidget {
  const CreditoDetalleSheet({
    super.key,
    required this.credito,
    required this.puedeModificar,
    required this.puedeEliminar,
    required this.puedeRefinanciar,
    required this.onModificar,
    required this.onEliminar,
    this.onRefinanciar,
    required this.onCopiarDato,
  });

  final CreditoRegistro credito;
  final bool puedeModificar;
  final bool puedeEliminar;
  final bool puedeRefinanciar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;
  final VoidCallback? onRefinanciar;
  final void Function(String etiqueta, String valor) onCopiarDato;

  @override
  Widget build(BuildContext context) {
    final CreditoRefinanciacion? refinanciacion = credito.refinanciacion;
    final DateTime? fechaModificacion = credito.fechaModificacionVisible;

    return IslandModalSheet(
      maxHeightFactor: 0.82,
      footer: _FooterAccionesCredito(
        puedeModificar: puedeModificar,
        puedeEliminar: puedeEliminar,
        puedeRefinanciar: puedeRefinanciar && onRefinanciar != null,
        onModificar: onModificar,
        onEliminar: onEliminar,
        onRefinanciar: onRefinanciar,
        onCerrar: () => Navigator.of(context).pop(),
      ),
      children: <Widget>[
        _HeaderCredito(credito: credito, onCopiar: onCopiarDato),
        const SizedBox(height: 12),
        _SeccionBalance(credito: credito, onCopiar: onCopiarDato),
        const SizedBox(height: 8),
        _SeccionCondiciones(credito: credito, onCopiar: onCopiarDato),
        const SizedBox(height: 8),
        _SeccionFechasTrazabilidad(credito: credito, onCopiar: onCopiarDato),
        if (refinanciacion != null) ...<Widget>[
          const SizedBox(height: 8),
          EtiquetaRefinanciacion(refinanciacion: refinanciacion),
        ],
        if (fechaModificacion != null) ...<Widget>[
          const SizedBox(height: 8),
          EtiquetaCreditoModificado(fecha: fechaModificacion),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HeaderCredito extends StatelessWidget {
  const _HeaderCredito({
    required this.credito,
    required this.onCopiar,
  });

  final CreditoRegistro credito;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final String cedula = (credito.cedula ?? '').trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        CircleAvatar(
          radius: 24,
          backgroundColor: CobroAppTheme.primary.withValues(alpha: 0.14),
          child: Text(
            credito.cliente.isEmpty
                ? '?'
                : credito.cliente.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: CobroAppTheme.primary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                credito.cliente,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: clay.text,
                    ),
              ),
              const SizedBox(height: 2),
              if (cedula.isNotEmpty) ...<Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'CC $cedula',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: clay.subtleText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 13),
                      tooltip: 'Copiar cédula',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(22, 22),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => onCopiar('Cédula', cedula),
                    ),
                  ],
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
                      credito.ruta.isEmpty ? 'Sin ruta' : credito.ruta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: clay.subtleText,
                            fontWeight: FontWeight.w500,
                            fontSize: 11.5,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        EstadoCreditoChip(credito: credito),
      ],
    );
  }
}

class _SeccionBalance extends StatelessWidget {
  const _SeccionBalance({
    required this.credito,
    required this.onCopiar,
  });

  final CreditoRegistro credito;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    return TarjetaSeccionSheet(
      titulo: 'Balance y Recaudo',
      icono: Icons.account_balance_wallet_outlined,
      children: <Widget>[
        BarraSaldo(
          abonado: credito.totalAbonado,
          total: credito.valorTotal,
        ),
        const SizedBox(height: 8),
        FilaDatoSheet(
          etiqueta: 'Saldo pendiente',
          valor: formatMoney(credito.saldo),
          valorCopiable: credito.saldo.toString(),
          colorValor: credito.saldo > 0 ? CobroAppTheme.primary : CobroAppTheme.success,
          icono: Icons.pending_actions_rounded,
          onCopiar: onCopiar,
        ),
        const SizedBox(height: 6),
        FilaDatoSheet(
          etiqueta: 'Total con intereses',
          valor: formatMoney(credito.valorTotal),
          icono: Icons.request_quote_outlined,
          onCopiar: onCopiar,
        ),
      ],
    );
  }
}

class _SeccionCondiciones extends StatelessWidget {
  const _SeccionCondiciones({
    required this.credito,
    required this.onCopiar,
  });

  final CreditoRegistro credito;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    return TarjetaSeccionSheet(
      titulo: 'Condiciones del Crédito',
      icono: Icons.tune_rounded,
      children: <Widget>[
        FilaDatoSheet(
          etiqueta: 'Principal prestado',
          valor: formatMoney(credito.valorPrincipal),
          icono: Icons.payments_outlined,
          onCopiar: onCopiar,
        ),
        const SizedBox(height: 6),
        FilaDatoSheet(
          etiqueta: 'Valor por cuota',
          valor: formatMoney(credito.valorCuota),
          valorCopiable: credito.valorCuota.toString(),
          icono: Icons.calendar_view_week_rounded,
          onCopiar: onCopiar,
        ),
        const SizedBox(height: 6),
        FilaDatoSheet(
          etiqueta: 'Frecuencia de pago',
          valor: credito.frecuenciaPago.nombre,
          icono: Icons.repeat_rounded,
          onCopiar: onCopiar,
        ),
        const SizedBox(height: 6),
        FilaDatoSheet(
          etiqueta: 'Cuotas pendientes / pactadas',
          valor: '${credito.cuotasRestantes} restantes de ${credito.numeroCuotas}',
          icono: Icons.pie_chart_outline_rounded,
          onCopiar: onCopiar,
        ),
        const SizedBox(height: 6),
        FilaDatoSheet(
          etiqueta: 'Interés y Plazo',
          valor: '${credito.porcentajeInteres.toStringAsFixed(1)}% · ${credito.plazoDias} días',
          icono: Icons.percent_rounded,
          onCopiar: onCopiar,
        ),
      ],
    );
  }
}

class _SeccionFechasTrazabilidad extends StatelessWidget {
  const _SeccionFechasTrazabilidad({
    required this.credito,
    required this.onCopiar,
  });

  final CreditoRegistro credito;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    final String cajaMenor = (credito.cajaMenor ?? '').trim();
    final String negocio = (credito.negocio ?? '').trim();

    return TarjetaSeccionSheet(
      titulo: 'Fechas y Trazabilidad',
      icono: Icons.calendar_today_outlined,
      children: <Widget>[
        FilaDatoSheet(
          etiqueta: 'Fecha de inicio',
          valor: formatDateLabel(credito.fechaInicio),
          icono: Icons.play_arrow_outlined,
          onCopiar: onCopiar,
        ),
        const SizedBox(height: 6),
        FilaDatoSheet(
          etiqueta: 'Fecha máxima de cobro',
          valor: formatDateLabel(credito.fechaMaxima),
          icono: Icons.event_available_outlined,
          onCopiar: onCopiar,
        ),
        if (cajaMenor.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          FilaDatoSheet(
            etiqueta: 'Caja menor de desembolso',
            valor: cajaMenor,
            icono: Icons.account_balance_outlined,
            onCopiar: onCopiar,
          ),
        ],
        if (negocio.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          FilaDatoSheet(
            etiqueta: 'Negocio o actividad',
            valor: negocio,
            icono: Icons.storefront_outlined,
            onCopiar: onCopiar,
          ),
        ],
      ],
    );
  }
}

class _FooterAccionesCredito extends StatelessWidget {
  const _FooterAccionesCredito({
    required this.puedeModificar,
    required this.puedeEliminar,
    required this.puedeRefinanciar,
    required this.onModificar,
    required this.onEliminar,
    this.onRefinanciar,
    required this.onCerrar,
  });

  final bool puedeModificar;
  final bool puedeEliminar;
  final bool puedeRefinanciar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;
  final VoidCallback? onRefinanciar;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool tieneRefinanciar = puedeRefinanciar && onRefinanciar != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: clay.surface,
        border: Border(
          top: BorderSide(color: clay.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (tieneRefinanciar) ...<Widget>[
            FilledButton.icon(
              onPressed: onRefinanciar,
              icon: const Icon(Icons.currency_exchange_rounded, size: 18),
              label: const Text(
                'Refinanciar crédito',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ClayRadius.control),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onCerrar,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ClayRadius.control),
                    ),
                  ),
                  child: const Text(
                    'Cerrar',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (puedeModificar && !tieneRefinanciar) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onModificar,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(
                      'Modificar',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ClayRadius.control),
                      ),
                    ),
                  ),
                ),
              ] else if (puedeModificar && tieneRefinanciar) ...<Widget>[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onModificar,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Modificar crédito',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ClayRadius.control),
                      side: BorderSide(
                        color: clay.border.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
              if (puedeEliminar) ...<Widget>[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onEliminar,
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Eliminar crédito',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ClayRadius.control),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
