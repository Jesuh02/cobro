import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

/// Despliega la ficha de detalle de un movimiento de caja menor en un
/// Modal Bottom Sheet flotante (Island Sheet) adaptado a la zona del pulgar.
Future<void> mostrarMovimientoDetalleSheet({
  required BuildContext context,
  required MovimientoCaja movimiento,
  required bool puedeModificar,
  required VoidCallback onModificar,
  VoidCallback? onVerCliente,
  void Function(String)? mostrarMensaje,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (BuildContext sheetContext) {
      return MovimientoDetalleSheet(
        movimiento: movimiento,
        puedeModificar: puedeModificar,
        onModificar: () {
          Navigator.of(sheetContext).pop();
          onModificar();
        },
        onVerCliente: onVerCliente != null
            ? () {
                Navigator.of(sheetContext).pop();
                onVerCliente();
              }
            : null,
        onCopiarDato: (String etiqueta, String valor) {
          Clipboard.setData(ClipboardData(text: valor));
          HapticFeedback.selectionClick();
          final String mensaje = '$etiqueta copiado al portapapeles';
          if (mostrarMensaje != null) {
            mostrarMensaje(mensaje);
          } else {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              SnackBar(
                content: Text(mensaje),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );
    },
  );
}

class MovimientoDetalleSheet extends StatelessWidget {
  const MovimientoDetalleSheet({
    super.key,
    required this.movimiento,
    required this.puedeModificar,
    required this.onModificar,
    this.onVerCliente,
    required this.onCopiarDato,
  });

  final MovimientoCaja movimiento;
  final bool puedeModificar;
  final VoidCallback onModificar;
  final VoidCallback? onVerCliente;
  final void Function(String etiqueta, String valor) onCopiarDato;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Size screenSize = MediaQuery.sizeOf(context);
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final double systemBottom = MediaQuery.paddingOf(context).bottom;

    final double horizontalMargin = screenSize.width < 420 ? 10.0 : 18.0;
    final double bottomMargin = bottomInset > 0
        ? bottomInset + 8.0
        : (systemBottom > 0 ? systemBottom + 6.0 : 12.0);

    final bool tieneCliente =
        (movimiento.cliente?.trim().isNotEmpty ?? false) ||
        (movimiento.clienteIdentificacion?.trim().isNotEmpty ?? false);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalMargin,
          0,
          horizontalMargin,
          bottomMargin,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.78,
              maxWidth: 480,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: clay.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: clay.border.withValues(alpha: 0.65),
                ),
                boxShadow: clay.floatingShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _DragHandle(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _HeaderMovimiento(movimiento: movimiento),
                          const SizedBox(height: 12),
                          _SeccionTransaccion(
                            movimiento: movimiento,
                            onCopiar: onCopiarDato,
                          ),
                          if (tieneCliente) ...<Widget>[
                            const SizedBox(height: 8),
                            _SeccionCliente(
                              movimiento: movimiento,
                              onCopiar: onCopiarDato,
                              onVerCliente: onVerCliente,
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  _FooterAcciones(
                    puedeModificar: puedeModificar && movimiento.esEditablePorAdmin,
                    onModificar: onModificar,
                    onCerrar: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 32,
          height: 3.5,
          decoration: BoxDecoration(
            color: clay.subtleText.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _HeaderMovimiento extends StatelessWidget {
  const _HeaderMovimiento({required this.movimiento});

  final MovimientoCaja movimiento;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool salida = movimiento.tipoMovimiento.naturaleza == 'S';
    final bool auditoria = movimiento.esAuditoria;
    final Color colorNaturaleza = auditoria
        ? clay.subtleText
        : salida
            ? CobroAppTheme.danger
            : CobroAppTheme.success;

    final IconData iconoNaturaleza = auditoria
        ? Icons.history_rounded
        : movimiento.esPago
            ? Icons.payments_rounded
            : salida
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded;

    final String textoNaturaleza = auditoria
        ? 'Auditoría'
        : salida
            ? 'Salida de caja'
            : 'Entrada de caja';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorNaturaleza.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ClayRadius.control),
        border: Border.all(
          color: colorNaturaleza.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: colorNaturaleza.withValues(alpha: 0.15),
                child: Icon(iconoNaturaleza, color: colorNaturaleza, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  textoNaturaleza,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorNaturaleza,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: clay.surfaceHigh,
                  borderRadius: BorderRadius.circular(ClayRadius.small),
                  border: Border.all(
                    color: clay.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  movimiento.tipoMovimiento.nombre,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: clay.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(movimiento.montoConNaturaleza),
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorNaturaleza,
                    letterSpacing: -0.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionTransaccion extends StatelessWidget {
  const _SeccionTransaccion({
    required this.movimiento,
    required this.onCopiar,
  });

  final MovimientoCaja movimiento;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    final String fecha = formatDateTimeLabel(movimiento.fechaMovimiento);
    final String concepto = movimiento.motivoVisible.trim();
    final String? usuario = movimiento.usuario?.nombreCompleto.trim();

    return _InfoCard(
      titulo: 'Detalle de la transacción',
      icono: Icons.receipt_long_outlined,
      children: <Widget>[
        _FilaDato(
          etiqueta: 'Concepto / Motivo',
          valor: concepto.isEmpty ? 'Sin motivo registrado' : concepto,
          multiline: true,
          icono: Icons.description_outlined,
          onCopiar: onCopiar,
        ),
        const SizedBox(height: 6),
        _FilaDato(
          etiqueta: 'Caja menor',
          valor: movimiento.cajaMenor,
          icono: Icons.account_balance_wallet_outlined,
          onCopiar: onCopiar,
        ),
        const SizedBox(height: 6),
        _FilaDato(
          etiqueta: 'Fecha y hora',
          valor: fecha,
          icono: Icons.calendar_today_outlined,
          onCopiar: onCopiar,
        ),
        if (usuario != null && usuario.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          _FilaDato(
            etiqueta: 'Registrado por',
            valor: usuario,
            icono: Icons.person_outline_rounded,
            onCopiar: onCopiar,
          ),
        ],
      ],
    );
  }
}

class _SeccionCliente extends StatelessWidget {
  const _SeccionCliente({
    required this.movimiento,
    required this.onCopiar,
    this.onVerCliente,
  });

  final MovimientoCaja movimiento;
  final void Function(String etiqueta, String valor) onCopiar;
  final VoidCallback? onVerCliente;

  @override
  Widget build(BuildContext context) {
    final String cliente = (movimiento.cliente ?? '').trim();
    final String identificacion =
        (movimiento.clienteIdentificacion ?? '').trim();

    return _InfoCard(
      titulo: 'Cliente vinculado',
      icono: Icons.person_pin_circle_outlined,
      children: <Widget>[
        if (cliente.isNotEmpty)
          _FilaDato(
            etiqueta: 'Nombre del cliente',
            valor: cliente,
            valorCopiable: cliente,
            icono: Icons.person_rounded,
            onCopiar: onCopiar,
          ),
        if (identificacion.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          _FilaDato(
            etiqueta: 'Documento / Cédula',
            valor: 'CC $identificacion',
            valorCopiable: identificacion,
            icono: Icons.badge_outlined,
            onCopiar: onCopiar,
          ),
        ],
        if (onVerCliente != null) ...<Widget>[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onVerCliente,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Ver ficha de cliente'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.titulo,
    required this.icono,
    required this.children,
  });

  final String titulo;
  final IconData icono;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: clay.surfaceLow,
        borderRadius: BorderRadius.circular(ClayRadius.small),
        border: Border.all(color: clay.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icono, size: 15, color: CobroAppTheme.primary),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: clay.text,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({
    required this.etiqueta,
    required this.valor,
    this.valorCopiable,
    this.icono,
    this.multiline = false,
    required this.onCopiar,
  });

  final String etiqueta;
  final String valor;
  final String? valorCopiable;
  final IconData? icono;
  final bool multiline;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;

    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: <Widget>[
        if (icono != null) ...<Widget>[
          Icon(icono, size: 15, color: clay.subtleText),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                etiqueta,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: clay.subtleText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
              ),
              const SizedBox(height: 1),
              SelectableText(
                valor,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: clay.text,
                    ),
              ),
            ],
          ),
        ),
        if (valorCopiable != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 15),
            tooltip: 'Copiar $etiqueta',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
            ),
            onPressed: () => onCopiar(etiqueta, valorCopiable!),
          ),
      ],
    );
  }
}

class _FooterAcciones extends StatelessWidget {
  const _FooterAcciones({
    required this.puedeModificar,
    required this.onModificar,
    required this.onCerrar,
  });

  final bool puedeModificar;
  final VoidCallback onModificar;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: clay.surface,
        border: Border(
          top: BorderSide(color: clay.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
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
              child: const Text('Cerrar'),
            ),
          ),
          if (puedeModificar) ...<Widget>[
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onModificar,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Modificar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ClayRadius.control),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
