import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/ui/modal_layouts.dart';
import '../../../../data/models/models.dart';
import '../../../creditos/presentation/widgets/formulario_credito.dart';
import '../widgets/cliente_ubicacion_picker.dart';

const String _direccionCasaHint = 'Ej: cr14 #28-26';
const String _mensajeDireccionCasa =
    'Escribe la direccion de la casa asociada a esta ubicacion';

Future<void> mostrarDialogoCrearCliente({
  required BuildContext context,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(Cliente) onClienteCreado,
  required void Function() onRecargarEnSegundoPlano,
}) async {
  final bool? creado = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final TextEditingController nombreController = TextEditingController();
      final TextEditingController cedulaController = TextEditingController();
      final TextEditingController direccionController = TextEditingController();
      final TextEditingController correoController = TextEditingController();
      final TextEditingController telefonoController = TextEditingController();
      LatLng? ubicacionCliente;

      return AlertDialog(
        title: const Text('Nuevo cliente'),
        content: DialogContent(
          maxWidth: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cedulaController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  labelText: 'Cédula',
                  hintText: 'Número de identificación',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: direccionController,
                decoration: const InputDecoration(
                  labelText: 'Direccion',
                  hintText: _direccionCasaHint,
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
              ),
              const SizedBox(height: 12),
              ClienteUbicacionPicker(
                value: ubicacionCliente,
                onChanged: (LatLng? value) => ubicacionCliente = value,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: correoController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (nombreController.text.trim().length < 2) {
                mostrarMensaje('El cliente necesita nombre completo');
                return;
              }

              if (ubicacionCliente != null &&
                  direccionController.text.trim().isEmpty) {
                mostrarMensaje(_mensajeDireccionCasa);
                return;
              }

              await ejecutarAccion(() async {
                final Cliente cliente = Cliente.fromJson(
                  await apiClient.postObject(
                    '/clientes',
                    <String, dynamic>{
                      'nombreCompleto': nombreController.text.trim(),
                      if (cedulaController.text.trim().isNotEmpty)
                        'cedula': cedulaController.text.trim(),
                      if (direccionController.text.trim().isNotEmpty)
                        'direccion': direccionController.text.trim(),
                      if (ubicacionCliente != null) ...<String, dynamic>{
                        'latitud': ubicacionCliente!.latitude,
                        'longitud': ubicacionCliente!.longitude,
                      },
                      if (correoController.text.trim().isNotEmpty)
                        'correo': correoController.text.trim(),
                      if (telefonoController.text.trim().isNotEmpty)
                        'telefono': telefonoController.text.trim(),
                    },
                    queueOffline: true,
                  ),
                );
                onClienteCreado(cliente);
                onRecargarEnSegundoPlano();
              });

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Crear'),
          ),
        ],
      );
    },
  );

  if (creado == true) {
    mostrarMensaje('Cliente creado');
  }
}

Future<void> mostrarDialogoModificarCliente({
  required BuildContext context,
  required Cliente cliente,
  required bool esAdministrador,
  bool? puedeModificar,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(Cliente) onClienteModificado,
  required void Function() onRecargarEnSegundoPlano,
}) async {
  final bool permitido = puedeModificar ?? esAdministrador;
  if (!permitido) {
    mostrarMensaje('No tienes permiso para modificar clientes');
    return;
  }

  final bool? modificado = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _DialogoModificarClienteContent(
      cliente: cliente,
      apiClient: apiClient,
      mostrarMensaje: mostrarMensaje,
      ejecutarAccion: ejecutarAccion,
      onClienteModificado: onClienteModificado,
      onRecargarEnSegundoPlano: onRecargarEnSegundoPlano,
    ),
  );

  if (modificado == true) {
    mostrarMensaje('Cliente actualizado');
  }
}

class _DialogoModificarClienteContent extends StatefulWidget {
  const _DialogoModificarClienteContent({
    required this.cliente,
    required this.apiClient,
    required this.mostrarMensaje,
    required this.ejecutarAccion,
    required this.onClienteModificado,
    required this.onRecargarEnSegundoPlano,
  });

  final Cliente cliente;
  final ApiClient apiClient;
  final void Function(String) mostrarMensaje;
  final Future<bool> Function(Future<void> Function()) ejecutarAccion;
  final void Function(Cliente) onClienteModificado;
  final void Function() onRecargarEnSegundoPlano;

  @override
  State<_DialogoModificarClienteContent> createState() =>
      _DialogoModificarClienteContentState();
}

class _DialogoModificarClienteContentState
    extends State<_DialogoModificarClienteContent> {
  late final TextEditingController _nombreController;
  late final TextEditingController _cedulaController;
  late final TextEditingController _negocioController;
  late final TextEditingController _direccionController;
  late final TextEditingController _correoController;
  late final TextEditingController _telefonoController;
  late LatLng? _ubicacionCliente;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.cliente.nombreCompleto);
    _cedulaController =
        TextEditingController(text: widget.cliente.cedula ?? '');
    _negocioController =
        TextEditingController(text: widget.cliente.nombreComercial ?? '');
    _direccionController =
        TextEditingController(text: widget.cliente.direccion ?? '');
    _correoController =
        TextEditingController(text: widget.cliente.correo ?? '');
    _telefonoController =
        TextEditingController(text: widget.cliente.telefono ?? '');
    _ubicacionCliente = widget.cliente.tieneUbicacion
        ? LatLng(widget.cliente.latitude!, widget.cliente.longitude!)
        : null;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    _negocioController.dispose();
    _direccionController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreController.text.trim().length < 2) {
      widget.mostrarMensaje('El cliente necesita nombre completo');
      return;
    }

    if (_ubicacionCliente != null &&
        _direccionController.text.trim().isEmpty) {
      widget.mostrarMensaje(_mensajeDireccionCasa);
      return;
    }

    setState(() => _guardando = true);
    final bool guardado = await widget.ejecutarAccion(() async {
      final Cliente actualizado = Cliente.fromJson(
        await widget.apiClient.patchObject(
          '/clientes/${widget.cliente.id}',
          <String, dynamic>{
            'nombreCompleto': _nombreController.text.trim(),
            if (_cedulaController.text.trim().isNotEmpty)
              'cedula': _cedulaController.text.trim(),
            if (_negocioController.text.trim().isNotEmpty)
              'nombreComercial': _negocioController.text.trim(),
            'direccion': _direccionController.text.trim(),
            if (_ubicacionCliente != null) ...<String, dynamic>{
              'latitud': _ubicacionCliente!.latitude,
              'longitud': _ubicacionCliente!.longitude,
            } else ...<String, dynamic>{
              'latitud': null,
              'longitud': null,
            },
            if (_correoController.text.trim().isNotEmpty)
              'correo': _correoController.text.trim(),
            if (_telefonoController.text.trim().isNotEmpty)
              'telefono': _telefonoController.text.trim(),
          },
          queueOffline: true,
        ),
      );
      widget.onClienteModificado(actualizado);
      widget.onRecargarEnSegundoPlano();
    });

    if (!guardado) {
      if (mounted) {
        setState(() => _guardando = false);
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modificar cliente'),
      content: DialogContent(
        maxWidth: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nombreController,
              enabled: !_guardando,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cedulaController,
              enabled: !_guardando,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: const InputDecoration(
                labelText: 'Cedula',
                hintText: 'Numero de identificacion',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _negocioController,
              enabled: !_guardando,
              decoration: const InputDecoration(
                labelText: 'Negocio',
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _direccionController,
              enabled: !_guardando,
              decoration: const InputDecoration(
                labelText: 'Direccion',
                hintText: _direccionCasaHint,
                prefixIcon: Icon(Icons.location_on_rounded),
              ),
            ),
            const SizedBox(height: 12),
            ClienteUbicacionPicker(
              value: _ubicacionCliente,
              enabled: !_guardando,
              onChanged: (LatLng? value) {
                setState(() => _ubicacionCliente = value);
              },
            ),
            const SizedBox(height: 12),
            DosColumnas(
              left: TextField(
                controller: _correoController,
                enabled: !_guardando,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_rounded),
                ),
              ),
              right: TextField(
                controller: _telefonoController,
                enabled: !_guardando,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

Future<void> mostrarDialogoEliminarCliente({
  required BuildContext context,
  required Cliente cliente,
  required bool esAdministrador,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(String) onClienteEliminado,
  required void Function() onRecargarEnSegundoPlano,
}) async {
  if (!esAdministrador) {
    mostrarMensaje('Solo los administradores pueden eliminar clientes');
    return;
  }

  final bool? confirmado = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Seguro que quieres eliminar?'),
        content: Text(
          'Se eliminara "${cliente.nombreCompleto}". No se puede eliminar si tiene creditos o pagos registrados.',
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
    await apiClient.deleteObject('/clientes/${cliente.id}');
    onClienteEliminado(cliente.id);
    onRecargarEnSegundoPlano();
  });

  if (eliminado) {
    mostrarMensaje('Cliente eliminado');
  }
}

Future<void> mostrarDialogoCrearClienteConCredito({
  required BuildContext context,
  required Catalogos? catalogos,
  required ApiClient apiClient,
  required bool puedeCrearCreditos,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(Cliente) onClienteCreado,
  VoidCallback? onCreditoCreado,
  VoidCallback? onMostrarCuotasRegistradas,
  required void Function({
    bool catalogos,
    bool presupuesto,
    bool clientes,
    bool cobrosRuta,
    bool creditos,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano,
  bool Function(String, double)? validarPresupuestoCaja,
  String? defaultRutaId,
  String? defaultMonedaCodigo,
  int? defaultFrecuenciaPagoId,
  String? defaultCajaMenorId,
}) async {
  final List<RutaCatalogo> rutas =
      catalogos?.rutasAbiertas ?? const <RutaCatalogo>[];
  final List<Moneda> monedas = catalogos?.monedas ?? const <Moneda>[];
  final List<FrecuenciaPago> frecuencias =
      catalogos?.frecuenciasPago ?? const <FrecuenciaPago>[];
  final List<CajaMenorCatalogo> cajasMenores =
      catalogos?.cajasMenoresActivas ?? const <CajaMenorCatalogo>[];

  final String? resultado = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      final TextEditingController nombreController = TextEditingController();
      final TextEditingController cedulaController = TextEditingController();
      final TextEditingController direccionController = TextEditingController();
      final TextEditingController correoController = TextEditingController();
      final TextEditingController telefonoController = TextEditingController();
      final TextEditingController valorController = TextEditingController();
      final TextEditingController interesController = TextEditingController(
        text: '20',
      );
      final TextEditingController plazoController = TextEditingController(
        text: '30',
      );
      final TextEditingController observacionController =
          TextEditingController();

      final bool creditoDisponible = monedas.isNotEmpty &&
          frecuencias.isNotEmpty &&
          cajasMenores.isNotEmpty;
      bool agregarCredito = creditoDisponible;
      bool guardandoDialogo = false;
      String? clienteCreadoId;
      String? rutaId = rutas.any((RutaCatalogo r) => r.id == defaultRutaId)
          ? defaultRutaId
          : null;
      String? monedaCodigo =
          monedas.any((Moneda m) => m.codigo == defaultMonedaCodigo)
              ? defaultMonedaCodigo
              : (monedas.isEmpty ? null : monedas.first.codigo);
      int? frecuenciaPagoId =
          frecuencias.any((FrecuenciaPago f) => f.id == defaultFrecuenciaPagoId)
              ? defaultFrecuenciaPagoId
              : (frecuencias.isEmpty ? null : frecuencias.first.id);
      String? cajaMenorId =
          cajasMenores.any((CajaMenorCatalogo c) => c.id == defaultCajaMenorId)
              ? defaultCajaMenorId
              : (cajasMenores.isEmpty ? null : cajasMenores.first.id);

      DateTime fechaInicio = DateTime.now();
      bool omitirDomingos = true;
      LatLng? ubicacionCliente;

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: const Text('Nuevo cliente'),
            content: DialogContent(
              maxWidth: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nombreController,
                    enabled: !guardandoDialogo,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cedulaController,
                    enabled: !guardandoDialogo,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(20),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Cedula',
                      hintText: 'Numero de identificacion',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: direccionController,
                    enabled: !guardandoDialogo,
                    decoration: const InputDecoration(
                      labelText: 'Direccion',
                      hintText: _direccionCasaHint,
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClienteUbicacionPicker(
                    value: ubicacionCliente,
                    enabled: !guardandoDialogo,
                    onChanged: (LatLng? value) {
                      setDialogState(() => ubicacionCliente = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DosColumnas(
                    left: TextField(
                      controller: correoController,
                      enabled: !guardandoDialogo,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.mail_rounded),
                      ),
                    ),
                    right: TextField(
                      controller: telefonoController,
                      enabled: !guardandoDialogo,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Telefono',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: agregarCredito,
                    onChanged: creditoDisponible && !guardandoDialogo
                        ? (bool value) =>
                            setDialogState(() => agregarCredito = value)
                        : null,
                    title: const Text('Crear credito de inmediato'),
                    subtitle: Text(
                      creditoDisponible
                          ? 'Abre la cartera con el primer prestamo configurado'
                          : 'Configura catalogos para habilitar creditos al cliente',
                    ),
                  ),
                  if (agregarCredito) ...<Widget>[
                    const SizedBox(height: 8),
                    CamposCreditoSinCliente(
                      rutas: rutas,
                      monedas: monedas,
                      frecuencias: frecuencias,
                      cajasMenores: cajasMenores,
                      rutaId: rutaId,
                      monedaCodigo: monedaCodigo,
                      frecuenciaPagoId: frecuenciaPagoId,
                      cajaMenorId: cajaMenorId,
                      fechaInicio: fechaInicio,
                      omitirDomingos: omitirDomingos,
                      valorController: valorController,
                      interesController: interesController,
                      plazoController: plazoController,
                      observacionController: observacionController,
                      guardando: guardandoDialogo,
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
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: guardandoDialogo
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: guardandoDialogo
                    ? null
                    : () async {
                        if (nombreController.text.trim().length < 2) {
                          mostrarMensaje(
                            'El cliente necesita nombre completo',
                          );
                          return;
                        }

                        if (ubicacionCliente != null &&
                            direccionController.text.trim().isEmpty) {
                          mostrarMensaje(_mensajeDireccionCasa);
                          return;
                        }

                        double? valorPrincipal;
                        double? porcentajeInteres;
                        int? plazoDias;
                        String? cajaMenorCreditoId;

                        if (agregarCredito) {
                          if (monedaCodigo == null ||
                              frecuenciaPagoId == null) {
                            mostrarMensaje(
                              'Faltan datos reales para crear el credito',
                            );
                            return;
                          }

                          if (cajaMenorId == null) {
                            mostrarMensaje(
                              'No se puede hacer credito sin caja menor',
                            );
                            return;
                          }
                          final String cajaMenorValidadaId = cajaMenorId!;

                          try {
                            valorPrincipal =
                                parseMontoInput(valorController.text);
                            porcentajeInteres =
                                parseNumero(interesController.text) ?? 0.0;
                            plazoDias = int.parse(plazoController.text.trim());
                          } catch (error) {
                            mostrarMensaje(mensajeError(error));
                            return;
                          }

                          if (validarPresupuestoCaja != null &&
                              !validarPresupuestoCaja(
                                cajaMenorValidadaId,
                                valorPrincipal,
                              )) {
                            return;
                          }

                          cajaMenorCreditoId = cajaMenorValidadaId;
                        }

                        setDialogState(() => guardandoDialogo = true);

                        final bool guardado = await ejecutarAccion(() async {
                          String clienteId;
                          if (clienteCreadoId != null) {
                            clienteId = clienteCreadoId!;
                          } else {
                            final Cliente cliente = Cliente.fromJson(
                              await apiClient.postObject(
                                '/clientes',
                                <String, dynamic>{
                                  'nombreCompleto':
                                      nombreController.text.trim(),
                                  if (cedulaController.text.trim().isNotEmpty)
                                    'cedula': cedulaController.text.trim(),
                                  if (direccionController.text
                                      .trim()
                                      .isNotEmpty)
                                    'direccion':
                                        direccionController.text.trim(),
                                  if (ubicacionCliente !=
                                      null) ...<String, dynamic>{
                                    'latitud': ubicacionCliente!.latitude,
                                    'longitud': ubicacionCliente!.longitude,
                                  },
                                  if (correoController.text.trim().isNotEmpty)
                                    'correo': correoController.text.trim(),
                                  if (telefonoController.text.trim().isNotEmpty)
                                    'telefono': telefonoController.text.trim(),
                                },
                                queueOffline: true,
                              ),
                            );
                            clienteId = cliente.id;
                            clienteCreadoId = clienteId;
                            onClienteCreado(cliente);
                          }

                          if (agregarCredito) {
                            await apiClient.postObject(
                              '/creditos',
                              <String, dynamic>{
                                'clienteId': clienteId,
                                if (rutaId != null) 'rutaId': rutaId,
                                'monedaCodigo': monedaCodigo,
                                'frecuenciaPagoId': frecuenciaPagoId,
                                'fechaInicio': formatDateValue(fechaInicio),
                                'valorPrincipal': valorPrincipal,
                                'porcentajeInteres': porcentajeInteres,
                                'plazoDias': plazoDias,
                                'omitirDomingos': omitirDomingos,
                                'cajaMenorId': cajaMenorCreditoId!,
                                if (observacionController.text
                                    .trim()
                                    .isNotEmpty)
                                  'observacion':
                                      observacionController.text.trim(),
                              },
                              queueOffline: true,
                            );
                            onCreditoCreado?.call();
                            onMostrarCuotasRegistradas?.call();
                          }

                          onRecargarEnSegundoPlano(
                            catalogos: agregarCredito && rutaId == null,
                            presupuesto: agregarCredito,
                            clientes: true,
                            cobrosRuta: agregarCredito,
                            creditos: agregarCredito,
                            movimientosCaja: agregarCredito,
                          );
                        });

                        if (!guardado) {
                          if (dialogContext.mounted) {
                            setDialogState(() => guardandoDialogo = false);
                          }
                          return;
                        }

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(
                            agregarCredito
                                ? 'Cliente y credito creados'
                                : 'Cliente creado',
                          );
                        }
                      },
                icon: guardandoDialogo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  agregarCredito ? 'Crear cliente y credito' : 'Crear',
                ),
              ),
            ],
          );
        },
      );
    },
  );

  if (resultado != null) {
    mostrarMensaje(resultado);
  }
}
