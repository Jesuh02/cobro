export 'widgets/papelera_detalle_sheet.dart';
export 'widgets/papelera_item.dart';

import 'package:flutter/material.dart';

import '../../../core/ui/page_layout.dart';
import '../../../data/models/models.dart';
import 'widgets/papelera_detalle_sheet.dart';
import 'widgets/papelera_item.dart';

class PapeleraView extends StatelessWidget {
  const PapeleraView({
    super.key,
    required this.buscarController,
    required this.items,
    required this.cargando,
    required this.onRefresh,
    required this.onRestaurar,
    required this.onEliminarDefinitivo,
    this.onVerDetalle,
    this.mostrarMensaje,
    this.esAdministrador = true,
    this.error,
  });

  final TextEditingController buscarController;
  final List<PapeleraItem> items;
  final bool cargando;
  final Future<void> Function() onRefresh;
  final ValueChanged<PapeleraItem> onRestaurar;
  final ValueChanged<PapeleraItem> onEliminarDefinitivo;
  final ValueChanged<PapeleraItem>? onVerDetalle;
  final void Function(String)? mostrarMensaje;
  final bool esAdministrador;
  final String? error;

  void _abrirFichaDetalle(BuildContext context, PapeleraItem item) {
    if (onVerDetalle != null) {
      onVerDetalle!(item);
      return;
    }

    mostrarPapeleraDetalleSheet(
      context: context,
      item: item,
      esAdministrador: esAdministrador,
      onRestaurar: () => onRestaurar(item),
      onEliminarDefinitivo: () => onEliminarDefinitivo(item),
      mostrarMensaje: mostrarMensaje,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Papelera',
      subtitulo: esAdministrador
          ? 'Historial de clientes y créditos suspendidos. Solo administradores pueden purgar definitivamente.'
          : 'Historial de clientes y créditos que has enviado a la papelera. Puedes restaurarlos en cualquier momento.',
      error: error,
      onRefresh: onRefresh,
      children: <Widget>[
        TextField(
          controller: buscarController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Buscar en papelera por cliente, cédula, ruta o usuario',
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty && !cargando)
          const EstadoVacio(
            icono: Icons.auto_delete_outlined,
            titulo: 'Papelera vacía',
            mensaje:
                'No hay clientes ni créditos en la papelera de reciclaje.',
          )
        else
          ...items.map(
            (PapeleraItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PapeleraItemCard(
                item: item,
                onRestaurar: () => onRestaurar(item),
                onEliminarDefinitivo: () => onEliminarDefinitivo(item),
                esAdministrador: esAdministrador,
                onTap: () => _abrirFichaDetalle(context, item),
              ),
            ),
          ),
      ],
    );
  }
}
