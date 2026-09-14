export 'widgets/cliente_item.dart';

import 'package:flutter/material.dart';

import '../../../../core/ui/page_layout.dart';
import '../../../../data/models/models.dart';
import 'widgets/cliente_item.dart';

class ClientesView extends StatelessWidget {
  const ClientesView({
    super.key,
    required this.clientes,
    required this.sinClientesRegistrados,
    required this.esAdministrador,
    this.puedeModificar = false,
    required this.buscarController,
    required this.onRefresh,
    required this.onCrearCliente,
    required this.onModificarCliente,
    required this.onEliminarCliente,
    this.error,
    this.guardando = false,
  });

  final List<Cliente> clientes;
  final bool sinClientesRegistrados;
  final bool esAdministrador;
  final bool puedeModificar;
  final TextEditingController buscarController;
  final Future<void> Function() onRefresh;
  final VoidCallback onCrearCliente;
  final ValueChanged<Cliente> onModificarCliente;
  final ValueChanged<Cliente> onEliminarCliente;
  final String? error;
  final bool guardando;

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Clientes',
      error: error,
      onRefresh: onRefresh,
      acciones: <Widget>[
        FilledButton.icon(
          onPressed: guardando ? null : onCrearCliente,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Cliente'),
        ),
      ],
      children: <Widget>[
        if (sinClientesRegistrados)
          const EstadoVacio(
            icono: Icons.groups_outlined,
            titulo: 'Sin clientes',
            mensaje: 'No hay clientes registrados.',
          )
        else ...<Widget>[
          TextField(
            controller: buscarController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Buscar cliente, cedula o negocio',
            ),
          ),
          const SizedBox(height: 14),
          if (clientes.isEmpty)
            const EstadoVacio(
              icono: Icons.person_search_rounded,
              titulo: 'Sin resultados',
              mensaje: 'No hay clientes para el filtro actual.',
            )
          else
            ...clientes.map(
              (Cliente cliente) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClienteItem(
                  cliente: cliente,
                  esAdministrador: esAdministrador,
                  puedeModificar: puedeModificar,
                  onModificar: () => onModificarCliente(cliente),
                  onEliminar: () => onEliminarCliente(cliente),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
