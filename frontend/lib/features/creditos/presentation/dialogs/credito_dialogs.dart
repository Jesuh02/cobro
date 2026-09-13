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

class _DialogoCrearCreditoContent extends StatefulWidget {
  const _DialogoCrearCreditoContent({
    required this.catalogos,
    required this.clientes,
    required this.creditos,
    required this.apiClient,
    required this.mostrarMensaje,
    required this.mensajeError,
    required this.ejecutarAccion,
    required this.guardarCreditoLocal,
    required this.marcarAccionOfflinePendiente,
    this.mostrarCuotasRegistradas,
    required this.recargarEnSegundoPlano,
    this.validarPresupuestoCaja,
    this.defaultCajaMenorId,
  });

  final Catalogos catalogos;
  final List<Cliente> clientes;
  final List<CreditoRegistro> creditos;
  final ApiClient apiClient;
  final void Function(String) mostrarMensaje;
  final String Function(Object) mensajeError;
  final Future<bool> Function(Future<void> Function()) ejecutarAccion;
  final void Function(CreditoRegistro) guardarCreditoLocal;
  final Future<void> Function(OfflineMutationQueuedException)
      marcarAccionOfflinePendiente;
  final VoidCallback? mostrarCuotasRegistradas;
  final void Function({
    bool catalogos,
    bool presupuesto,
    bool cobrosRuta,
    bool creditos,
    bool movimientosCaja,
  }) recargarEnSegundoPlano;
  final bool Function(String, double)? validarPresupuestoCaja;
  final String? defaultCajaMenorId;

  @override
  State<_DialogoCrearCreditoContent> createState() =>
      _DialogoCrearCreditoContentState();
}

class _DialogoCrearCreditoContentState
    extends State<_DialogoCrearCreditoContent> {
  late final TextEditingController _valorCreditoController;
  late final TextEditingController _interesController;
  late final TextEditingController _plazoController;
  late final TextEditingController _observacionCreditoController;
  final Map<String, TextEditingController> _valorClienteControllers =
      <String, TextEditingController>{};

  TextEditingController _valorClienteController(String id) {
    return _valorClienteControllers.putIfAbsent(
      id,
      () => TextEditingController(text: _valorCreditoController.text),
    );
  }

  late String? _clienteId;
  late final Set<String> _clientesSeleccionadosIds;
  late String? _rutaId;
  late String? _monedaCodigo;
  late int? _frecuenciaPagoId;
  late String? _cajaMenorId;
  late DateTime _fechaInicio;
  late bool _omitirDomingos;
  bool _guardandoDialogo = false;

  @override
  void initState() {
    super.initState();
    _valorCreditoController = TextEditingController();
    _interesController = TextEditingController(text: '20');
    _plazoController = TextEditingController(text: '30');
    _observacionCreditoController = TextEditingController();

    _clienteId = widget.clientes.first.id;
    _clientesSeleccionadosIds = <String>{widget.clientes.first.id};
    _rutaId = widget.catalogos.rutasAbiertas.isNotEmpty
        ? widget.catalogos.rutasAbiertas.first.id
        : null;
    _monedaCodigo = widget.catalogos.monedas.first.codigo;
    _frecuenciaPagoId = widget.catalogos.frecuenciasPago.first.id;
    _cajaMenorId = widget.defaultCajaMenorId != null &&
            widget.catalogos.cajasMenoresActivas
                .any((CajaMenorCatalogo c) => c.id == widget.defaultCajaMenorId)
        ? widget.defaultCajaMenorId
        : (widget.catalogos.cajasMenoresActivas.isNotEmpty
            ? widget.catalogos.cajasMenoresActivas.first.id
            : null);
    _fechaInicio = DateTime.now();
    _omitirDomingos = true;
  }

  @override
  void dispose() {
    _valorCreditoController.dispose();
    _interesController.dispose();
    _plazoController.dispose();
    _observacionCreditoController.dispose();
    for (final TextEditingController c in _valorClienteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo crédito'),
      content: DialogContent(
        maxWidth: 760,
        child: FormularioCredito(
          clientes: widget.clientes,
          rutas: widget.catalogos.rutasAbiertas,
          monedas: widget.catalogos.monedas,
          frecuencias: widget.catalogos.frecuenciasPago,
          cajasMenores: widget.catalogos.cajasMenoresActivas,
          clienteId: _clienteId,
          rutaId: _rutaId,
          monedaCodigo: _monedaCodigo,
          frecuenciaPagoId: _frecuenciaPagoId,
          cajaMenorId: _cajaMenorId,
          fechaInicio: _fechaInicio,
          omitirDomingos: _omitirDomingos,
          valorController: _valorCreditoController,
          clientesSeleccionadosIds: _clientesSeleccionadosIds,
          valorClienteController: _valorClienteController,
          interesController: _interesController,
          plazoController: _plazoController,
          observacionController: _observacionCreditoController,
          guardando: _guardandoDialogo,
          onClienteChanged: (String? value) {
            setState(() => _clienteId = value);
          },
          onRutaChanged: (String? value) {
            setState(() => _rutaId = value);
          },
          onMonedaChanged: (String? value) {
            setState(() => _monedaCodigo = value);
          },
          onFrecuenciaChanged: (int? value) {
            setState(() => _frecuenciaPagoId = value);
          },
          onCajaMenorChanged: (String? value) {
            setState(() => _cajaMenorId = value);
          },
          onFechaChanged: (DateTime value) {
            setState(() => _fechaInicio = value);
          },
          onOmitirDomingosChanged: (bool value) {
            setState(() => _omitirDomingos = value);
          },
          onCrear: () async {
            if (_guardandoDialogo) return;

            final List<String> clienteIds = <String>[
              if (_clienteId != null) _clienteId!,
            ];

            if (clienteIds.isEmpty ||
                _monedaCodigo == null ||
                _frecuenciaPagoId == null) {
              widget.mostrarMensaje(
                  'Faltan datos reales para crear el credito');
              return;
            }

            if (_cajaMenorId == null) {
              widget.mostrarMensaje(
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
                    ? _valorCreditoController.text
                    : _valorClienteController(cId).text;
                valoresPorCliente[cId] = parseMontoInput(montoTexto);
              }
              porcentajeInteres =
                  parseNumero(_interesController.text) ?? 0.0;
              plazoDias = int.parse(_plazoController.text.trim());
            } catch (error) {
              widget.mostrarMensaje(widget.mensajeError(error));
              return;
            }

            final double valorPrincipalTotal =
                valoresPorCliente.values.fold<double>(
              0,
              (double total, double valor) => total + valor,
            );

            if (widget.validarPresupuestoCaja != null &&
                !widget.validarPresupuestoCaja!(
                    _cajaMenorId!, valorPrincipalTotal)) {
              return;
            }

            setState(() => _guardandoDialogo = true);
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
            widget.mostrarMensaje(
              clienteIds.length == 1
                  ? 'Creando credito...'
                  : 'Creando creditos...',
            );

            await widget.ejecutarAccion(() async {
              int creados = 0;
              int pendientes = 0;
              for (final String cId in clienteIds) {
                try {
                  final CreditoRegistro creditoCreado =
                      CreditoRegistro.fromJson(
                    await widget.apiClient.postObject(
                      '/creditos',
                      <String, dynamic>{
                        'clienteId': cId,
                        if (_rutaId != null) 'rutaId': _rutaId,
                        'monedaCodigo': _monedaCodigo,
                        'frecuenciaPagoId': _frecuenciaPagoId,
                        'fechaInicio': formatDateValue(_fechaInicio),
                        'valorPrincipal': valoresPorCliente[cId] ?? 0.0,
                        'porcentajeInteres': porcentajeInteres,
                        'plazoDias': plazoDias,
                        'omitirDomingos': _omitirDomingos,
                        'cajaMenorId': _cajaMenorId,
                        if (_observacionCreditoController.text
                            .trim()
                            .isNotEmpty)
                          'observacion':
                              _observacionCreditoController.text.trim(),
                      },
                      queueOffline: true,
                    ),
                  );
                  creados++;
                  widget.guardarCreditoLocal(creditoCreado);
                } on OfflineMutationQueuedException catch (error) {
                  pendientes++;
                  await widget.marcarAccionOfflinePendiente(error);
                }
              }

              if (creados > 0 || pendientes > 0) {
                widget.mostrarCuotasRegistradas?.call();
              }

              widget.recargarEnSegundoPlano(
                catalogos: false,
                presupuesto: true,
                cobrosRuta: true,
                creditos: true,
                movimientosCaja: true,
              );

              if (creados > 0 && pendientes > 0) {
                widget.mostrarMensaje(
                  '$creados credito(s) creado(s). $pendientes guardado(s) offline.',
                );
              } else if (creados > 1) {
                widget.mostrarMensaje(
                    '$creados creditos creados exitosamente');
              } else if (creados == 1) {
                widget.mostrarMensaje('Credito creado exitosamente');
              }
            });
          },
          usarSuperficie: false,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardandoDialogo
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
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
  String? defaultCajaMenorId,
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

  await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _DialogoCrearCreditoContent(
        catalogos: catalogos,
        clientes: clientes,
        creditos: creditos,
        apiClient: apiClient,
        mostrarMensaje: mostrarMensaje,
        mensajeError: mensajeError,
        ejecutarAccion: ejecutarAccion,
        guardarCreditoLocal: guardarCreditoLocal,
        marcarAccionOfflinePendiente: marcarAccionOfflinePendiente,
        mostrarCuotasRegistradas: mostrarCuotasRegistradas,
        recargarEnSegundoPlano: recargarEnSegundoPlano,
        validarPresupuestoCaja: validarPresupuestoCaja,
        defaultCajaMenorId: defaultCajaMenorId,
      );
    },
  );
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

class _DialogoRefinanciarCreditoContent extends StatefulWidget {
  const _DialogoRefinanciarCreditoContent({
    required this.credito,
    required this.catalogos,
    required this.cajasCompatibles,
    required this.clientesFormulario,
    required this.monedasFormulario,
    required this.apiClient,
    required this.mostrarMensaje,
    required this.mensajeError,
    required this.validarPresupuestoCaja,
    required this.ejecutarAccion,
    required this.onGuardarCreditoLocal,
    required this.onRecargarEnSegundoPlano,
  });

  final CreditoRegistro credito;
  final Catalogos catalogos;
  final List<CajaMenorCatalogo> cajasCompatibles;
  final List<Cliente> clientesFormulario;
  final List<Moneda> monedasFormulario;
  final ApiClient apiClient;
  final void Function(String) mostrarMensaje;
  final String Function(Object) mensajeError;
  final bool Function(String, double) validarPresupuestoCaja;
  final Future<bool> Function(Future<void> Function()) ejecutarAccion;
  final void Function(CreditoRegistro) onGuardarCreditoLocal;
  final void Function({
    bool catalogos,
    bool presupuesto,
    bool cobrosRuta,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano;

  @override
  State<_DialogoRefinanciarCreditoContent> createState() =>
      _DialogoRefinanciarCreditoContentState();
}

class _DialogoRefinanciarCreditoContentState
    extends State<_DialogoRefinanciarCreditoContent> {
  late final TextEditingController _valorController;
  late final TextEditingController _interesController;
  late final TextEditingController _plazoController;
  late final TextEditingController _observacionController;

  late String? _rutaId;
  late String? _cajaMenorId;
  late int? _frecuenciaPagoId;
  late DateTime _fechaInicio;
  late bool _omitirDomingos;
  bool _guardandoDialogo = false;

  @override
  void initState() {
    super.initState();
    _valorController = TextEditingController(
      text: formatNumber(widget.credito.valorPrincipal),
    );
    _interesController = TextEditingController(
      text: formatNumber(widget.credito.porcentajeInteres),
    );
    _plazoController = TextEditingController(
      text: widget.credito.plazoDias.toString(),
    );
    _observacionController = TextEditingController(
      text: widget.credito.observacion ?? '',
    );

    _rutaId = widget.catalogos.rutasAbiertas
            .any((RutaCatalogo ruta) => ruta.id == widget.credito.rutaId)
        ? widget.credito.rutaId
        : null;
    _cajaMenorId = widget.cajasCompatibles
            .any((CajaMenorCatalogo caja) => caja.id == widget.credito.cajaMenorId)
        ? widget.credito.cajaMenorId
        : widget.cajasCompatibles.first.id;
    _frecuenciaPagoId = widget.catalogos.frecuenciasPago.any(
      (FrecuenciaPago frecuencia) =>
          frecuencia.id == widget.credito.frecuenciaPago.id,
    )
        ? widget.credito.frecuenciaPago.id
        : widget.catalogos.frecuenciasPago.first.id;
    _fechaInicio = DateTime.now();
    _omitirDomingos = widget.credito.omitirDomingos;
  }

  @override
  void dispose() {
    _valorController.dispose();
    _interesController.dispose();
    _plazoController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Refinanciar ${widget.credito.cliente}'),
      content: DialogContent(
        maxWidth: 600,
        child: FormularioCredito(
          clientes: widget.clientesFormulario,
          rutas: widget.catalogos.rutasAbiertas,
          monedas: widget.monedasFormulario,
          frecuencias: widget.catalogos.frecuenciasPago,
          cajasMenores: widget.cajasCompatibles,
          clienteId: widget.credito.clienteId,
          rutaId: _rutaId,
          monedaCodigo: widget.credito.monedaCodigo,
          frecuenciaPagoId: _frecuenciaPagoId,
          cajaMenorId: _cajaMenorId,
          fechaInicio: _fechaInicio,
          omitirDomingos: _omitirDomingos,
          valorController: _valorController,
          interesController: _interesController,
          plazoController: _plazoController,
          observacionController: _observacionController,
          guardando: _guardandoDialogo,
          clienteBloqueado: true,
          monedaBloqueada: true,
          accionLabel: 'Refinanciar',
          usarSuperficie: false,
          onClienteChanged: (_) {},
          onRutaChanged: (String? value) {
            setState(() => _rutaId = value);
          },
          onMonedaChanged: (_) {},
          onFrecuenciaChanged: (int? value) {
            setState(() => _frecuenciaPagoId = value);
          },
          onCajaMenorChanged: (String? value) {
            setState(() => _cajaMenorId = value);
          },
          onFechaChanged: (DateTime value) {
            setState(() => _fechaInicio = value);
          },
          onOmitirDomingosChanged: (bool value) {
            setState(() => _omitirDomingos = value);
          },
          onCrear: () async {
            if (_guardandoDialogo) {
              return;
            }

            final String? cajaId = _cajaMenorId;
            final int? frecuenciaId = _frecuenciaPagoId;
            if (cajaId == null || frecuenciaId == null) {
              widget.mostrarMensaje('Faltan datos para refinanciar');
              return;
            }

            final double valorNuevo;
            final double porcentajeInteres;
            final int plazoDias;
            try {
              valorNuevo = parseMontoInput(_valorController.text);
              porcentajeInteres =
                  parsePorcentajeInput(_interesController.text);
              plazoDias =
                  parseEnteroPositivoInput(_plazoController.text);
            } catch (error) {
              widget.mostrarMensaje(widget.mensajeError(error));
              return;
            }

            if (valorNuevo <= widget.credito.valorPrincipal) {
              widget.mostrarMensaje(
                'El nuevo valor debe superar el valor actual',
              );
              return;
            }

            final double incremento =
                valorNuevo - widget.credito.valorPrincipal;
            if (!widget.validarPresupuestoCaja(cajaId, incremento)) {
              return;
            }

            setState(() => _guardandoDialogo = true);
            final bool refinanciado = await widget.ejecutarAccion(
              () async {
                final CreditoRegistro actualizado =
                    CreditoRegistro.fromJson(
                  await widget.apiClient.patchObject(
                    '/creditos/${widget.credito.id}/refinanciar',
                    <String, dynamic>{
                      if (_rutaId != null) 'rutaId': _rutaId,
                      'monedaCodigo': widget.credito.monedaCodigo,
                      'frecuenciaPagoId': frecuenciaId,
                      'fechaInicio': formatDateValue(_fechaInicio),
                      'valorPrincipal': valorNuevo,
                      'porcentajeInteres': porcentajeInteres,
                      'plazoDias': plazoDias,
                      'omitirDomingos': _omitirDomingos,
                      'cajaMenorId': cajaId,
                      if (_observacionController.text.trim().isNotEmpty)
                        'observacion':
                            _observacionController.text.trim(),
                    },
                    queueOffline: true,
                  ),
                );
                widget.onGuardarCreditoLocal(actualizado);
                widget.onRecargarEnSegundoPlano(
                  catalogos: _rutaId == null,
                  presupuesto: true,
                  cobrosRuta: true,
                  movimientosCaja: true,
                );
              },
            );

            if (!context.mounted) {
              return;
            }

            if (refinanciado) {
              Navigator.of(context).pop(true);
              widget.mostrarMensaje('Credito refinanciado');
              return;
            }

            setState(() => _guardandoDialogo = false);
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardandoDialogo
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ],
    );
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

  await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _DialogoRefinanciarCreditoContent(
        credito: credito,
        catalogos: catalogos,
        cajasCompatibles: cajasCompatibles,
        clientesFormulario: clientesFormulario,
        monedasFormulario: monedasFormulario,
        apiClient: apiClient,
        mostrarMensaje: mostrarMensaje,
        mensajeError: mensajeError,
        validarPresupuestoCaja: validarPresupuestoCaja,
        ejecutarAccion: ejecutarAccion,
        onGuardarCreditoLocal: onGuardarCreditoLocal,
        onRecargarEnSegundoPlano: onRecargarEnSegundoPlano,
      );
    },
  );
}

class _DialogoModificarCreditoContent extends StatefulWidget {
  const _DialogoModificarCreditoContent({
    required this.credito,
    required this.catalogos,
    required this.clientes,
    required this.cajasCompatibles,
    required this.clientesFormulario,
    required this.monedasFormulario,
    required this.apiClient,
    required this.mostrarMensaje,
    required this.mensajeError,
    required this.setError,
    required this.onGuardarCreditoLocal,
    required this.onMarcarAccionOfflinePendiente,
    required this.onRecargarEnSegundoPlano,
  });

  final CreditoRegistro credito;
  final Catalogos catalogos;
  final List<Cliente> clientes;
  final List<CajaMenorCatalogo> cajasCompatibles;
  final List<Cliente> clientesFormulario;
  final List<Moneda> monedasFormulario;
  final ApiClient apiClient;
  final void Function(String) mostrarMensaje;
  final String Function(Object) mensajeError;
  final void Function(String) setError;
  final void Function(CreditoRegistro) onGuardarCreditoLocal;
  final Future<void> Function(OfflineMutationQueuedException)
      onMarcarAccionOfflinePendiente;
  final void Function({
    bool catalogos,
    bool presupuesto,
    bool cobrosRuta,
    bool creditos,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano;

  @override
  State<_DialogoModificarCreditoContent> createState() =>
      _DialogoModificarCreditoContentState();
}

class _DialogoModificarCreditoContentState
    extends State<_DialogoModificarCreditoContent> {
  late final TextEditingController _valorController;
  late final TextEditingController _interesController;
  late final TextEditingController _plazoController;
  late final TextEditingController _observacionController;

  late String? _clienteId;
  late String? _rutaId;
  late String? _cajaMenorId;
  late int? _frecuenciaPagoId;
  late DateTime _fechaInicio;
  late bool _omitirDomingos;
  bool _guardandoDialogo = false;

  @override
  void initState() {
    super.initState();
    _valorController = TextEditingController(
      text: formatNumber(widget.credito.valorPrincipal),
    );
    _interesController = TextEditingController(
      text: formatNumber(widget.credito.porcentajeInteres),
    );
    _plazoController = TextEditingController(
      text: widget.credito.plazoDias.toString(),
    );
    _observacionController = TextEditingController(
      text: widget.credito.observacion ?? '',
    );

    _clienteId = widget.credito.clienteId;
    _rutaId = widget.catalogos.rutasAbiertas
            .any((RutaCatalogo ruta) => ruta.id == widget.credito.rutaId)
        ? widget.credito.rutaId
        : null;
    _cajaMenorId = widget.cajasCompatibles
            .any((CajaMenorCatalogo caja) => caja.id == widget.credito.cajaMenorId)
        ? widget.credito.cajaMenorId
        : widget.cajasCompatibles.first.id;
    _frecuenciaPagoId = widget.catalogos.frecuenciasPago.any(
      (FrecuenciaPago frecuencia) =>
          frecuencia.id == widget.credito.frecuenciaPago.id,
    )
        ? widget.credito.frecuenciaPago.id
        : widget.catalogos.frecuenciasPago.first.id;
    _fechaInicio = widget.credito.fechaInicio;
    _omitirDomingos = widget.credito.omitirDomingos;
  }

  @override
  void dispose() {
    _valorController.dispose();
    _interesController.dispose();
    _plazoController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modificar ${widget.credito.cliente}'),
      content: DialogContent(
        maxWidth: 600,
        child: FormularioCredito(
          clientes: widget.clientesFormulario,
          rutas: widget.catalogos.rutasAbiertas,
          monedas: widget.monedasFormulario,
          frecuencias: widget.catalogos.frecuenciasPago,
          cajasMenores: widget.cajasCompatibles,
          clienteId: _clienteId,
          rutaId: _rutaId,
          monedaCodigo: widget.credito.monedaCodigo,
          frecuenciaPagoId: _frecuenciaPagoId,
          cajaMenorId: _cajaMenorId,
          fechaInicio: _fechaInicio,
          omitirDomingos: _omitirDomingos,
          valorController: _valorController,
          interesController: _interesController,
          plazoController: _plazoController,
          observacionController: _observacionController,
          guardando: _guardandoDialogo,
          monedaBloqueada: true,
          accionLabel: 'Guardar',
          usarSuperficie: false,
          onClienteChanged: (String? value) {
            setState(() => _clienteId = value);
          },
          onRutaChanged: (String? value) {
            setState(() => _rutaId = value);
          },
          onMonedaChanged: (_) {},
          onFrecuenciaChanged: (int? value) {
            setState(() => _frecuenciaPagoId = value);
          },
          onCajaMenorChanged: (String? value) {
            setState(() => _cajaMenorId = value);
          },
          onFechaChanged: (DateTime value) {
            setState(() => _fechaInicio = value);
          },
          onOmitirDomingosChanged: (bool value) {
            setState(() => _omitirDomingos = value);
          },
          onCrear: () async {
            if (_guardandoDialogo) {
              return;
            }

            final String? clienteSeleccionado = _clienteId;
            final String? cajaId = _cajaMenorId;
            final int? frecuenciaId = _frecuenciaPagoId;
            if (clienteSeleccionado == null ||
                cajaId == null ||
                frecuenciaId == null) {
              widget.mostrarMensaje('Faltan datos para modificar');
              return;
            }

            final double valorPrincipal;
            final double porcentajeInteres;
            final int plazoDias;
            try {
              valorPrincipal = parseMontoInput(_valorController.text);
              porcentajeInteres =
                  parsePorcentajeInput(_interesController.text);
              plazoDias =
                  parseEnteroPositivoInput(_plazoController.text);
            } catch (error) {
              widget.mostrarMensaje(widget.mensajeError(error));
              return;
            }

            final bool cambiaCondicionesFinancieras =
                frecuenciaId != widget.credito.frecuenciaPago.id ||
                    formatDateValue(_fechaInicio) !=
                        formatDateValue(widget.credito.fechaInicio) ||
                    valorPrincipal != widget.credito.valorPrincipal ||
                    porcentajeInteres != widget.credito.porcentajeInteres ||
                    plazoDias != widget.credito.plazoDias ||
                    _omitirDomingos != widget.credito.omitirDomingos;
            if (widget.credito.totalAbonado > 0.009 &&
                cambiaCondicionesFinancieras) {
              widget.mostrarMensaje(
                'No se pueden modificar valor, interes, plazo, frecuencia, fecha u omitir domingos en un credito con pagos registrados',
              );
              return;
            }

            final String observacion =
                _observacionController.text.trim();
            final Map<String, dynamic> payload = <String, dynamic>{
              'clienteId': clienteSeleccionado,
              if (_rutaId != null) 'rutaId': _rutaId,
              'monedaCodigo': widget.credito.monedaCodigo,
              'frecuenciaPagoId': frecuenciaId,
              'fechaInicio': formatDateValue(_fechaInicio),
              'valorPrincipal': valorPrincipal,
              'porcentajeInteres': porcentajeInteres,
              'plazoDias': plazoDias,
              'omitirDomingos': _omitirDomingos,
              'cajaMenorId': cajaId,
              if (observacion.isNotEmpty) 'observacion': observacion,
            };
            final CreditoRegistro optimista =
                creditoOptimistaModificado(
              credito: widget.credito,
              catalogos: widget.catalogos,
              clientes: widget.clientes,
              clienteId: clienteSeleccionado,
              rutaId: _rutaId,
              cajaMenorId: cajaId,
              frecuenciaPagoId: frecuenciaId,
              fechaInicio: _fechaInicio,
              valorPrincipal: valorPrincipal,
              porcentajeInteres: porcentajeInteres,
              plazoDias: plazoDias,
              omitirDomingos: _omitirDomingos,
              observacion: observacion.isEmpty ? null : observacion,
            );
            setState(() => _guardandoDialogo = true);
            widget.onGuardarCreditoLocal(optimista);
            if (context.mounted) {
              Navigator.of(context).pop(true);
              widget.mostrarMensaje('Credito modificado');
            }

            unawaited(() async {
              try {
                final CreditoRegistro respuesta =
                    CreditoRegistro.fromJson(
                  await widget.apiClient.patchObject(
                    '/creditos/${widget.credito.id}',
                    payload,
                    queueOffline: true,
                  ),
                );
                widget.onGuardarCreditoLocal(respuesta);
                widget.onRecargarEnSegundoPlano(
                  catalogos: _rutaId == null,
                  presupuesto: true,
                  cobrosRuta: true,
                  creditos: true,
                  movimientosCaja: true,
                );
              } on OfflineMutationQueuedException catch (error) {
                await widget.onMarcarAccionOfflinePendiente(error);
              } catch (error) {
                widget.setError(widget.mensajeError(error));
                widget.onGuardarCreditoLocal(widget.credito);
                widget.mostrarMensaje(widget.mensajeError(error));
              }
            }());
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardandoDialogo
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ],
    );
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

  await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _DialogoModificarCreditoContent(
        credito: credito,
        catalogos: catalogos,
        clientes: clientes,
        cajasCompatibles: cajasCompatibles,
        clientesFormulario: clientesFormulario,
        monedasFormulario: monedasFormulario,
        apiClient: apiClient,
        mostrarMensaje: mostrarMensaje,
        mensajeError: mensajeError,
        setError: setError,
        onGuardarCreditoLocal: onGuardarCreditoLocal,
        onMarcarAccionOfflinePendiente: onMarcarAccionOfflinePendiente,
        onRecargarEnSegundoPlano: onRecargarEnSegundoPlano,
      );
    },
  );
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
