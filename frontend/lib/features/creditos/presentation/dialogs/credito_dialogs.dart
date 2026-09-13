import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/modal_layouts.dart';
import '../../../../data/models/models.dart';
import '../widgets/calculo_credito.dart';
import '../widgets/formulario_credito.dart';

CreditoRegistro creditoOptimistaModificado({
  required CreditoRegistro credito,
  required Catalogos catalogos,
  required List<Cliente> clientes,
  required String clienteId,
  required String? rutaId,
  required String cajaMenorId,
  required int frecuenciaPagoId,
  required DateTime fechaInicio,
  required double valorPrincipal,
  required double porcentajeInteres,
  required int plazoDias,
  required bool omitirDomingos,
  required String? observacion,
}) {
  final Cliente cliente = clientes.firstWhere(
    (Cliente item) => item.id == clienteId,
    orElse: () => Cliente(
      id: credito.clienteId,
      nombreCompleto: credito.cliente,
      cedula: credito.cedula,
      direccion: credito.direccion,
      nombreComercial: credito.negocio,
      estadoNombre: 'Activo',
    ),
  );
  final RutaCatalogo? ruta = rutaId == null
      ? null
      : catalogos.rutas.firstWhere(
          (RutaCatalogo item) => item.id == rutaId,
          orElse: () => RutaCatalogo(
            id: credito.rutaId,
            nombre: credito.ruta,
            estadoCodigo: 'ABIERTA',
          ),
        );
  final CajaMenorCatalogo caja = catalogos.cajasMenores.firstWhere(
    (CajaMenorCatalogo item) => item.id == cajaMenorId,
    orElse: () => CajaMenorCatalogo(
      id: credito.cajaMenorId ?? cajaMenorId,
      nombre: credito.cajaMenor ?? '',
      activa: true,
      monedaCodigo: credito.monedaCodigo,
    ),
  );
  final FrecuenciaPago frecuencia = catalogos.frecuenciasPago.firstWhere(
    (FrecuenciaPago item) => item.id == frecuenciaPagoId,
    orElse: () => credito.frecuenciaPago,
  );
  final bool cambiaPlan = frecuencia.id != credito.frecuenciaPago.id ||
      formatDateValue(fechaInicio) != formatDateValue(credito.fechaInicio) ||
      valorPrincipal != credito.valorPrincipal ||
      porcentajeInteres != credito.porcentajeInteres ||
      plazoDias != credito.plazoDias ||
      omitirDomingos != credito.omitirDomingos;
  final CalculoCredito calculo = CalculoCredito.desdeFormulario(
    valor: valorPrincipal.toString(),
    interes: porcentajeInteres.toString(),
    plazo: plazoDias.toString(),
    fechaInicio: fechaInicio,
    diasIntervalo: frecuencia.diasIntervalo,
    omitirDomingos: omitirDomingos,
  );

  return credito.copyWith(
    clienteId: cliente.id,
    cliente: cliente.nombreCompleto,
    cedula: cliente.cedula,
    negocio: cliente.nombreComercial,
    direccion: cliente.direccion,
    rutaId: ruta?.id ?? credito.rutaId,
    ruta: ruta?.nombre ?? credito.ruta,
    cajaMenorId: caja.id,
    cajaMenor: caja.nombre,
    frecuenciaPago: frecuencia,
    fechaInicio: fechaInicio,
    valorPrincipal: valorPrincipal,
    porcentajeInteres: porcentajeInteres,
    plazoDias: plazoDias,
    omitirDomingos: omitirDomingos,
    valorTotal: cambiaPlan ? calculo.valorTotal : credito.valorTotal,
    valorCuota: cambiaPlan ? calculo.valorCuota : credito.valorCuota,
    saldo: cambiaPlan
        ? math.max(0.0, calculo.valorTotal - credito.totalAbonado)
        : credito.saldo,
    numeroCuotas: cambiaPlan ? calculo.numeroCuotas : credito.numeroCuotas,
    cuotasRestantes:
        cambiaPlan ? calculo.numeroCuotas : credito.cuotasRestantes,
    fechaMaxima: cambiaPlan ? calculo.fechaMaxima : credito.fechaMaxima,
    observacion: observacion,
  );
}

Future<void> mostrarDialogoCrearCredito({
  required BuildContext context,
  required ApiClient apiClient,
  required Catalogos? catalogos,
  required List<Cliente> clientes,
  required List<CreditoRegistro> creditos,
  required bool puedeCrearCreditos,
  required Future<void> Function() onAbrirCrearClienteConCredito,
  required String Function(Catalogos?) mensajeDatosBaseCredito,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(CreditoRegistro) guardarCreditoLocal,
  required Future<void> Function(OfflineMutationQueuedException)
      marcarAccionOfflinePendiente,
  VoidCallback? mostrarCuotasRegistradas,
  required void Function({
    bool catalogos,
    bool presupuesto,
    bool cobrosRuta,
    bool creditos,
    bool movimientosCaja,
  }) recargarEnSegundoPlano,
  bool Function(String, double)? validarPresupuestoCaja,
}) async {
  if (!puedeCrearCreditos) {
    mostrarMensaje('No tienes permiso para crear creditos');
    return;
  }

  final bool listo = catalogos != null &&
      clientes.isNotEmpty &&
      catalogos.frecuenciasPago.isNotEmpty &&
      catalogos.monedas.isNotEmpty &&
      catalogos.cajasMenoresActivas.isNotEmpty;

  if (!listo) {
    final bool puedeCrearClienteConCredito = catalogos != null &&
        clientes.isEmpty &&
        catalogos.frecuenciasPago.isNotEmpty &&
        catalogos.monedas.isNotEmpty &&
        catalogos.cajasMenoresActivas.isNotEmpty;

    if (puedeCrearClienteConCredito) {
      await onAbrirCrearClienteConCredito();
      return;
    }

    mostrarMensaje(mensajeDatosBaseCredito(catalogos));
    return;
  }

  final TextEditingController valorCreditoController = TextEditingController();
  final TextEditingController interesController =
      TextEditingController(text: '20');
  final TextEditingController plazoController =
      TextEditingController(text: '30');
  final TextEditingController observacionCreditoController =
      TextEditingController();
  final Map<String, TextEditingController> valorClienteControllers =
      <String, TextEditingController>{};

  TextEditingController valorClienteController(String id) {
    return valorClienteControllers.putIfAbsent(
      id,
      () => TextEditingController(text: valorCreditoController.text),
    );
  }

  String? clienteId = clientes.first.id;
  final Set<String> clientesSeleccionadosIds = <String>{clientes.first.id};
  String? rutaId = catalogos.rutasAbiertas.isNotEmpty
      ? catalogos.rutasAbiertas.first.id
      : null;
  String? monedaCodigo = catalogos.monedas.first.codigo;
  int? frecuenciaPagoId = catalogos.frecuenciasPago.first.id;
  String? cajaMenorId = catalogos.cajasMenoresActivas.first.id;
  DateTime fechaInicio = DateTime.now();
  bool omitirDomingos = true;

  try {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        bool guardandoDialogo = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo crédito'),
              content: DialogContent(
                maxWidth: 760,
                child: FormularioCredito(
                  clientes: clientes,
                  rutas: catalogos.rutasAbiertas,
                  monedas: catalogos.monedas,
                  frecuencias: catalogos.frecuenciasPago,
                  cajasMenores: catalogos.cajasMenoresActivas,
                  clienteId: clienteId,
                  rutaId: rutaId,
                  monedaCodigo: monedaCodigo,
                  frecuenciaPagoId: frecuenciaPagoId,
                  cajaMenorId: cajaMenorId,
                  fechaInicio: fechaInicio,
                  omitirDomingos: omitirDomingos,
                  valorController: valorCreditoController,
                  clientesSeleccionadosIds: clientesSeleccionadosIds,
                  valorClienteController: valorClienteController,
                  interesController: interesController,
                  plazoController: plazoController,
                  observacionController: observacionCreditoController,
                  guardando: guardandoDialogo,
                  onClienteChanged: (String? value) {
                    setDialogState(() => clienteId = value);
                  },
                  onRutaChanged: (String? value) {
                    setDialogState(() => rutaId = value);
                  },
                  onMonedaChanged: (String? value) {
                    setDialogState(() => monedaCodigo = value);
                  },
                  onFrecuenciaChanged: (int? value) {
                    setDialogState(() => frecuenciaPagoId = value);
                  },
                  onCajaMenorChanged: (String? value) {
                    setDialogState(() => cajaMenorId = value);
                  },
                  onFechaChanged: (DateTime value) {
                    setDialogState(() => fechaInicio = value);
                  },
                  onOmitirDomingosChanged: (bool value) {
                    setDialogState(() => omitirDomingos = value);
                  },
                  onCrear: () async {
                    if (guardandoDialogo) return;

                    final List<String> clienteIds = <String>[
                      if (clienteId != null) clienteId!,
                    ];

                    if (clienteIds.isEmpty ||
                        monedaCodigo == null ||
                        frecuenciaPagoId == null) {
                      mostrarMensaje(
                          'Faltan datos reales para crear el credito');
                      return;
                    }

                    if (cajaMenorId == null) {
                      mostrarMensaje(
                          'No se puede hacer credito sin caja menor');
                      return;
                    }

                    final double porcentajeInteres;
                    final int plazoDias;
                    final Map<String, double> valoresPorCliente =
                        <String, double>{};

                    try {
                      for (final String cId in clienteIds) {
                        final String montoTexto = clienteIds.length == 1
                            ? valorCreditoController.text
                            : valorClienteController(cId).text;
                        valoresPorCliente[cId] = parseMontoInput(montoTexto);
                      }
                      porcentajeInteres =
                          parseNumero(interesController.text) ?? 0.0;
                      plazoDias = int.parse(plazoController.text.trim());
                    } catch (error) {
                      mostrarMensaje(mensajeError(error));
                      return;
                    }

                    final double valorPrincipalTotal =
                        valoresPorCliente.values.fold<double>(
                      0,
                      (double total, double valor) => total + valor,
                    );

                    if (validarPresupuestoCaja != null &&
                        !validarPresupuestoCaja(
                            cajaMenorId!, valorPrincipalTotal)) {
                      return;
                    }

                    setDialogState(() => guardandoDialogo = true);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                    mostrarMensaje(
                      clienteIds.length == 1
                          ? 'Creando credito...'
                          : 'Creando creditos...',
                    );

                    await ejecutarAccion(() async {
                      int creados = 0;
                      int pendientes = 0;
                      for (final String cId in clienteIds) {
                        try {
                          final CreditoRegistro creditoCreado =
                              CreditoRegistro.fromJson(
                            await apiClient.postObject(
                              '/creditos',
                              <String, dynamic>{
                                'clienteId': cId,
                                if (rutaId != null) 'rutaId': rutaId,
                                'monedaCodigo': monedaCodigo,
                                'frecuenciaPagoId': frecuenciaPagoId,
                                'fechaInicio': formatDateValue(fechaInicio),
                                'valorPrincipal': valoresPorCliente[cId] ?? 0.0,
                                'porcentajeInteres': porcentajeInteres,
                                'plazoDias': plazoDias,
                                'omitirDomingos': omitirDomingos,
                                'cajaMenorId': cajaMenorId,
                                if (observacionCreditoController.text
                                    .trim()
                                    .isNotEmpty)
                                  'observacion':
                                      observacionCreditoController.text.trim(),
                              },
                              queueOffline: true,
                            ),
                          );
                          creados++;
                          guardarCreditoLocal(creditoCreado);
                        } on OfflineMutationQueuedException catch (error) {
                          pendientes++;
                          await marcarAccionOfflinePendiente(error);
                        }
                      }

                      if (creados > 0 || pendientes > 0) {
                        mostrarCuotasRegistradas?.call();
                      }

                      recargarEnSegundoPlano(
                        catalogos: false,
                        presupuesto: true,
                        cobrosRuta: true,
                        creditos: true,
                        movimientosCaja: true,
                      );

                      if (creados > 0 && pendientes > 0) {
                        mostrarMensaje(
                          '$creados credito(s) creado(s). $pendientes guardado(s) offline.',
                        );
                      } else if (creados > 1) {
                        mostrarMensaje(
                            '$creados creditos creados exitosamente');
                      } else if (creados == 1) {
                        mostrarMensaje('Credito creado exitosamente');
                      }
                    });
                  },
                  usarSuperficie: false,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: guardandoDialogo
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    valorCreditoController.dispose();
    interesController.dispose();
    plazoController.dispose();
    observacionCreditoController.dispose();
    for (final TextEditingController c in valorClienteControllers.values) {
      c.dispose();
    }
  }
}

Future<void> mostrarDialogoSeleccionRefinanciacion({
  required BuildContext context,
  required bool puedeRefinanciar,
  required List<CreditoRegistro> creditosActivos,
  required void Function(String) mostrarMensaje,
  required Future<void> Function(CreditoRegistro) onRefinanciarCredito,
}) async {
  if (!puedeRefinanciar) {
    mostrarMensaje('No tienes permiso para refinanciar creditos');
    return;
  }

  if (creditosActivos.isEmpty) {
    mostrarMensaje('No hay creditos activos para refinanciar');
    return;
  }

  final CreditoRegistro? seleccionado = await showDialog<CreditoRegistro>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Refinanciar credito'),
        content: DialogContent(
          maxWidth: 520,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemBuilder: (BuildContext context, int index) {
                final CreditoRegistro credito = creditosActivos[index];
                return ListTile(
                  leading: const Icon(Icons.currency_exchange_rounded),
                  title: Text(
                    credito.cliente,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${formatMoney(credito.valorPrincipal)} - ${credito.ruta}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(dialogContext).pop(credito),
                );
              },
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(height: 1),
              itemCount: creditosActivos.length,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      );
    },
  );

  if (seleccionado != null) {
    await onRefinanciarCredito(seleccionado);
  }
}

Future<void> mostrarDialogoRefinanciarCredito({
  required BuildContext context,
  required CreditoRegistro credito,
  required bool puedeRefinanciar,
  required Catalogos? catalogos,
  required List<Cliente> clientes,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required bool Function(String, double) validarPresupuestoCaja,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(CreditoRegistro) onGuardarCreditoLocal,
  required void Function({
    bool catalogos,
    bool presupuesto,
    bool cobrosRuta,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano,
}) async {
  if (!puedeRefinanciar) {
    mostrarMensaje('No tienes permiso para refinanciar creditos');
    return;
  }

  if (!credito.activo) {
    mostrarMensaje('Solo se pueden refinanciar creditos activos');
    return;
  }

  if (catalogos == null ||
      catalogos.frecuenciasPago.isEmpty ||
      catalogos.cajasMenoresActivas.isEmpty) {
    mostrarMensaje('Necesitas catalogos y caja menor activa');
    return;
  }

  final List<CajaMenorCatalogo> cajasCompatibles = catalogos.cajasMenoresActivas
      .where(
        (CajaMenorCatalogo caja) => caja.monedaCodigo == credito.monedaCodigo,
      )
      .toList(growable: false);
  if (cajasCompatibles.isEmpty) {
    mostrarMensaje('No hay caja menor activa para esa moneda');
    return;
  }

  final TextEditingController valorController = TextEditingController(
    text: formatNumber(credito.valorPrincipal),
  );
  final TextEditingController interesController = TextEditingController(
    text: formatNumber(credito.porcentajeInteres),
  );
  final TextEditingController plazoController = TextEditingController(
    text: credito.plazoDias.toString(),
  );
  final TextEditingController observacionController = TextEditingController(
    text: credito.observacion ?? '',
  );

  String? rutaId = catalogos.rutasAbiertas
          .any((RutaCatalogo ruta) => ruta.id == credito.rutaId)
      ? credito.rutaId
      : null;
  String? cajaMenorId = cajasCompatibles
          .any((CajaMenorCatalogo caja) => caja.id == credito.cajaMenorId)
      ? credito.cajaMenorId
      : cajasCompatibles.first.id;
  int? frecuenciaPagoId = catalogos.frecuenciasPago.any(
    (FrecuenciaPago frecuencia) => frecuencia.id == credito.frecuenciaPago.id,
  )
      ? credito.frecuenciaPago.id
      : catalogos.frecuenciasPago.first.id;
  DateTime fechaInicio = DateTime.now();
  bool omitirDomingos = credito.omitirDomingos;
  final List<Cliente> clientesFormulario =
      clientes.any((Cliente cliente) => cliente.id == credito.clienteId)
          ? clientes
          : <Cliente>[
              Cliente(
                id: credito.clienteId,
                nombreCompleto: credito.cliente,
                cedula: credito.cedula,
                direccion: credito.direccion,
                nombreComercial: credito.negocio,
                estadoNombre: 'Activo',
              ),
              ...clientes,
            ];
  final List<Moneda> monedasFormulario = catalogos.monedas
          .any((Moneda moneda) => moneda.codigo == credito.monedaCodigo)
      ? catalogos.monedas
          .where((Moneda moneda) => moneda.codigo == credito.monedaCodigo)
          .toList(growable: false)
      : <Moneda>[
          Moneda(
            codigo: credito.monedaCodigo,
            nombre: credito.monedaCodigo,
          ),
        ];

  try {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        bool guardandoDialogo = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Refinanciar ${credito.cliente}'),
              content: DialogContent(
                maxWidth: 600,
                child: FormularioCredito(
                  clientes: clientesFormulario,
                  rutas: catalogos.rutasAbiertas,
                  monedas: monedasFormulario,
                  frecuencias: catalogos.frecuenciasPago,
                  cajasMenores: cajasCompatibles,
                  clienteId: credito.clienteId,
                  rutaId: rutaId,
                  monedaCodigo: credito.monedaCodigo,
                  frecuenciaPagoId: frecuenciaPagoId,
                  cajaMenorId: cajaMenorId,
                  fechaInicio: fechaInicio,
                  omitirDomingos: omitirDomingos,
                  valorController: valorController,
                  interesController: interesController,
                  plazoController: plazoController,
                  observacionController: observacionController,
                  guardando: guardandoDialogo,
                  clienteBloqueado: true,
                  monedaBloqueada: true,
                  accionLabel: 'Refinanciar',
                  usarSuperficie: false,
                  onClienteChanged: (_) {},
                  onRutaChanged: (String? value) {
                    setDialogState(() => rutaId = value);
                  },
                  onMonedaChanged: (_) {},
                  onFrecuenciaChanged: (int? value) {
                    setDialogState(() => frecuenciaPagoId = value);
                  },
                  onCajaMenorChanged: (String? value) {
                    setDialogState(() => cajaMenorId = value);
                  },
                  onFechaChanged: (DateTime value) {
                    setDialogState(() => fechaInicio = value);
                  },
                  onOmitirDomingosChanged: (bool value) {
                    setDialogState(() => omitirDomingos = value);
                  },
                  onCrear: () async {
                    if (guardandoDialogo) {
                      return;
                    }

                    final String? cajaId = cajaMenorId;
                    final int? frecuenciaId = frecuenciaPagoId;
                    if (cajaId == null || frecuenciaId == null) {
                      mostrarMensaje('Faltan datos para refinanciar');
                      return;
                    }

                    final double valorNuevo;
                    final double porcentajeInteres;
                    final int plazoDias;
                    try {
                      valorNuevo = parseMontoInput(valorController.text);
                      porcentajeInteres =
                          parsePorcentajeInput(interesController.text);
                      plazoDias =
                          parseEnteroPositivoInput(plazoController.text);
                    } catch (error) {
                      mostrarMensaje(mensajeError(error));
                      return;
                    }

                    if (valorNuevo <= credito.valorPrincipal) {
                      mostrarMensaje(
                        'El nuevo valor debe superar el valor actual',
                      );
                      return;
                    }

                    final double incremento =
                        valorNuevo - credito.valorPrincipal;
                    if (!validarPresupuestoCaja(cajaId, incremento)) {
                      return;
                    }

                    setDialogState(() => guardandoDialogo = true);
                    final bool refinanciado = await ejecutarAccion(
                      () async {
                        final CreditoRegistro actualizado =
                            CreditoRegistro.fromJson(
                          await apiClient.patchObject(
                            '/creditos/${credito.id}/refinanciar',
                            <String, dynamic>{
                              if (rutaId != null) 'rutaId': rutaId,
                              'monedaCodigo': credito.monedaCodigo,
                              'frecuenciaPagoId': frecuenciaId,
                              'fechaInicio': formatDateValue(fechaInicio),
                              'valorPrincipal': valorNuevo,
                              'porcentajeInteres': porcentajeInteres,
                              'plazoDias': plazoDias,
                              'omitirDomingos': omitirDomingos,
                              'cajaMenorId': cajaId,
                              if (observacionController.text.trim().isNotEmpty)
                                'observacion':
                                    observacionController.text.trim(),
                            },
                            queueOffline: true,
                          ),
                        );
                        onGuardarCreditoLocal(actualizado);
                        onRecargarEnSegundoPlano(
                          catalogos: rutaId == null,
                          presupuesto: true,
                          cobrosRuta: true,
                          movimientosCaja: true,
                        );
                      },
                    );

                    if (!dialogContext.mounted) {
                      return;
                    }

                    if (refinanciado) {
                      Navigator.of(dialogContext).pop(true);
                      mostrarMensaje('Credito refinanciado');
                      return;
                    }

                    setDialogState(() => guardandoDialogo = false);
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: guardandoDialogo
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    valorController.dispose();
    interesController.dispose();
    plazoController.dispose();
    observacionController.dispose();
  }
}

Future<void> mostrarDialogoModificarCredito({
  required BuildContext context,
  required CreditoRegistro credito,
  required bool puedeModificar,
  required Catalogos? catalogos,
  required List<Cliente> clientes,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required void Function(String) setError,
  required void Function(CreditoRegistro) onGuardarCreditoLocal,
  required Future<void> Function(OfflineMutationQueuedException)
      onMarcarAccionOfflinePendiente,
  required void Function({
    bool catalogos,
    bool presupuesto,
    bool cobrosRuta,
    bool creditos,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano,
}) async {
  if (!puedeModificar) {
    mostrarMensaje('No tienes permiso para modificar creditos');
    return;
  }

  if (catalogos == null ||
      catalogos.frecuenciasPago.isEmpty ||
      catalogos.cajasMenoresActivas.isEmpty) {
    mostrarMensaje('Necesitas catalogos y caja menor activa');
    return;
  }

  final List<CajaMenorCatalogo> cajasCompatibles = catalogos.cajasMenoresActivas
      .where(
        (CajaMenorCatalogo caja) => caja.monedaCodigo == credito.monedaCodigo,
      )
      .toList(growable: false);
  if (cajasCompatibles.isEmpty) {
    mostrarMensaje('No hay caja menor activa para esa moneda');
    return;
  }

  final TextEditingController valorController = TextEditingController(
    text: formatNumber(credito.valorPrincipal),
  );
  final TextEditingController interesController = TextEditingController(
    text: formatNumber(credito.porcentajeInteres),
  );
  final TextEditingController plazoController = TextEditingController(
    text: credito.plazoDias.toString(),
  );
  final TextEditingController observacionController = TextEditingController(
    text: credito.observacion ?? '',
  );

  String? clienteId = credito.clienteId;
  String? rutaId = catalogos.rutasAbiertas
          .any((RutaCatalogo ruta) => ruta.id == credito.rutaId)
      ? credito.rutaId
      : null;
  String? cajaMenorId = cajasCompatibles
          .any((CajaMenorCatalogo caja) => caja.id == credito.cajaMenorId)
      ? credito.cajaMenorId
      : cajasCompatibles.first.id;
  int? frecuenciaPagoId = catalogos.frecuenciasPago.any(
    (FrecuenciaPago frecuencia) => frecuencia.id == credito.frecuenciaPago.id,
  )
      ? credito.frecuenciaPago.id
      : catalogos.frecuenciasPago.first.id;
  DateTime fechaInicio = credito.fechaInicio;
  bool omitirDomingos = credito.omitirDomingos;
  final List<Cliente> clientesFormulario =
      clientes.any((Cliente cliente) => cliente.id == credito.clienteId)
          ? clientes
          : <Cliente>[
              Cliente(
                id: credito.clienteId,
                nombreCompleto: credito.cliente,
                cedula: credito.cedula,
                direccion: credito.direccion,
                nombreComercial: credito.negocio,
                estadoNombre: 'Activo',
              ),
              ...clientes,
            ];
  final List<Moneda> monedasFormulario = catalogos.monedas
          .any((Moneda moneda) => moneda.codigo == credito.monedaCodigo)
      ? catalogos.monedas
          .where((Moneda moneda) => moneda.codigo == credito.monedaCodigo)
          .toList(growable: false)
      : <Moneda>[
          Moneda(
            codigo: credito.monedaCodigo,
            nombre: credito.monedaCodigo,
          ),
        ];

  try {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        bool guardandoDialogo = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Modificar ${credito.cliente}'),
              content: DialogContent(
                maxWidth: 600,
                child: FormularioCredito(
                  clientes: clientesFormulario,
                  rutas: catalogos.rutasAbiertas,
                  monedas: monedasFormulario,
                  frecuencias: catalogos.frecuenciasPago,
                  cajasMenores: cajasCompatibles,
                  clienteId: clienteId,
                  rutaId: rutaId,
                  monedaCodigo: credito.monedaCodigo,
                  frecuenciaPagoId: frecuenciaPagoId,
                  cajaMenorId: cajaMenorId,
                  fechaInicio: fechaInicio,
                  omitirDomingos: omitirDomingos,
                  valorController: valorController,
                  interesController: interesController,
                  plazoController: plazoController,
                  observacionController: observacionController,
                  guardando: guardandoDialogo,
                  monedaBloqueada: true,
                  accionLabel: 'Guardar',
                  usarSuperficie: false,
                  onClienteChanged: (String? value) {
                    setDialogState(() => clienteId = value);
                  },
                  onRutaChanged: (String? value) {
                    setDialogState(() => rutaId = value);
                  },
                  onMonedaChanged: (_) {},
                  onFrecuenciaChanged: (int? value) {
                    setDialogState(() => frecuenciaPagoId = value);
                  },
                  onCajaMenorChanged: (String? value) {
                    setDialogState(() => cajaMenorId = value);
                  },
                  onFechaChanged: (DateTime value) {
                    setDialogState(() => fechaInicio = value);
                  },
                  onOmitirDomingosChanged: (bool value) {
                    setDialogState(() => omitirDomingos = value);
                  },
                  onCrear: () async {
                    if (guardandoDialogo) {
                      return;
                    }

                    final String? clienteSeleccionado = clienteId;
                    final String? cajaId = cajaMenorId;
                    final int? frecuenciaId = frecuenciaPagoId;
                    if (clienteSeleccionado == null ||
                        cajaId == null ||
                        frecuenciaId == null) {
                      mostrarMensaje('Faltan datos para modificar');
                      return;
                    }

                    final double valorPrincipal;
                    final double porcentajeInteres;
                    final int plazoDias;
                    try {
                      valorPrincipal = parseMontoInput(valorController.text);
                      porcentajeInteres =
                          parsePorcentajeInput(interesController.text);
                      plazoDias =
                          parseEnteroPositivoInput(plazoController.text);
                    } catch (error) {
                      mostrarMensaje(mensajeError(error));
                      return;
                    }

                    final bool cambiaCondicionesFinancieras =
                        frecuenciaId != credito.frecuenciaPago.id ||
                            formatDateValue(fechaInicio) !=
                                formatDateValue(credito.fechaInicio) ||
                            valorPrincipal != credito.valorPrincipal ||
                            porcentajeInteres != credito.porcentajeInteres ||
                            plazoDias != credito.plazoDias ||
                            omitirDomingos != credito.omitirDomingos;
                    if (credito.totalAbonado > 0.009 &&
                        cambiaCondicionesFinancieras) {
                      mostrarMensaje(
                        'No se pueden modificar valor, interes, plazo, frecuencia, fecha u omitir domingos en un credito con pagos registrados',
                      );
                      return;
                    }

                    final String observacion =
                        observacionController.text.trim();
                    final Map<String, dynamic> payload = <String, dynamic>{
                      'clienteId': clienteSeleccionado,
                      if (rutaId != null) 'rutaId': rutaId,
                      'monedaCodigo': credito.monedaCodigo,
                      'frecuenciaPagoId': frecuenciaId,
                      'fechaInicio': formatDateValue(fechaInicio),
                      'valorPrincipal': valorPrincipal,
                      'porcentajeInteres': porcentajeInteres,
                      'plazoDias': plazoDias,
                      'omitirDomingos': omitirDomingos,
                      'cajaMenorId': cajaId,
                      if (observacion.isNotEmpty) 'observacion': observacion,
                    };
                    final CreditoRegistro optimista =
                        creditoOptimistaModificado(
                      credito: credito,
                      catalogos: catalogos,
                      clientes: clientes,
                      clienteId: clienteSeleccionado,
                      rutaId: rutaId,
                      cajaMenorId: cajaId,
                      frecuenciaPagoId: frecuenciaId,
                      fechaInicio: fechaInicio,
                      valorPrincipal: valorPrincipal,
                      porcentajeInteres: porcentajeInteres,
                      plazoDias: plazoDias,
                      omitirDomingos: omitirDomingos,
                      observacion: observacion.isEmpty ? null : observacion,
                    );
                    setDialogState(() => guardandoDialogo = true);
                    onGuardarCreditoLocal(optimista);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                      mostrarMensaje('Credito modificado');
                    }

                    unawaited(() async {
                      try {
                        final CreditoRegistro respuesta =
                            CreditoRegistro.fromJson(
                          await apiClient.patchObject(
                            '/creditos/${credito.id}',
                            payload,
                            queueOffline: true,
                          ),
                        );
                        onGuardarCreditoLocal(respuesta);
                        onRecargarEnSegundoPlano(
                          catalogos: rutaId == null,
                          presupuesto: true,
                          cobrosRuta: true,
                          creditos: true,
                          movimientosCaja: true,
                        );
                      } on OfflineMutationQueuedException catch (error) {
                        await onMarcarAccionOfflinePendiente(error);
                      } catch (error) {
                        setError(mensajeError(error));
                        onGuardarCreditoLocal(credito);
                        mostrarMensaje(mensajeError(error));
                      }
                    }());
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: guardandoDialogo
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    valorController.dispose();
    interesController.dispose();
    plazoController.dispose();
    observacionController.dispose();
  }
}

Future<void> mostrarDialogoEliminarCredito({
  required BuildContext context,
  required CreditoRegistro credito,
  required bool puedeEliminar,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(String) onEliminarCreditoLocal,
  required void Function(CreditoRegistro) onRestaurarCreditoLocal,
  required Future<void> Function(OfflineMutationQueuedException)
      onMarcarAccionOfflinePendiente,
  required void Function({
    bool catalogos,
    bool presupuesto,
    bool cobrosRuta,
    bool creditos,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano,
}) async {
  if (!puedeEliminar) {
    mostrarMensaje('No tienes permiso para eliminar creditos');
    return;
  }

  final bool? confirmado = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('¿Seguro que quieres eliminar?'),
        content: Text(
          'Se eliminara el credito de "${credito.cliente}" y la caja quedara como estaba antes de hacer el credito.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar'),
          ),
        ],
      );
    },
  );

  if (confirmado != true) {
    return;
  }

  final bool eliminado = await ejecutarAccion(() async {
    onEliminarCreditoLocal(credito.id);
    try {
      await apiClient.deleteObject(
        '/creditos/${credito.id}',
        queueOffline: true,
      );
    } on OfflineMutationQueuedException catch (error) {
      await onMarcarAccionOfflinePendiente(error);
    } catch (_) {
      onRestaurarCreditoLocal(credito);
      rethrow;
    }
    onRecargarEnSegundoPlano(
      catalogos: false,
      presupuesto: true,
      cobrosRuta: true,
      creditos: true,
      movimientosCaja: true,
    );
  });

  if (eliminado) {
    mostrarMensaje('Credito eliminado');
  }
}
