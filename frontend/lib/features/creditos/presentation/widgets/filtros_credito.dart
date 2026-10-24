import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/ui/botones_filtro.dart';

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
    this.onSeleccionarRangoFechas,
    this.onSeleccionarFechaDesde,
    this.onSeleccionarFechaHasta,
    required this.exportando,
    required this.onExportar,
    required this.hayFiltrosCredito,
    required this.onLimpiarFiltros,
  });

  final FiltroEstadoCredito filtroCredito;
  final ValueChanged<FiltroEstadoCredito> onFiltroCreditoChanged;
  final DateTime? fechaCreditoDesde;
  final DateTime? fechaCreditoHasta;
  final VoidCallback? onSeleccionarRangoFechas;
  final VoidCallback? onSeleccionarFechaDesde;
  final VoidCallback? onSeleccionarFechaHasta;
  final bool exportando;
  final VoidCallback? onExportar;
  final bool hayFiltrosCredito;
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
          return _FiltrosCreditoMovil(
            filtroCredito: filtroCredito,
            onFiltroCreditoChanged: onFiltroCreditoChanged,
            fechaCreditoDesde: fechaCreditoDesde,
            fechaCreditoHasta: fechaCreditoHasta,
            onSeleccionarFechas: _callbackFechas,
            exportando: exportando,
            onExportar: onExportar,
            hayFiltrosCredito: hayFiltrosCredito,
            onLimpiarFiltros: onLimpiarFiltros,
          );
        }

        return _FiltrosCreditoDesktop(
          filtroCredito: filtroCredito,
          onFiltroCreditoChanged: onFiltroCreditoChanged,
          fechaCreditoDesde: fechaCreditoDesde,
          fechaCreditoHasta: fechaCreditoHasta,
          onSeleccionarFechas: _callbackFechas,
          exportando: exportando,
          onExportar: onExportar,
          hayFiltrosCredito: hayFiltrosCredito,
          onLimpiarFiltros: onLimpiarFiltros,
        );
      },
    );
  }
}

/// Disposición optimizada para dispositivos móviles (2 filas compactas).
class _FiltrosCreditoMovil extends StatelessWidget {
  const _FiltrosCreditoMovil({
    required this.filtroCredito,
    required this.onFiltroCreditoChanged,
    required this.fechaCreditoDesde,
    required this.fechaCreditoHasta,
    required this.onSeleccionarFechas,
    required this.exportando,
    required this.onExportar,
    required this.hayFiltrosCredito,
    required this.onLimpiarFiltros,
  });

  final FiltroEstadoCredito filtroCredito;
  final ValueChanged<FiltroEstadoCredito> onFiltroCreditoChanged;
  final DateTime? fechaCreditoDesde;
  final DateTime? fechaCreditoHasta;
  final VoidCallback onSeleccionarFechas;
  final bool exportando;
  final VoidCallback? onExportar;
  final bool hayFiltrosCredito;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Fila 1: SegmentedButton al 100% de ancho con colores semánticos
        SizedBox(
          width: double.infinity,
          child: _SegmentoEstadoCredito(
            filtro: filtroCredito,
            onChanged: onFiltroCreditoChanged,
          ),
        ),
        const SizedBox(height: 8),

        // Fila 2: Rango de Fechas (Expanded) + Exportar + Limpiar
        Row(
          children: <Widget>[
            Expanded(
              child: BotonRangoFechas(
                fechaDesde: fechaCreditoDesde,
                fechaHasta: fechaCreditoHasta,
                onTap: onSeleccionarFechas,
              ),
            ),
            const SizedBox(width: 8),
            BotonIconoAccion(
              tooltip: exportando ? 'Exportando...' : 'Exportar reporte',
              estaCargando: exportando,
              icono: Icons.file_download_outlined,
              onPressed: exportando ? null : onExportar,
            ),
            if (hayFiltrosCredito) ...<Widget>[
              const SizedBox(width: 8),
              BotonIconoAccion(
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
class _FiltrosCreditoDesktop extends StatelessWidget {
  const _FiltrosCreditoDesktop({
    required this.filtroCredito,
    required this.onFiltroCreditoChanged,
    required this.fechaCreditoDesde,
    required this.fechaCreditoHasta,
    required this.onSeleccionarFechas,
    required this.exportando,
    required this.onExportar,
    required this.hayFiltrosCredito,
    required this.onLimpiarFiltros,
  });

  final FiltroEstadoCredito filtroCredito;
  final ValueChanged<FiltroEstadoCredito> onFiltroCreditoChanged;
  final DateTime? fechaCreditoDesde;
  final DateTime? fechaCreditoHasta;
  final VoidCallback onSeleccionarFechas;
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
        _SegmentoEstadoCredito(
          filtro: filtroCredito,
          onChanged: onFiltroCreditoChanged,
        ),
        BotonRangoFechas(
          fechaDesde: fechaCreditoDesde,
          fechaHasta: fechaCreditoHasta,
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

class _SegmentoEstadoCredito extends StatelessWidget {
  const _SegmentoEstadoCredito({
    required this.filtro,
    required this.onChanged,
  });

  final FiltroEstadoCredito filtro;
  final ValueChanged<FiltroEstadoCredito> onChanged;

  Color _colorActivo() {
    switch (filtro) {
      case FiltroEstadoCredito.todos:
        return CobroAppTheme.primary;
      case FiltroEstadoCredito.activos:
        return CobroAppTheme.success;
      case FiltroEstadoCredito.inactivos:
        return CobroAppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colorActivo = _colorActivo();

    return SegmentedButton<FiltroEstadoCredito>(
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
      segments: const <ButtonSegment<FiltroEstadoCredito>>[
        ButtonSegment<FiltroEstadoCredito>(
          value: FiltroEstadoCredito.todos,
          icon: Icon(Icons.receipt_long_rounded, size: 14),
          label: Text('Todos', softWrap: false, maxLines: 1),
        ),
        ButtonSegment<FiltroEstadoCredito>(
          value: FiltroEstadoCredito.activos,
          icon: Icon(Icons.check_circle_outline_rounded, size: 14),
          label: Text('Activos', softWrap: false, maxLines: 1),
        ),
        ButtonSegment<FiltroEstadoCredito>(
          value: FiltroEstadoCredito.inactivos,
          icon: Icon(Icons.pause_circle_outline_rounded, size: 14),
          label: Text('Inactivos', softWrap: false, maxLines: 1),
        ),
      ],
      selected: <FiltroEstadoCredito>{filtro},
      onSelectionChanged: (Set<FiltroEstadoCredito> value) {
        HapticFeedback.selectionClick();
        onChanged(value.first);
      },
    );
  }
}
