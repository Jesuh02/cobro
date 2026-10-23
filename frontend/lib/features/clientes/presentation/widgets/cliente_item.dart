import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';

enum AccionCliente {
  modificar,
  eliminar,
}

class ClienteItem extends StatelessWidget {
  const ClienteItem({
    super.key,
    required this.cliente,
    required this.esAdministrador,
    this.puedeModificar = false,
    this.puedeEliminar = false,
    this.onTap,
    required this.onModificar,
    required this.onEliminar,
  });

  final Cliente cliente;
  final bool esAdministrador;
  final bool puedeModificar;
  final bool puedeEliminar;
  final VoidCallback? onTap;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;

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
          _ClienteAvatar(nombreCompleto: cliente.nombreCompleto),
          const SizedBox(width: 12),
          Expanded(child: _ClienteInfo(cliente: cliente)),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _ClienteBadgeEstado(estadoNombre: cliente.estadoNombre),
              if (esAdministrador || puedeModificar || puedeEliminar) ...<Widget>[
                const SizedBox(height: 4),
                _ClientePopupMenu(
                  esAdministrador: esAdministrador,
                  puedeModificar: puedeModificar,
                  puedeEliminar: puedeEliminar,
                  onModificar: onModificar,
                  onEliminar: onEliminar,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ClienteAvatar extends StatelessWidget {
  const _ClienteAvatar({required this.nombreCompleto});

  final String nombreCompleto;

  @override
  Widget build(BuildContext context) {
    final String inicial =
        nombreCompleto.isEmpty ? '?' : nombreCompleto.substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: 22,
      backgroundColor: CobroAppTheme.primary.withValues(alpha: 0.12),
      child: Text(
        inicial,
        style: const TextStyle(
          color: CobroAppTheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
    );
  }
}

class _ClienteInfo extends StatelessWidget {
  const _ClienteInfo({required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final String cedula = (cliente.cedula ?? '').trim();
    final String telefono = (cliente.telefono ?? '').trim();
    final String direccion = (cliente.direccion ?? '').trim();
    final String nombreComercial = (cliente.nombreComercial ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          cliente.nombreCompleto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: clay.text,
              ),
        ),
        if (nombreComercial.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Icon(
                Icons.storefront_rounded,
                size: 13,
                color: clay.subtleText,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  nombreComercial,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: clay.subtleText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 3),
        Row(
          children: <Widget>[
            if (cedula.isNotEmpty) ...<Widget>[
              Icon(
                Icons.badge_outlined,
                size: 13,
                color: clay.subtleText,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  'CC $cedula',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: clay.subtleText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
            if (cedula.isNotEmpty && telefono.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: clay.subtleText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (telefono.isNotEmpty) ...<Widget>[
              Icon(
                Icons.phone_outlined,
                size: 13,
                color: clay.subtleText,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  telefono,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: clay.subtleText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ],
        ),
        if (direccion.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Icon(
                Icons.place_outlined,
                size: 13,
                color: clay.subtleText,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  direccion,
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
      ],
    );
  }
}

class _ClienteBadgeEstado extends StatelessWidget {
  const _ClienteBadgeEstado({required this.estadoNombre});

  final String estadoNombre;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final bool esActivo = estadoNombre.trim().toLowerCase() == 'activo';
    final Color colorEstado = esActivo ? CobroAppTheme.success : clay.subtleText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorEstado.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ClayRadius.small),
        border: Border.all(
          color: colorEstado.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        estadoNombre,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorEstado,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _ClientePopupMenu extends StatelessWidget {
  const _ClientePopupMenu({
    required this.esAdministrador,
    required this.puedeModificar,
    required this.puedeEliminar,
    required this.onModificar,
    required this.onEliminar,
  });

  final bool esAdministrador;
  final bool puedeModificar;
  final bool puedeEliminar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<AccionCliente>(
        tooltip: 'Acciones',
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (AccionCliente accion) {
          switch (accion) {
            case AccionCliente.modificar:
              onModificar();
            case AccionCliente.eliminar:
              onEliminar();
          }
        },
        itemBuilder: (BuildContext context) {
          return <PopupMenuEntry<AccionCliente>>[
            if (esAdministrador || puedeModificar)
              const PopupMenuItem<AccionCliente>(
                value: AccionCliente.modificar,
                child: Row(
                  children: <Widget>[
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Modificar'),
                  ],
                ),
              ),
            if (esAdministrador || puedeEliminar)
              const PopupMenuItem<AccionCliente>(
                value: AccionCliente.eliminar,
                child: Row(
                  children: <Widget>[
                    Icon(Icons.delete_outline_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Eliminar'),
                  ],
                ),
              ),
          ];
        },
      ),
    );
  }
}
