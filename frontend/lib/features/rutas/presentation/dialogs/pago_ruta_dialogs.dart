import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/ui/clay.dart';
import '../../../../data/models/models.dart';
import '../widgets/selector_cobro_ruta_buscable.dart';
import '../widgets/selector_medio_pago_buscable.dart';

Future<void> mostrarDialogoRegistrarPago({
  required BuildContext context,
  required CobroRuta cobro,
  required bool puedeAgregarCuota,
  required List<MedioPago> mediosPago,
  required List<CobroRuta> cobrosRuta,
  required Set<String> cuotasEnPago,
  required String? rutaFiltroId,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required Future<void> Function(List<PagoRutaSolicitud>) onRegistrarPagos,
}) async {
  if (!puedeAgregarCuota) {
    mostrarMensaje('No tienes permiso para agregar cuota');
    return;
  }

  if (mediosPago.isEmpty) {
    mostrarMensaje('No hay medios de pago registrados');
    return;
  }

  final List<CobroRuta> cobrosDisponibles = cobrosRuta
      .where(
        (CobroRuta item) =>
            item.proximaCuotaId != null &&
            item.saldo > 0.009 &&
            (rutaFiltroId == null || item.rutaId == rutaFiltroId),
      )
      .toList(growable: false);
  final TextEditingController observacionController = TextEditingController();
  final List<PagoRutaSeleccion> seleccionados = <PagoRutaSeleccion>[
    PagoRutaSeleccion(cobro),
  ];

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      String medioPagoCodigo = mediosPago.first.codigo;
      bool guardandoPago = false;

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final Set<String> cuotasSeleccionadas = seleccionados
              .map((PagoRutaSeleccion item) => item.cuotaId)
              .whereType<String>()
              .toSet();

          return AlertDialog(
            title: const Text('Registrar pagos'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SelectorCobroRutaBuscable(
                      cobros: cobrosDisponibles,
                      cuotasSeleccionadas: cuotasSeleccionadas,
                      enabled: !guardandoPago,
                      onSelected: (CobroRuta item) {
                        if (cuotasSeleccionadas.contains(item.proximaCuotaId)) {
                          return;
                        }
                        seleccionados.add(PagoRutaSeleccion(item));
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 14),
                    ...seleccionados.map(
                      (PagoRutaSeleccion item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClaySurface(
                          radius: 12,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          item.cobro.cliente,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          <String>[
                                            if ((item.cobro.cedula ?? '')
                                                .isNotEmpty)
                                              'CC ${item.cobro.cedula!}',
                                            'Cuota ${item.cobro.proximaNumeroCuota ?? '-'}',
                                            formatDateLabel(
                                              item.cobro.proximaFechaPago,
                                            ),
                                          ].join(' - '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: context.clay.subtleText,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (seleccionados.length > 1)
                                    IconButton(
                                      tooltip: 'Quitar',
                                      onPressed: guardandoPago
                                          ? null
                                          : () {
                                              seleccionados.remove(item);
                                              setDialogState(() {});
                                            },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: item.montoController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Monto de ${item.cobro.cliente}',
                                  prefixIcon:
                                      const Icon(Icons.payments_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectorMedioPagoBuscable(
                      mediosPago: mediosPago,
                      medioPagoCodigo: medioPagoCodigo,
                      enabled: !guardandoPago,
                      onChanged: (String value) {
                        setDialogState(() => medioPagoCodigo = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: observacionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observacion',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: guardandoPago
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (guardandoPago) {
                    return;
                  }
                  if (seleccionados.isEmpty) {
                    mostrarMensaje('Agrega al menos un cliente');
                    return;
                  }

                  final String? observacion =
                      observacionController.text.trim().isEmpty
                          ? null
                          : observacionController.text.trim();
                  final List<PagoRutaSolicitud> pagos = <PagoRutaSolicitud>[];

                  for (final PagoRutaSeleccion item in seleccionados) {
                    final String? cuotaId = item.cuotaId;
                    if (cuotaId == null || cuotasEnPago.contains(cuotaId)) {
                      mostrarMensaje('Este pago ya se esta procesando');
                      return;
                    }

                    final double monto;
                    try {
                      monto = parseMontoInput(item.montoController.text);
                    } catch (error) {
                      mostrarMensaje(mensajeError(error));
                      return;
                    }

                    if (monto > item.cobro.saldo) {
                      mostrarMensaje(
                        'El pago de ${item.cobro.cliente} supera el saldo',
                      );
                      return;
                    }

                    pagos.add(
                      PagoRutaSolicitud(
                        cuotaId: cuotaId,
                        monto: monto,
                        medioPagoCodigo: medioPagoCodigo,
                        observacion: observacion,
                      ),
                    );
                  }

                  setDialogState(() => guardandoPago = true);

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }

                  unawaited(onRegistrarPagos(pagos));
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Registrar'),
              ),
            ],
          );
        },
      );
    },
  );
}
