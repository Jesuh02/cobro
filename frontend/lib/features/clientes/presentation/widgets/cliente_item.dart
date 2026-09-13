import 'package:flutter/material.dart';

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
    required this.onModificar,
    required this.onEliminar,
  });

  final Cliente cliente;
  final bool esAdministrador;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final String contacto = <String>[
      if ((cliente.cedula ?? '').isNotEmpty) 'CC ${cliente.cedula!}',
      if ((cliente.direccion ?? '').isNotEmpty) cliente.direccion!,
      if ((cliente.telefono ?? '').isNotEmpty) cliente.telefono!,
      if ((cliente.correo ?? '').isNotEmpty) cliente.correo!,
    ].join(' · ');

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: CobroAppTheme.primary.withValues(alpha: 0.12),
            child: Text(
              cliente.nombreCompleto.isEmpty
                  ? '?'
                  : cliente.nombreCompleto.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: CobroAppTheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  cliente.nombreCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if ((cliente.nombreComercial ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    cliente.nombreComercial!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.clay.subtleText,
                        ),
                  ),
                ],
                if (contacto.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    contacto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.clay.subtleText,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            cliente.estadoNombre,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: CobroAppTheme.success,
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (esAdministrador) ...<Widget>[
            const SizedBox(width: 4),
            PopupMenuButton<AccionCliente>(
              tooltip: 'Acciones',
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
                return const <PopupMenuEntry<AccionCliente>>[
                  PopupMenuItem<AccionCliente>(
                    value: AccionCliente.modificar,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('Modificar'),
                      ],
                    ),
                  ),
                  PopupMenuItem<AccionCliente>(
                    value: AccionCliente.eliminar,
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
