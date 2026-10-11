import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/ui/page_layout.dart';
import '../../../data/models/models.dart';

class PapeleraView extends StatelessWidget {
  const PapeleraView({
    super.key,
    required this.buscarController,
    required this.items,
    required this.cargando,
    required this.onRefresh,
    required this.onRestaurar,
    required this.onEliminarDefinitivo,
    this.esAdministrador = true,
    this.error,
  });

  final TextEditingController buscarController;
  final List<PapeleraItem> items;
  final bool cargando;
  final Future<void> Function() onRefresh;
  final ValueChanged<PapeleraItem> onRestaurar;
  final ValueChanged<PapeleraItem> onEliminarDefinitivo;
  final bool esAdministrador;
  final String? error;

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
              padding: const EdgeInsets.only(bottom: 14),
              child: _PapeleraItemCard(
                item: item,
                onRestaurar: () => onRestaurar(item),
                onEliminarDefinitivo: () => onEliminarDefinitivo(item),
                esAdministrador: esAdministrador,
              ),
            ),
          ),
      ],
    );
  }
}

class _PapeleraItemCard extends StatelessWidget {
  const _PapeleraItemCard({
    required this.item,
    required this.onRestaurar,
    required this.onEliminarDefinitivo,
    required this.esAdministrador,
  });

  final PapeleraItem item;
  final VoidCallback onRestaurar;
  final VoidCallback onEliminarDefinitivo;
  final bool esAdministrador;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String contacto = <String>[
      if (item.cliente.documento.isNotEmpty) 'CC ${item.cliente.documento}',
      if ((item.cliente.direccion ?? '').isNotEmpty) item.cliente.direccion!,
      if ((item.cliente.telefono ?? '').isNotEmpty) item.cliente.telefono!,
    ].join(' · ');

    return ClaySurface(
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.cliente.nombreCompleto,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((item.cliente.negocio ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        item.cliente.negocio!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: CobroAppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (contacto.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        contacto,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Botón Restaurar rápido
              FilledButton.tonalIcon(
                onPressed: onRestaurar,
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Restaurar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Información de crédito suspendido si existe
          if (item.credito != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Crédito activo suspendido en cadena',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Monto: ${formatMoney(item.credito!.total)} · Saldo pendiente: ${formatMoney(item.credito!.saldoPendiente)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Metadatos inferiores
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _ChipMetadato(
                icono: Icons.calendar_today_rounded,
                texto: 'Eliminado: ${formatDateTimeLabel(item.fecha)}',
              ),
              _ChipMetadato(
                icono: Icons.person_outline_rounded,
                texto: 'Por: ${item.eliminadoPor.nombreCompleto}',
              ),
              if (item.ruta != null)
                _ChipMetadato(
                  icono: Icons.alt_route_rounded,
                  texto: 'Ruta: ${item.ruta!.nombre}',
                ),
              // Opción de purga definitiva (solo administradores)
              if (esAdministrador)
                TextButton.icon(
                  onPressed: onEliminarDefinitivo,
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Purgar',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipMetadato extends StatelessWidget {
  const _ChipMetadato({
    required this.icono,
    required this.texto,
  });

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icono,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
