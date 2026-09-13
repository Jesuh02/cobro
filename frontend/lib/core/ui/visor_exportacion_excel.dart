import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/exportacion_model.dart';
import '../formatters/app_formatters.dart';
import 'clay.dart';

class VisorExportacionExcel extends StatelessWidget {
  const VisorExportacionExcel({
    super.key,
    required this.exportacion,
    required this.onDescargar,
  });

  final ExportacionExcel exportacion;
  final Future<void> Function() onDescargar;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Size size = MediaQuery.sizeOf(context);
    final ExportacionVistaPrevia vistaPrevia = exportacion.vistaPrevia;
    final bool sinVistaPrevia =
        vistaPrevia.columnas.isEmpty || vistaPrevia.filas.isEmpty;
    final String filas = exportacion.filas == 1
        ? '1 fila exportada'
        : '${exportacion.filas} filas exportadas';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1080,
          maxHeight: size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.table_chart_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          exportacion.archivo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: <Widget>[
                            EtiquetaExportacion(texto: filas),
                            EtiquetaExportacion(
                              texto:
                                  'Generado ${formatDateTimeLabel(exportacion.generadoEn)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: clay.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: sinVistaPrevia
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'El Excel no tiene filas para previsualizar.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: clay.subtleText),
                              ),
                            ),
                          )
                        : TablaVistaPreviaExcel(vistaPrevia: vistaPrevia),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        unawaited(onDescargar());
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Descargar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EtiquetaExportacion extends StatelessWidget {
  const EtiquetaExportacion({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.clay.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.clay.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.clay.subtleText,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class TablaVistaPreviaExcel extends StatelessWidget {
  const TablaVistaPreviaExcel({super.key, required this.vistaPrevia});

  final ExportacionVistaPrevia vistaPrevia;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Scrollbar(
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll<Color>(
                clay.surfaceHigh,
              ),
              headingTextStyle: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
              dataTextStyle: Theme.of(context).textTheme.bodySmall,
              columnSpacing: 18,
              columns: vistaPrevia.columnas
                  .map(
                    (String columna) => DataColumn(
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          columna,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
              rows: vistaPrevia.filas
                  .map(
                    (List<Object?> fila) => DataRow(
                      cells: List<DataCell>.generate(
                        vistaPrevia.columnas.length,
                        (int index) {
                          final Object? valor =
                              index < fila.length ? fila[index] : null;
                          return DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                formatExportCellText(valor),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}
