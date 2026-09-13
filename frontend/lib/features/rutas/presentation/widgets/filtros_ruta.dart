import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/ui/clay.dart';
import '../../../../core/ui/cobro_dropdown.dart';
import '../../../../data/models/models.dart';

enum FiltroEstadoRuta {
  todos,
  alDia,
  pendiente,
  atrasado,
  pagado;

  EstadoCobro? get estadoCobro {
    return switch (this) {
      FiltroEstadoRuta.todos => null,
      FiltroEstadoRuta.alDia => EstadoCobro.alDia,
      FiltroEstadoRuta.pendiente => EstadoCobro.pendiente,
      FiltroEstadoRuta.atrasado => EstadoCobro.atrasado,
      FiltroEstadoRuta.pagado => EstadoCobro.pagado,
    };
  }

  String? get wire {
    return switch (this) {
      FiltroEstadoRuta.todos => null,
      FiltroEstadoRuta.alDia => 'AL_DIA',
      FiltroEstadoRuta.pendiente => 'PENDIENTE',
      FiltroEstadoRuta.atrasado => 'ATRASADO',
      FiltroEstadoRuta.pagado => 'PAGADO',
    };
  }
}

class FiltrosRuta extends StatelessWidget {
  const FiltrosRuta({
    super.key,
    required this.buscarController,
    required this.rutas,
    required this.rutaSeleccionadaId,
    required this.exportando,
    required this.vistaMapaDesktop,
    required this.mostrarLimpiarFiltros,
    required this.onRutaChanged,
    required this.onExportar,
    required this.onLimpiarFiltros,
  });

  final TextEditingController buscarController;
  final List<RutaCatalogo> rutas;
  final String? rutaSeleccionadaId;
  final bool exportando;
  final bool vistaMapaDesktop;
  final bool mostrarLimpiarFiltros;
  final ValueChanged<String?> onRutaChanged;
  final VoidCallback onExportar;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 620;
        final Widget buscar = TextField(
          controller: buscarController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Buscar cliente, cedula o negocio',
          ),
        );
        final Widget selectorRuta = CobroDropdownField<String?>(
          key: ValueKey<String?>(rutaSeleccionadaId),
          labelText: 'Ruta',
          prefixIcon: const Icon(Icons.route_rounded),
          value: rutaSeleccionadaId,
          hintText: 'Todas',
          menuWidth: 260,
          items: <CobroDropdownItem<String?>>[
            const CobroDropdownItem<String?>(
              value: null,
              label: 'Todas',
              subtitle: 'Todas las rutas',
              icon: Icons.all_inclusive_rounded,
              iconColor: Color(0xFF6366F1),
            ),
            ...rutas.map(
              (RutaCatalogo ruta) => CobroDropdownItem<String?>(
                value: ruta.id,
                label: ruta.nombre,
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
          onChanged: onRutaChanged,
        );
        final Widget exportar = SizedBox(
          width: compact ? double.infinity : null,
          height: compact ? 56 : null,
          child: OutlinedButton.icon(
            onPressed: exportando ? null : onExportar,
            icon: exportando
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            label: Text(exportando ? 'Exportando' : 'Exportar'),
          ),
        );
        final Widget limpiar = Tooltip(
          message: 'Limpiar filtros',
          child: IconButton.outlined(
            onPressed: onLimpiarFiltros,
            icon: const Icon(Icons.filter_alt_off_rounded),
          ),
        );

        if (vistaMapaDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              buscar,
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: selectorRuta),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: exportando ? 'Exportando' : 'Exportar ruta',
                    child: SizedBox.square(
                      dimension: 56,
                      child: IconButton.outlined(
                        onPressed: exportando ? null : onExportar,
                        icon: exportando
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.file_download_outlined),
                      ),
                    ),
                  ),
                  if (mostrarLimpiarFiltros) ...<Widget>[
                    const SizedBox(width: 8),
                    SizedBox.square(dimension: 56, child: limpiar),
                  ],
                ],
              ),
            ],
          );
        }

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              buscar,
              const SizedBox(height: 10),
              selectorRuta,
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: exportar),
                  if (mostrarLimpiarFiltros) ...<Widget>[
                    const SizedBox(width: 10),
                    SizedBox.square(
                      dimension: 56,
                      child: limpiar,
                    ),
                  ],
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 2, child: buscar),
            const SizedBox(width: 12),
            Expanded(child: selectorRuta),
            const SizedBox(width: 12),
            exportar,
            if (mostrarLimpiarFiltros) ...<Widget>[
              const SizedBox(width: 8),
              limpiar,
            ],
          ],
        );
      },
    );
  }
}

class ResumenEstados extends StatelessWidget {
  const ResumenEstados({
    super.key,
    required this.alDia,
    required this.pendientes,
    required this.atrasados,
    required this.pagados,
    required this.filtro,
    required this.onFiltroChanged,
  });

  final int alDia;
  final int pendientes;
  final int atrasados;
  final int pagados;
  final FiltroEstadoRuta filtro;
  final ValueChanged<FiltroEstadoRuta> onFiltroChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        EstadoContador(
          label: 'Al día',
          value: alDia,
          color: CobroAppTheme.success,
          selected: filtro == FiltroEstadoRuta.alDia,
          onTap: () => onFiltroChanged(FiltroEstadoRuta.alDia),
        ),
        EstadoContador(
          label: 'Debe hoy',
          value: pendientes,
          color: CobroAppTheme.warning,
          selected: filtro == FiltroEstadoRuta.pendiente,
          onTap: () => onFiltroChanged(FiltroEstadoRuta.pendiente),
        ),
        EstadoContador(
          label: 'Atrasado',
          value: atrasados,
          color: CobroAppTheme.danger,
          selected: filtro == FiltroEstadoRuta.atrasado,
          onTap: () => onFiltroChanged(FiltroEstadoRuta.atrasado),
        ),
        EstadoContador(
          label: 'Pagados',
          value: pagados,
          color: CobroAppTheme.primary,
          selected: filtro == FiltroEstadoRuta.pagado,
          onTap: () => onFiltroChanged(FiltroEstadoRuta.pagado),
        ),
      ],
    );
  }
}

class EstadoContador extends StatelessWidget {
  const EstadoContador({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filtrar $label',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width < 560 ? 132 : 0,
        ),
        child: ClaySurface(
          radius: 14,
          padding: EdgeInsets.zero,
          color: color.withValues(alpha: selected ? 0.18 : 0.08),
          borderColor: color.withValues(alpha: selected ? 0.48 : 0.22),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.circle,
                      size: selected ? 16 : 10,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$label: $value',
                      style: TextStyle(
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
