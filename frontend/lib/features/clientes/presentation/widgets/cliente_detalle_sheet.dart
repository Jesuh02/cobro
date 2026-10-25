import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/ui/clay.dart';
import '../../../../core/ui/island_modal_sheet.dart';
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
  await mostrarIslandModalBottomSheet<void>(
    context: context,
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
    return IslandModalSheet(
      maxHeightFactor: 0.78,
      footer: _FooterAcciones(
        esAdministrador: esAdministrador,
        puedeModificar: puedeModificar,
        puedeEliminar: puedeEliminar,
        onModificar: onModificar,
        onEliminar: onEliminar,
        onCerrar: () => Navigator.of(context).pop(),
      ),
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

typedef _InfoCard = TarjetaSeccionSheet;
typedef _FilaDato = FilaDatoSheet;

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
