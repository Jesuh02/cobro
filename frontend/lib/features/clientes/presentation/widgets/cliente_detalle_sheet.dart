import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

/// Despliega la ficha de detalle de un cliente en un Modal Bottom Sheet
/// flotante (Island Sheet), desacoplado de los bordes físicos de la pantalla
/// para una estética moderna y ergonómica.
Future<void> mostrarClienteDetalleSheet({
  required BuildContext context,
  required Cliente cliente,
  required bool esAdministrador,
  bool puedeModificar = false,
  bool puedeEliminar = false,
  required VoidCallback onModificar,
  required VoidCallback onEliminar,
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
      return ClienteDetalleSheet(
        cliente: cliente,
        esAdministrador: esAdministrador,
        puedeModificar: puedeModificar,
        puedeEliminar: puedeEliminar,
        onModificar: () {
          Navigator.of(sheetContext).pop();
          onModificar();
        },
        onEliminar: () {
          Navigator.of(sheetContext).pop();
          onEliminar();
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

class ClienteDetalleSheet extends StatelessWidget {
  const ClienteDetalleSheet({
    super.key,
    required this.cliente,
    required this.esAdministrador,
    this.puedeModificar = false,
    this.puedeEliminar = false,
    required this.onModificar,
    required this.onEliminar,
    required this.onCopiarDato,
  });

  final Cliente cliente;
  final bool esAdministrador;
  final bool puedeModificar;
  final bool puedeEliminar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;
  final void Function(String etiqueta, String valor) onCopiarDato;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Size screenSize = MediaQuery.sizeOf(context);
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final double systemBottom = MediaQuery.paddingOf(context).bottom;

    // Márgenes flotantes para evitar que el sheet se pegue a los bordes de la pantalla
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
                          _HeaderCliente(cliente: cliente),
                          const SizedBox(height: 12),
                          _SeccionIdentificacion(
                            cliente: cliente,
                            onCopiar: onCopiarDato,
                          ),
                          const SizedBox(height: 8),
                          _SeccionContacto(
                            cliente: cliente,
                            onCopiar: onCopiarDato,
                          ),
                          const SizedBox(height: 8),
                          _SeccionUbicacion(
                            cliente: cliente,
                            onCopiar: onCopiarDato,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  _FooterAcciones(
                    esAdministrador: esAdministrador,
                    puedeModificar: puedeModificar,
                    puedeEliminar: puedeEliminar,
                    onModificar: onModificar,
                    onEliminar: onEliminar,
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

class _HeaderCliente extends StatelessWidget {
  const _HeaderCliente({required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool esActivo = cliente.estadoNombre.trim().toLowerCase() == 'activo';
    final Color estadoColor =
        esActivo ? CobroAppTheme.success : clay.subtleText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        CircleAvatar(
          radius: 24,
          backgroundColor: CobroAppTheme.primary.withValues(alpha: 0.14),
          child: Text(
            cliente.nombreCompleto.isEmpty
                ? '?'
                : cliente.nombreCompleto.substring(0, 1).toUpperCase(),
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
                cliente.nombreCompleto,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: clay.text,
                    ),
              ),
              if ((cliente.nombreComercial ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.storefront_rounded,
                      size: 14,
                      color: clay.subtleText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        cliente.nombreComercial!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: clay.subtleText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: estadoColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(ClayRadius.small),
            border: Border.all(
              color: estadoColor.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            cliente.estadoNombre,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: estadoColor,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _SeccionIdentificacion extends StatelessWidget {
  const _SeccionIdentificacion({
    required this.cliente,
    required this.onCopiar,
  });

  final Cliente cliente;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    final String cedula = (cliente.cedula ?? '').trim();
    return _InfoCard(
      titulo: 'Identificación',
      icono: Icons.badge_outlined,
      children: <Widget>[
        _FilaDato(
          etiqueta: 'Documento / Cédula',
          valor: cedula.isEmpty ? 'No registrada' : 'CC $cedula',
          valorCopiable: cedula.isEmpty ? null : cedula,
          onCopiar: onCopiar,
        ),
      ],
    );
  }
}

class _SeccionContacto extends StatelessWidget {
  const _SeccionContacto({
    required this.cliente,
    required this.onCopiar,
  });

  final Cliente cliente;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    final String telefono = (cliente.telefono ?? '').trim();
    final String correo = (cliente.correo ?? '').trim();

    return _InfoCard(
      titulo: 'Contacto',
      icono: Icons.contact_phone_outlined,
      children: <Widget>[
        _FilaDato(
          etiqueta: 'Teléfono',
          valor: telefono.isEmpty ? 'No registrado' : telefono,
          valorCopiable: telefono.isEmpty ? null : telefono,
          icono: Icons.phone_rounded,
          onCopiar: onCopiar,
        ),
        if (correo.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          _FilaDato(
            etiqueta: 'Correo',
            valor: correo,
            valorCopiable: correo,
            icono: Icons.alternate_email_rounded,
            onCopiar: onCopiar,
          ),
        ],
      ],
    );
  }
}

class _SeccionUbicacion extends StatelessWidget {
  const _SeccionUbicacion({
    required this.cliente,
    required this.onCopiar,
  });

  final Cliente cliente;
  final void Function(String etiqueta, String valor) onCopiar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final String direccion = (cliente.direccion ?? '').trim();
    final bool tieneGps = cliente.tieneUbicacion;

    return _InfoCard(
      titulo: 'Ubicación y Domicilio',
      icono: Icons.place_outlined,
      children: <Widget>[
        _FilaDato(
          etiqueta: 'Dirección física',
          valor: direccion.isEmpty ? 'No registrada' : direccion,
          valorCopiable: direccion.isEmpty ? null : direccion,
          multiline: true,
          onCopiar: onCopiar,
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Icon(
              tieneGps
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
              size: 15,
              color: tieneGps ? CobroAppTheme.primary : clay.subtleText,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tieneGps
                    ? 'Coordenadas: ${cliente.latitude!.toStringAsFixed(5)}, ${cliente.longitude!.toStringAsFixed(5)}'
                    : 'Sin georreferenciación GPS',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tieneGps ? clay.text : clay.subtleText,
                      fontWeight:
                          tieneGps ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
            if (tieneGps)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 15),
                tooltip: 'Copiar coordenadas',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => onCopiar(
                  'Coordenadas',
                  '${cliente.latitude}, ${cliente.longitude}',
                ),
              ),
          ],
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
    required this.puedeModificar,
    required this.puedeEliminar,
    required this.onModificar,
    required this.onEliminar,
    required this.onCerrar,
  });

  final bool esAdministrador;
  final bool puedeModificar;
  final bool puedeEliminar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool permiteEditar = esAdministrador || puedeModificar;
    final bool permiteEliminar = esAdministrador || puedeEliminar;

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
          if (permiteEditar) ...<Widget>[
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
          if (permiteEliminar) ...<Widget>[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onEliminar,
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: Theme.of(context).colorScheme.error,
              tooltip: 'Eliminar cliente',
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
