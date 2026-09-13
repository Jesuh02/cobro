import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';

enum FiltroEstadoCredito {
  todos,
  activos,
  inactivos,
}

class FiltrosCredito extends StatelessWidget {
  const FiltrosCredito({
    super.key,
    required this.filtroCredito,
    required this.onFiltroCreditoChanged,
    required this.fechaCreditoDesde,
    required this.fechaCreditoHasta,
    required this.onSeleccionarFechaDesde,
    required this.onSeleccionarFechaHasta,
    required this.exportando,
    required this.onExportar,
    required this.hayFiltrosCredito,
    required this.onLimpiarFiltros,
  });

  final FiltroEstadoCredito filtroCredito;
  final ValueChanged<FiltroEstadoCredito> onFiltroCreditoChanged;
  final DateTime? fechaCreditoDesde;
  final DateTime? fechaCreditoHasta;
  final VoidCallback onSeleccionarFechaDesde;
  final VoidCallback onSeleccionarFechaHasta;
  final bool exportando;
  final VoidCallback? onExportar;
  final bool hayFiltrosCredito;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SegmentedButton<FiltroEstadoCredito>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<FiltroEstadoCredito>>[
            ButtonSegment<FiltroEstadoCredito>(
              value: FiltroEstadoCredito.todos,
              icon: Icon(Icons.receipt_long_rounded),
              label: Text('Todos'),
            ),
            ButtonSegment<FiltroEstadoCredito>(
              value: FiltroEstadoCredito.activos,
              icon: Icon(Icons.check_circle_outline_rounded),
              label: Text('Activos'),
            ),
            ButtonSegment<FiltroEstadoCredito>(
              value: FiltroEstadoCredito.inactivos,
              icon: Icon(Icons.pause_circle_outline_rounded),
              label: Text('Inactivos'),
            ),
          ],
          selected: <FiltroEstadoCredito>{filtroCredito},
          onSelectionChanged: (Set<FiltroEstadoCredito> value) {
            onFiltroCreditoChanged(value.first);
          },
        ),
        OutlinedButton.icon(
          onPressed: onSeleccionarFechaDesde,
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(
            fechaCreditoDesde == null
                ? 'Desde'
                : 'Desde ${formatDateLabel(fechaCreditoDesde)}',
          ),
        ),
        OutlinedButton.icon(
          onPressed: onSeleccionarFechaHasta,
          icon: const Icon(Icons.event_available_rounded),
          label: Text(
            fechaCreditoHasta == null
                ? 'Hasta'
                : 'Hasta ${formatDateLabel(fechaCreditoHasta)}',
          ),
        ),
        OutlinedButton.icon(
          onPressed: exportando ? null : onExportar,
          icon: exportando
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined),
          label: Text(exportando ? 'Exportando' : 'Exportar'),
        ),
        if (hayFiltrosCredito)
          Tooltip(
            message: 'Limpiar filtros',
            child: IconButton.outlined(
              onPressed: onLimpiarFiltros,
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
          ),
      ],
    );
  }
}
