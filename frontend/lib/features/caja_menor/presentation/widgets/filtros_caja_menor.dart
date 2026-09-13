import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/cobro_dropdown.dart';
import '../../../../data/models/models.dart';

enum FiltroMovimientoCaja {
  todos,
  entradas,
  salidas,
}

class FiltrosCajaMenor extends StatelessWidget {
  const FiltrosCajaMenor({
    super.key,
    required this.cajas,
    required this.cajaMenorFiltroId,
    this.todasLasCajasFiltro = '__todas_las_cajas__',
    required this.onCajaChanged,
    required this.filtroMovimientoCaja,
    required this.onFiltroMovimientoCajaChanged,
    required this.fechaCajaDesde,
    required this.fechaCajaHasta,
    required this.onSeleccionarFechaDesde,
    required this.onSeleccionarFechaHasta,
    required this.exportando,
    required this.onExportar,
    required this.hayFiltrosCaja,
    required this.onLimpiarFiltros,
  });

  final List<CajaMenorCatalogo> cajas;
  final String? cajaMenorFiltroId;
  final String todasLasCajasFiltro;
  final ValueChanged<String?> onCajaChanged;
  final FiltroMovimientoCaja filtroMovimientoCaja;
  final ValueChanged<FiltroMovimientoCaja> onFiltroMovimientoCajaChanged;
  final DateTime? fechaCajaDesde;
  final DateTime? fechaCajaHasta;
  final VoidCallback onSeleccionarFechaDesde;
  final VoidCallback onSeleccionarFechaHasta;
  final bool exportando;
  final VoidCallback? onExportar;
  final bool hayFiltrosCaja;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    final bool filtroCajaValido = cajas.any(
      (CajaMenorCatalogo caja) => caja.id == cajaMenorFiltroId,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (cajas.isNotEmpty)
          SizedBox(
            width: 260,
            child: CobroDropdownField<String>(
              key: ValueKey<String>(
                'filtro-caja-${cajaMenorFiltroId ?? todasLasCajasFiltro}',
              ),
              labelText: 'Caja',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              value: filtroCajaValido ? cajaMenorFiltroId : todasLasCajasFiltro,
              menuWidth: 260,
              items: <CobroDropdownItem<String>>[
                CobroDropdownItem<String>(
                  value: todasLasCajasFiltro,
                  label: 'Todas las cajas',
                  subtitle: 'Ver movimientos globales',
                  icon: Icons.all_inbox_rounded,
                  iconColor: const Color(0xFF6366F1),
                ),
                ...cajas.map(
                  (CajaMenorCatalogo caja) {
                    final String estadoTexto =
                        caja.estaAbierta ? 'Abierta' : 'Cerrada';
                    final String resp = caja.responsable != null &&
                            caja.responsable!.nombreCompleto.trim().isNotEmpty
                        ? '${caja.responsable!.nombreCompleto.trim()} • '
                        : '';
                    return CobroDropdownItem<String>(
                      value: caja.id,
                      label: caja.nombre,
                      subtitle: '$estadoTexto • $resp${caja.monedaCodigo}',
                      icon: caja.estaAbierta
                          ? Icons.savings_rounded
                          : Icons.lock_outline_rounded,
                      iconColor: caja.estaAbierta
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF6B7280),
                    );
                  },
                ),
              ],
              onChanged: onCajaChanged,
            ),
          ),
        SegmentedButton<FiltroMovimientoCaja>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<FiltroMovimientoCaja>>[
            ButtonSegment<FiltroMovimientoCaja>(
              value: FiltroMovimientoCaja.todos,
              icon: Icon(Icons.receipt_long_rounded),
              label: Text('Todos'),
            ),
            ButtonSegment<FiltroMovimientoCaja>(
              value: FiltroMovimientoCaja.entradas,
              icon: Icon(Icons.arrow_upward_rounded),
              label: Text('Entradas'),
            ),
            ButtonSegment<FiltroMovimientoCaja>(
              value: FiltroMovimientoCaja.salidas,
              icon: Icon(Icons.arrow_downward_rounded),
              label: Text('Salidas'),
            ),
          ],
          selected: <FiltroMovimientoCaja>{filtroMovimientoCaja},
          onSelectionChanged: (Set<FiltroMovimientoCaja> value) {
            onFiltroMovimientoCajaChanged(value.first);
          },
        ),
        OutlinedButton.icon(
          onPressed: onSeleccionarFechaDesde,
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(
            fechaCajaDesde == null
                ? 'Desde'
                : 'Desde ${formatDateLabel(fechaCajaDesde)}',
          ),
        ),
        OutlinedButton.icon(
          onPressed: onSeleccionarFechaHasta,
          icon: const Icon(Icons.event_available_rounded),
          label: Text(
            fechaCajaHasta == null
                ? 'Hasta'
                : 'Hasta ${formatDateLabel(fechaCajaHasta)}',
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
        if (hayFiltrosCaja)
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
