import 'package:flutter/material.dart';

import '../formatters/app_formatters.dart';

/// Botón estilizado para selector de rango de fechas con estado visual activo/inactivo.
class BotonRangoFechas extends StatelessWidget {
  const BotonRangoFechas({
    super.key,
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

/// Botón compacto de icono para acciones auxiliares en barras de filtros (Exportar, Limpiar, etc.).
class BotonIconoAccion extends StatelessWidget {
  const BotonIconoAccion({
    super.key,
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
