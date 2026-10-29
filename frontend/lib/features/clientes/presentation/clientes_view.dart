export 'widgets/cliente_detalle_sheet.dart';
export 'widgets/cliente_item.dart';

import 'package:flutter/material.dart';

import '../../../../core/ui/page_layout.dart';
import '../../../../data/models/models.dart';
import 'widgets/cliente_detalle_sheet.dart';
import 'widgets/cliente_item.dart';

class ClientesView extends StatelessWidget {
  const ClientesView({
    super.key,
    required this.clientes,
    required this.cargando,
    required this.sinClientesRegistrados,
    required this.esAdministrador,
    this.puedeModificar = false,
    this.puedeEliminar = false,
    required this.buscarController,
    required this.onRefresh,
    required this.onCrearCliente,
    required this.onModificarCliente,
    required this.onEliminarCliente,
    this.onVerDetalleCliente,
    this.mostrarMensaje,
    this.error,
    this.guardando = false,
  });

  final List<Cliente> clientes;
  final bool cargando;
  final bool sinClientesRegistrados;
  final bool esAdministrador;
  final bool puedeModificar;
  final bool puedeEliminar;
  final TextEditingController buscarController;
  final Future<void> Function() onRefresh;
  final VoidCallback onCrearCliente;
  final ValueChanged<Cliente> onModificarCliente;
  final ValueChanged<Cliente> onEliminarCliente;
  final ValueChanged<Cliente>? onVerDetalleCliente;
  final void Function(String)? mostrarMensaje;
  final String? error;
  final bool guardando;

  void _abrirFichaDetalle(BuildContext context, Cliente cliente) {
    if (onVerDetalleCliente != null) {
      onVerDetalleCliente!(cliente);
      return;
    }

    mostrarClienteDetalleSheet(
      context: context,
      cliente: cliente,
      esAdministrador: esAdministrador,
      puedeModificar: puedeModificar,
      puedeEliminar: puedeEliminar,
      onModificar: () => onModificarCliente(cliente),
      onEliminar: () => onEliminarCliente(cliente),
      mostrarMensaje: mostrarMensaje,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Clientes',
      error: error,
      onRefresh: onRefresh,
      acciones: <Widget>[
        FilledButton.icon(
          onPressed: guardando || cargando ? null : onCrearCliente,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Cliente'),
        ),
      ],
      children: <Widget>[
        if (cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (sinClientesRegistrados)
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
                  puedeEliminar: puedeEliminar,
                  onTap: () => _abrirFichaDetalle(context, cliente),
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
