import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
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
    this.onSeleccionarRangoFechas,
    this.onSeleccionarFechaDesde,
    this.onSeleccionarFechaHasta,
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
  final VoidCallback? onSeleccionarRangoFechas;
  final VoidCallback? onSeleccionarFechaDesde;
  final VoidCallback? onSeleccionarFechaHasta;
  final bool exportando;
  final VoidCallback? onExportar;
  final bool hayFiltrosCaja;
  final VoidCallback onLimpiarFiltros;

  VoidCallback get _callbackFechas =>
      onSeleccionarRangoFechas ??
      onSeleccionarFechaDesde ??
      () {};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool esMovil = constraints.maxWidth < 600;

        if (esMovil) {
          return _FiltrosCajaMovil(
            cajas: cajas,
            cajaMenorFiltroId: cajaMenorFiltroId,
            todasLasCajasFiltro: todasLasCajasFiltro,
            onCajaChanged: onCajaChanged,
            filtroMovimientoCaja: filtroMovimientoCaja,
            onFiltroMovimientoCajaChanged: onFiltroMovimientoCajaChanged,
            fechaCajaDesde: fechaCajaDesde,
            fechaCajaHasta: fechaCajaHasta,
            onSeleccionarFechas: _callbackFechas,
            exportando: exportando,
            onExportar: onExportar,
            hayFiltrosCaja: hayFiltrosCaja,
            onLimpiarFiltros: onLimpiarFiltros,
          );
        }

        return _FiltrosCajaDesktop(
          cajas: cajas,
          cajaMenorFiltroId: cajaMenorFiltroId,
          todasLasCajasFiltro: todasLasCajasFiltro,
          onCajaChanged: onCajaChanged,
          filtroMovimientoCaja: filtroMovimientoCaja,
          onFiltroMovimientoCajaChanged: onFiltroMovimientoCajaChanged,
          fechaCajaDesde: fechaCajaDesde,
          fechaCajaHasta: fechaCajaHasta,
          onSeleccionarFechas: _callbackFechas,
          exportando: exportando,
          onExportar: onExportar,
          hayFiltrosCaja: hayFiltrosCaja,
          onLimpiarFiltros: onLimpiarFiltros,
        );
      },
    );
  }
}

/// Disposición optimizada para dispositivos móviles (Opción 2: Jerarquía en 3 filas especializadas).
class _FiltrosCajaMovil extends StatelessWidget {
  const _FiltrosCajaMovil({
    required this.cajas,
    required this.cajaMenorFiltroId,
    required this.todasLasCajasFiltro,
    required this.onCajaChanged,
    required this.filtroMovimientoCaja,
    required this.onFiltroMovimientoCajaChanged,
    required this.fechaCajaDesde,
    required this.fechaCajaHasta,
    required this.onSeleccionarFechas,
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
  final VoidCallback onSeleccionarFechas;
  final bool exportando;
  final VoidCallback? onExportar;
  final bool hayFiltrosCaja;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Fila 1: SegmentedButton al 100% del ancho con colores semánticos
        SizedBox(
          width: double.infinity,
          child: _SegmentoTipoMovimiento(
            filtro: filtroMovimientoCaja,
            onChanged: onFiltroMovimientoCajaChanged,
          ),
        ),
        const SizedBox(height: 8),

        // Fila 2: Selector de Caja al 100% del ancho (nombres completos sin truncamientos)
        if (cajas.isNotEmpty) ...<Widget>[
          _SelectorCajaDropdown(
            cajas: cajas,
            cajaMenorFiltroId: cajaMenorFiltroId,
            todasLasCajasFiltro: todasLasCajasFiltro,
            onCajaChanged: onCajaChanged,
            labelText: 'Caja',
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
          ),
          const SizedBox(height: 8),
        ],

        // Fila 3: Rango de Fechas (Expanded con espacio amplio para texto completo) + Exportar + Limpiar
        Row(
          children: <Widget>[
            Expanded(
              child: _BotonRangoFechas(
                fechaDesde: fechaCajaDesde,
                fechaHasta: fechaCajaHasta,
                onTap: onSeleccionarFechas,
              ),
            ),
            const SizedBox(width: 8),
            _BotonIconoAccion(
              tooltip: exportando ? 'Exportando...' : 'Exportar reporte',
              estaCargando: exportando,
              icono: Icons.file_download_outlined,
              onPressed: exportando ? null : onExportar,
            ),
            if (hayFiltrosCaja) ...<Widget>[
              const SizedBox(width: 8),
              _BotonIconoAccion(
                tooltip: 'Limpiar filtros',
                icono: Icons.filter_alt_off_rounded,
                onPressed: onLimpiarFiltros,
                colorIcono: Theme.of(context).colorScheme.error,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Disposición horizontal fluida para pantallas grandes/desktop.
class _FiltrosCajaDesktop extends StatelessWidget {
  const _FiltrosCajaDesktop({
    required this.cajas,
    required this.cajaMenorFiltroId,
    required this.todasLasCajasFiltro,
    required this.onCajaChanged,
    required this.filtroMovimientoCaja,
    required this.onFiltroMovimientoCajaChanged,
    required this.fechaCajaDesde,
    required this.fechaCajaHasta,
    required this.onSeleccionarFechas,
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
  final VoidCallback onSeleccionarFechas;
  final bool exportando;
  final VoidCallback? onExportar;
  final bool hayFiltrosCaja;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (cajas.isNotEmpty)
          SizedBox(
            width: 250,
            child: _SelectorCajaDropdown(
              cajas: cajas,
              cajaMenorFiltroId: cajaMenorFiltroId,
              todasLasCajasFiltro: todasLasCajasFiltro,
              onCajaChanged: onCajaChanged,
              labelText: 'Caja',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
            ),
          ),
        _SegmentoTipoMovimiento(
          filtro: filtroMovimientoCaja,
          onChanged: onFiltroMovimientoCajaChanged,
        ),
        _BotonRangoFechas(
          fechaDesde: fechaCajaDesde,
          fechaHasta: fechaCajaHasta,
          onTap: onSeleccionarFechas,
        ),
        Tooltip(
          message: exportando ? 'Exportando...' : 'Exportar reporte',
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

// ---------------------------------------------------------------------------
// SUBCOMPONENTES MODULARES Y DESACOPLADOS
// ---------------------------------------------------------------------------

class _SegmentoTipoMovimiento extends StatelessWidget {
  const _SegmentoTipoMovimiento({
    required this.filtro,
    required this.onChanged,
  });

  final FiltroMovimientoCaja filtro;
  final ValueChanged<FiltroMovimientoCaja> onChanged;

  Color _colorActivo() {
    switch (filtro) {
      case FiltroMovimientoCaja.todos:
        return CobroAppTheme.primary;
      case FiltroMovimientoCaja.entradas:
        return CobroAppTheme.success;
      case FiltroMovimientoCaja.salidas:
        return CobroAppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colorActivo = _colorActivo();

    return SegmentedButton<FiltroMovimientoCaja>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorActivo.withValues(alpha: 0.14);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorActivo;
          }
          return theme.colorScheme.onSurfaceVariant;
        }),
        textStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        side: WidgetStateProperty.resolveWith<BorderSide>((states) {
          return BorderSide(
            color: colorActivo.withValues(alpha: 0.28),
            width: 1.0,
          );
        }),
      ),
      segments: const <ButtonSegment<FiltroMovimientoCaja>>[
        ButtonSegment<FiltroMovimientoCaja>(
          value: FiltroMovimientoCaja.todos,
          icon: Icon(Icons.receipt_long_rounded, size: 14),
          label: Text('Todos', softWrap: false, maxLines: 1),
        ),
        ButtonSegment<FiltroMovimientoCaja>(
          value: FiltroMovimientoCaja.entradas,
          icon: Icon(Icons.arrow_upward_rounded, size: 14),
          label: Text('Entradas', softWrap: false, maxLines: 1),
        ),
        ButtonSegment<FiltroMovimientoCaja>(
          value: FiltroMovimientoCaja.salidas,
          icon: Icon(Icons.arrow_downward_rounded, size: 14),
          label: Text('Salidas', softWrap: false, maxLines: 1),
        ),
      ],
      selected: <FiltroMovimientoCaja>{filtro},
      onSelectionChanged: (Set<FiltroMovimientoCaja> value) {
        HapticFeedback.selectionClick();
        onChanged(value.first);
      },
    );
  }
}

class _BotonRangoFechas extends StatelessWidget {
  const _BotonRangoFechas({
    required this.fechaDesde,
    required this.fechaHasta,
    required this.onTap,
  });

  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final VoidCallback onTap;

  String _formatearEtiqueta() {
    if (fechaDesde == null && fechaHasta == null) {
      return 'Fechas';
    }
    if (fechaDesde != null && fechaHasta != null) {
      if (fechaDesde!.year == fechaHasta!.year &&
          fechaDesde!.month == fechaHasta!.month &&
          fechaDesde!.day == fechaHasta!.day) {
        return formatDateLabel(fechaDesde);
      }
      return '${formatDateLabel(fechaDesde)} - ${formatDateLabel(fechaHasta)}';
    }
    if (fechaDesde != null) {
      return 'Desde ${formatDateLabel(fechaDesde)}';
    }
    return 'Hasta ${formatDateLabel(fechaHasta)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool activo = fechaDesde != null || fechaHasta != null;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          backgroundColor:
              activo ? colorScheme.primary.withValues(alpha: 0.08) : null,
          side: BorderSide(
            color: activo
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          Icons.date_range_rounded,
          size: 16,
          color: activo ? colorScheme.primary : null,
        ),
        label: Text(
          _formatearEtiqueta(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
            color: activo ? colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}

class _SelectorCajaDropdown extends StatelessWidget {
  const _SelectorCajaDropdown({
    required this.cajas,
    required this.cajaMenorFiltroId,
    required this.todasLasCajasFiltro,
    required this.onCajaChanged,
    this.labelText = 'Caja',
    this.prefixIcon,
  });

  final List<CajaMenorCatalogo> cajas;
  final String? cajaMenorFiltroId;
  final String todasLasCajasFiltro;
  final ValueChanged<String?> onCajaChanged;
  final String? labelText;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final bool filtroCajaValido = cajas.any(
      (CajaMenorCatalogo caja) => caja.id == cajaMenorFiltroId,
    );

    return CobroDropdownField<String>(
      key: ValueKey<String>(
        'filtro-caja-${cajaMenorFiltroId ?? todasLasCajasFiltro}',
      ),
      labelText: labelText,
      prefixIcon: prefixIcon,
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
    );
  }
}

class _BotonIconoAccion extends StatelessWidget {
  const _BotonIconoAccion({
    required this.tooltip,
    required this.icono,
    required this.onPressed,
    this.estaCargando = false,
    this.colorIcono,
  });

  final String tooltip;
  final IconData icono;
  final VoidCallback? onPressed;
  final bool estaCargando;
  final Color? colorIcono;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 42,
      child: Tooltip(
        message: tooltip,
        child: IconButton.outlined(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onPressed,
          icon: estaCargando
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icono, size: 17, color: colorIcono),
        ),
      ),
    );
  }
}
