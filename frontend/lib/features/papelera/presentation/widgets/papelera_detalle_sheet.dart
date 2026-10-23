import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

/// Despliega la ficha de detalle de un elemento en papelera en un
/// Modal Bottom Sheet flotante (Island Sheet) adaptado ergonómicamente al pulgar.
Future<void> mostrarPapeleraDetalleSheet({
  required BuildContext context,
  required PapeleraItem item,
  required bool esAdministrador,
  required VoidCallback onRestaurar,
  required VoidCallback onEliminarDefinitivo,
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
      return PapeleraDetalleSheet(
        item: item,
        esAdministrador: esAdministrador,
        onRestaurar: () {
          Navigator.of(sheetContext).pop();
          onRestaurar();
        },
        onEliminarDefinitivo: () {
          Navigator.of(sheetContext).pop();
          onEliminarDefinitivo();
        },
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

class PapeleraDetalleSheet extends StatelessWidget {
  const PapeleraDetalleSheet({
    super.key,
    required this.item,
    required this.esAdministrador,
    required this.onRestaurar,
    required this.onEliminarDefinitivo,
    required this.onCopiarDato,
  });

  final PapeleraItem item;
  final bool esAdministrador;
  final VoidCallback onRestaurar;
  final VoidCallback onEliminarDefinitivo;
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
                          _HeaderPapelera(item: item),
                          const SizedBox(height: 12),
                          _SeccionCliente(
                            cliente: item.cliente,
                            onCopiar: onCopiarDato,
                          ),
                          if (item.credito != null) ...<Widget>[
                            const SizedBox(height: 8),
                            _SeccionCredito(
                              credito: item.credito!,
                              tipoItem: item.tipo,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _SeccionAuditoria(
                            item: item,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  _FooterAcciones(
                    esAdministrador: esAdministrador,
                    onRestaurar: onRestaurar,
                    onEliminarDefinitivo: onEliminarDefinitivo,
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

class _HeaderPapelera extends StatelessWidget {
  const _HeaderPapelera({required this.item});

  final PapeleraItem item;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool esCredito = item.tipo == 'CREDITO';
    final Color colorTipo =
        esCredito ? Colors.orange.shade800 : Colors.redAccent.shade700;
    final Color colorFondo =
        esCredito ? Colors.orange.shade50 : Colors.red.shade50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorFondo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ClayRadius.control),
        border: Border.all(
          color: colorTipo.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: colorTipo.withValues(alpha: 0.15),
                child: Icon(
                  esCredito
                      ? Icons.receipt_long_rounded
                      : Icons.delete_outline_rounded,
                  color: colorTipo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.cliente.nombreCompleto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: clay.text,
                          ),
                    ),
                    if ((item.cliente.negocio ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        item.cliente.negocio!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: CobroAppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorTipo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ClayRadius.small),
                  border: Border.all(
                    color: colorTipo.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  esCredito ? 'Crédito' : 'Cliente',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorTipo,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                ),
              ),
            ],
          ),
          if ((item.motivo ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: clay.surfaceHigh,
                borderRadius: BorderRadius.circular(ClayRadius.small),
                border: Border.all(color: clay.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: clay.subtleText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Motivo: ${item.motivo!.trim()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: clay.subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeccionCliente extends StatelessWidget {
  const _SeccionCliente({
    required this.cliente,
    required this.onCopiar,
  });

  final PapeleraCliente cliente;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    final String documento = cliente.documento.trim();
    final String telefono = (cliente.telefono ?? '').trim();
    final String direccion = (cliente.direccion ?? '').trim();

    return _InfoCard(
      titulo: 'Datos del cliente',
      icono: Icons.person_outline_rounded,
      children: <Widget>[
        _FilaDato(
          etiqueta: 'Documento / Cédula',
          valor: documento.isEmpty ? 'No registrado' : 'CC $documento',
          valorCopiable: documento.isEmpty ? null : documento,
          icono: Icons.badge_outlined,
          onCopiar: onCopiar,
        ),
        if (telefono.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          _FilaDato(
            etiqueta: 'Teléfono',
            valor: telefono,
            valorCopiable: telefono,
            icono: Icons.phone_outlined,
            onCopiar: onCopiar,
          ),
        ],
        if (direccion.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          _FilaDato(
            etiqueta: 'Dirección física',
            valor: direccion,
            valorCopiable: direccion,
            multiline: true,
            icono: Icons.place_outlined,
            onCopiar: onCopiar,
          ),
        ],
      ],
    );
  }
}

class _SeccionCredito extends StatelessWidget {
  const _SeccionCredito({
    required this.credito,
    required this.tipoItem,
  });

  final PapeleraCredito credito;
  final String tipoItem;

  @override
  Widget build(BuildContext context) {
    final String titulo = tipoItem == 'CREDITO'
        ? 'Crédito eliminado'
        : 'Crédito activo suspendido en cadena';

    return _InfoCard(
      titulo: titulo,
      icono: Icons.receipt_long_outlined,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _DatoCompacto(
                etiqueta: 'Monto total',
                valor: formatMoney(credito.total),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DatoCompacto(
                etiqueta: 'Saldo pendiente',
                valor: formatMoney(credito.saldoPendiente),
                colorValor: Colors.amber.shade900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: _DatoCompacto(
                etiqueta: 'Total a pagar',
                valor: formatMoney(credito.totalPagar),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DatoCompacto(
                etiqueta: 'Frecuencia',
                valor: credito.frecuencia,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DatoCompacto extends StatelessWidget {
  const _DatoCompacto({
    required this.etiqueta,
    required this.valor,
    this.colorValor,
  });

  final String etiqueta;
  final String valor;
  final Color? colorValor;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        Text(
          valor,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorValor ?? clay.text,
              ),
        ),
      ],
    );
  }
}

class _SeccionAuditoria extends StatelessWidget {
  const _SeccionAuditoria({required this.item});

  final PapeleraItem item;

  @override
  Widget build(BuildContext context) {
    final String fecha = formatDateTimeLabel(item.fecha);
    final String usuario = item.eliminadoPor.nombreCompleto.trim();
    final String ruta = item.ruta?.nombre.trim() ?? 'Sin ruta asignada';

    return _InfoCard(
      titulo: 'Registro de eliminación',
      icono: Icons.history_rounded,
      children: <Widget>[
        _FilaDato(
          etiqueta: 'Fecha de eliminación',
          valor: fecha,
          icono: Icons.calendar_today_outlined,
          onCopiar: (_, __) {},
        ),
        const SizedBox(height: 6),
        _FilaDato(
          etiqueta: 'Eliminado por',
          valor: usuario,
          icono: Icons.person_outline_rounded,
          onCopiar: (_, __) {},
        ),
        const SizedBox(height: 6),
        _FilaDato(
          etiqueta: 'Ruta original',
          valor: ruta,
          icono: Icons.alt_route_rounded,
          onCopiar: (_, __) {},
        ),
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
    required this.esAdministrador,
    required this.onRestaurar,
    required this.onEliminarDefinitivo,
    required this.onCerrar,
  });

  final bool esAdministrador;
  final VoidCallback onRestaurar;
  final VoidCallback onEliminarDefinitivo;
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
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onRestaurar,
              icon: const Icon(Icons.restore_rounded, size: 17),
              label: const Text('Restaurar'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ClayRadius.control),
                ),
              ),
            ),
          ),
          if (esAdministrador) ...<Widget>[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onEliminarDefinitivo,
              icon: const Icon(Icons.delete_forever_rounded, size: 19),
              color: Theme.of(context).colorScheme.error,
              tooltip: 'Purgar definitivamente',
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
    );
  }
}
