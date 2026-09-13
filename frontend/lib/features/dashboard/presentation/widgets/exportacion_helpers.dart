import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/platform/export_download.dart';
import '../../../../core/ui/visor_exportacion_excel.dart';
import '../../../../data/models/models.dart';
import '../../../caja_menor/presentation/widgets/filtros_caja_menor.dart';
import '../../../creditos/presentation/widgets/filtros_credito.dart';
import '../../../rutas/presentation/widgets/filtros_ruta.dart';

Future<void> mostrarExportacionLista(
  BuildContext context,
  ExportacionExcel exportacion, {
  required void Function(String) mostrarMensaje,
}) async {
  final String filas =
      exportacion.filas == 1 ? '1 fila' : '${exportacion.filas} filas';
  mostrarMensaje('Excel exportado en R2: $filas');

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return VisorExportacionExcel(
        exportacion: exportacion,
        onDescargar: () async {
          final bool abierta = await abrirExportacionExcel(exportacion.url);
          if (!abierta && context.mounted) {
            mostrarMensaje('No se pudo descargar el archivo exportado');
          }
        },
      );
    },
  );
}

Future<void> exportarCobrosRutaHelper({
  required BuildContext context,
  required ApiClient apiClient,
  required String? rutaFiltroId,
  required String searchText,
  required FiltroEstadoRuta filtroEstadoRuta,
  required bool exportando,
  required void Function(bool) setExportando,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required void Function(String) setError,
}) async {
  if (exportando) {
    return;
  }

  setExportando(true);
  mostrarMensaje('Generando Excel...');

  try {
    final ExportacionExcel exportacion = ExportacionExcel.fromJson(
      await apiClient.getObject(
        '/exportaciones/cobros-ruta',
        query: <String, String?>{
          'rutaId': rutaFiltroId,
          'search': searchText.trim(),
          'estadoCobro': filtroEstadoRuta.wire,
        },
      ),
    );
    setExportando(false);
    if (context.mounted) {
      await mostrarExportacionLista(
        context,
        exportacion,
        mostrarMensaje: mostrarMensaje,
      );
    }
  } catch (error) {
    setError(mensajeError(error));
    mostrarMensaje(mensajeError(error));
  } finally {
    setExportando(false);
  }
}

Future<void> exportarCreditosHelper({
  required BuildContext context,
  required ApiClient apiClient,
  required String searchText,
  required FiltroEstadoCredito filtroCredito,
  required DateTime? fechaCreditoDesde,
  required DateTime? fechaCreditoHasta,
  required bool exportando,
  required void Function(bool) setExportando,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required void Function(String) setError,
}) async {
  if (exportando) {
    return;
  }

  setExportando(true);
  mostrarMensaje('Generando Excel...');

  try {
    final ExportacionExcel exportacion = ExportacionExcel.fromJson(
      await apiClient.getObject(
        '/exportaciones/creditos',
        query: <String, String?>{
          'search': searchText.trim(),
          'estado': filtroCredito == FiltroEstadoCredito.todos
              ? null
              : filtroCredito.name,
          'fechaDesde': fechaCreditoDesde == null
              ? null
              : formatDateValue(fechaCreditoDesde),
          'fechaHasta': fechaCreditoHasta == null
              ? null
              : formatDateValue(fechaCreditoHasta),
        },
      ),
    );
    setExportando(false);
    if (context.mounted) {
      await mostrarExportacionLista(
        context,
        exportacion,
        mostrarMensaje: mostrarMensaje,
      );
    }
  } catch (error) {
    setError(mensajeError(error));
    mostrarMensaje(mensajeError(error));
  } finally {
    setExportando(false);
  }
}

Future<void> exportarMovimientosCajaHelper({
  required BuildContext context,
  required ApiClient apiClient,
  required String? cajaMenorFiltroId,
  required String searchText,
  required FiltroMovimientoCaja filtroMovimientoCaja,
  required DateTime? fechaCajaDesde,
  required DateTime? fechaCajaHasta,
  required bool exportando,
  required void Function(bool) setExportando,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required void Function(String) setError,
}) async {
  if (exportando) {
    return;
  }

  setExportando(true);
  mostrarMensaje('Generando Excel...');

  try {
    final ExportacionExcel exportacion = ExportacionExcel.fromJson(
      await apiClient.getObject(
        '/exportaciones/caja-menor',
        query: <String, String?>{
          'cajaMenorId': cajaMenorFiltroId,
          'search': searchText.trim(),
          'tipo': filtroMovimientoCaja == FiltroMovimientoCaja.todos
              ? null
              : filtroMovimientoCaja.name,
          'fechaDesde':
              fechaCajaDesde == null ? null : formatDateValue(fechaCajaDesde),
          'fechaHasta':
              fechaCajaHasta == null ? null : formatDateValue(fechaCajaHasta),
        },
      ),
    );
    setExportando(false);
    if (context.mounted) {
      await mostrarExportacionLista(
        context,
        exportacion,
        mostrarMensaje: mostrarMensaje,
      );
    }
  } catch (error) {
    setError(mensajeError(error));
    mostrarMensaje(mensajeError(error));
  } finally {
    setExportando(false);
  }
}
