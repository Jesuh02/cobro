import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/cobro_dropdown.dart';
import '../../../../data/models/models.dart';

CobroDropdownItem<String> itemCajaMenor(CajaMenorCatalogo caja) {
  final String subtitulo = caja.responsable != null &&
          caja.responsable!.nombreCompleto.trim().isNotEmpty
      ? '${caja.responsable!.nombreCompleto.trim()} • ${caja.monedaCodigo}'
      : 'Moneda: ${caja.monedaCodigo}';
  return CobroDropdownItem<String>(
    value: caja.id,
    label: caja.nombre,
    subtitle: subtitulo,
    icon: Icons.savings_rounded,
    iconColor: const Color(0xFF2563EB),
  );
}

CobroDropdownItem<String> itemTipoMovimientoCaja(TipoMovimientoCaja tipo) {
  final bool esEntrada = tipo.naturaleza == 'E';
  final IconData iconData =
      esEntrada ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

  return CobroDropdownItem<String>(
    value: tipo.codigo,
    label: tipo.nombre,
    subtitle: esEntrada ? 'Entrada de dinero' : 'Salida de dinero',
    icon: iconData,
    iconColor: esEntrada ? const Color(0xFF10B981) : const Color(0xFFEF4444),
  );
}

Future<void> mostrarDialogoCrearCajaMenor({
  required BuildContext context,
  required bool puedeCrearCajaMenor,
  required Catalogos? catalogos,
  required SesionUsuario? usuarioSesion,
  required CajaMenorCatalogo? Function(String?)
      obtenerCajaMenorAbiertaDeUsuario,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(CajaMenorCatalogo) onGuardarCajaMenorLocal,
  required void Function({
    bool catalogos,
    bool cobrosRuta,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano,
}) async {
  if (!puedeCrearCajaMenor) {
    mostrarMensaje('No tienes permiso para crear caja menor');
    return;
  }

  if (catalogos == null) {
    mostrarMensaje('Los datos todavia estan cargando. Intenta nuevamente.');
    return;
  }

  final bool esAdmin = usuarioSesion?.esAdministrador ?? false;
  final List<UsuarioCatalogo> usuariosDisponibles = catalogos.usuarios;

  final CajaMenorCatalogo? cajaAbiertaPropia =
      obtenerCajaMenorAbiertaDeUsuario(usuarioSesion?.id);
  if (!esAdmin && cajaAbiertaPropia != null) {
    final String cierreStr = cajaAbiertaPropia.fechaCierre != null
        ? formatDateTimeLabel(cajaAbiertaPropia.fechaCierre!)
        : 'horario configurado';
    mostrarMensaje(
      'Ya tienes la caja menor "${cajaAbiertaPropia.nombre}" abierta hasta $cierreStr. Debes cerrarla antes de crear una nueva.',
    );
    return;
  }

  String? usuarioResponsableId = usuariosDisponibles
          .any((UsuarioCatalogo u) => u.id == usuarioSesion?.id)
      ? usuarioSesion?.id
      : (usuariosDisponibles.isNotEmpty ? usuariosDisponibles.first.id : null);

  final bool? creada = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final TextEditingController nombreController = TextEditingController(
        text: nombreCajaMenorPorDefecto(),
      );
      DateTime fechaApertura = DateTime.now();
      DateTime fechaCierre = DateTime(
        fechaApertura.year,
        fechaApertura.month,
        fechaApertura.day,
        23,
        59,
      );

      if (!fechaCierre.isAfter(fechaApertura)) {
        fechaCierre = fechaApertura.add(const Duration(hours: 1));
      }

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final String? usuarioDestinoId =
              esAdmin ? usuarioResponsableId : usuarioSesion?.id;
          final CajaMenorCatalogo? cajaAbiertaExistente =
              obtenerCajaMenorAbiertaDeUsuario(usuarioDestinoId);
          final bool tieneCajaAbierta = cajaAbiertaExistente != null;

          return AlertDialog(
            title: const Text('Crear caja menor'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (esAdmin && usuariosDisponibles.isNotEmpty) ...<Widget>[
                      CobroDropdownField<String>(
                        labelText: 'Usuario responsable',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        value: usuarioResponsableId,
                        items: usuariosDisponibles.map((UsuarioCatalogo u) {
                          final CajaMenorCatalogo? cajaDelUsuario =
                              obtenerCajaMenorAbiertaDeUsuario(u.id);
                          final bool abierta = cajaDelUsuario != null;
                          final String inicial =
                              u.nombreCompleto.trim().isNotEmpty
                                  ? u.nombreCompleto
                                      .trim()
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : '?';
                          final String subtitulo = abierta
                              ? 'Caja activa: ${cajaDelUsuario.nombre}'
                              : ((u.usuario.isNotEmpty &&
                                      u.usuario != u.nombreCompleto)
                                  ? '@${u.usuario}'
                                  : 'Sin caja abierta');
                          return CobroDropdownItem<String>(
                            value: u.id,
                            label: u.nombreCompleto.trim().isNotEmpty
                                ? u.nombreCompleto
                                : u.id,
                            subtitle: subtitulo,
                            avatarText: inicial,
                          );
                        }).toList(growable: false),
                        onChanged: (String? value) {
                          if (value != null) {
                            setDialogState(
                              () => usuarioResponsableId = value,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (tieneCajaAbierta) ...<Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.error_outline_rounded,
                              color: Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Usuario con caja menor activa',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'El usuario seleccionado ya tiene la caja "${cajaAbiertaExistente.nombre}" abierta. No se puede crear otra mientras tenga una activa.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la caja menor',
                        prefixIcon: Icon(Icons.wallet_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final TimeOfDay? selected = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(fechaCierre),
                        );

                        if (selected != null) {
                          final DateTime ahora = DateTime.now();
                          DateTime nueva = DateTime(
                            fechaApertura.year,
                            fechaApertura.month,
                            fechaApertura.day,
                            selected.hour,
                            selected.minute,
                          );
                          if (!nueva.isAfter(ahora)) {
                            nueva = nueva.add(const Duration(days: 1));
                          }
                          setDialogState(() => fechaCierre = nueva);
                        }
                      },
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(
                        'Cierre: ${formatDateTimeLabel(fechaCierre)}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: tieneCajaAbierta
                    ? null
                    : () async {
                        if (nombreController.text.trim().isEmpty) {
                          mostrarMensaje('El nombre de la caja es obligatorio');
                          return;
                        }

                        final DateTime fechaAperturaActual = DateTime.now();
                        if (!fechaCierre.isAfter(fechaAperturaActual)) {
                          mostrarMensaje(
                            'La fecha de cierre debe ser posterior a la de apertura',
                          );
                          return;
                        }

                        final bool guardada = await ejecutarAccion(() async {
                          final CajaMenorCatalogo caja =
                              CajaMenorCatalogo.fromJson(
                            await apiClient.postObject(
                              '/caja-menor',
                              <String, dynamic>{
                                'nombre': nombreController.text.trim(),
                                if (esAdmin && usuarioResponsableId != null)
                                  'responsableUsuarioId': usuarioResponsableId,
                                'fechaApertura':
                                    formatDateTimeValue(fechaAperturaActual),
                                'fechaCierre': formatDateTimeValue(fechaCierre),
                              },
                              queueOffline: true,
                            ),
                          );
                          onGuardarCajaMenorLocal(caja);
                          onRecargarEnSegundoPlano(
                            catalogos: true,
                            cobrosRuta: false,
                            movimientosCaja: true,
                          );
                        });

                        if (guardada && dialogContext.mounted) {
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
    },
  );

  if (creada == true) {
    mostrarMensaje('Caja menor creada');
  }
}

Future<void> mostrarDialogoCerrarCajaMenor({
  required BuildContext context,
  required bool puedeCrearCajaMenor,
  required List<CajaMenorCatalogo> cajasActivas,
  required String? cajaMenorFiltroId,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required Future<void> Function() onRecargar,
  required void Function(String?) onLimpiarCajaFiltroId,
}) async {
  if (!puedeCrearCajaMenor) {
    mostrarMensaje('No tienes permiso para cerrar la caja menor');
    return;
  }

  if (cajasActivas.isEmpty) {
    mostrarMensaje('No hay ninguna caja menor abierta para cerrar');
    return;
  }

  CajaMenorCatalogo? cajaSeleccionada;
  if (cajaMenorFiltroId != null) {
    cajaSeleccionada = cajasActivas.cast<CajaMenorCatalogo?>().firstWhere(
          (CajaMenorCatalogo? c) => c?.id == cajaMenorFiltroId,
          orElse: () => null,
        );
  }
  cajaSeleccionada ??= cajasActivas.length == 1 ? cajasActivas.first : null;

  String? idCajaACerrar = cajaSeleccionada?.id ?? cajasActivas.first.id;

  final bool? confirmar = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final CajaMenorCatalogo? cajaActual =
              cajasActivas.cast<CajaMenorCatalogo?>().firstWhere(
                    (CajaMenorCatalogo? c) => c?.id == idCajaACerrar,
                    orElse: () => null,
                  );

          return AlertDialog(
            title: const Row(
              children: <Widget>[
                Icon(Icons.lock_clock_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Cerrar caja menor'),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (cajasActivas.length > 1) ...<Widget>[
                    CobroDropdownField<String>(
                      labelText: 'Selecciona la caja a cerrar',
                      prefixIcon:
                          const Icon(Icons.account_balance_wallet_outlined),
                      value: idCajaACerrar,
                      items: cajasActivas
                          .map(itemCajaMenor)
                          .toList(growable: false),
                      onChanged: (String? val) {
                        if (val != null) {
                          setDialogState(() => idCajaACerrar = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    '¿Estás seguro de que deseas cerrar la caja "${cajaActual?.nombre ?? idCajaACerrar}"?',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cajaActual?.fechaCierre != null
                        ? 'Estaba programada para cerrar el ${formatDateTimeLabel(cajaActual!.fechaCierre!)}. Al cerrarla ahora, no se podrán registrar más movimientos ni préstamos con ella.'
                        : 'Al cerrarla ahora, no se podrán registrar más movimientos ni préstamos con ella.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirmar cierre'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmar != true || idCajaACerrar == null) {
    return;
  }

  final bool cerrada = await ejecutarAccion(() async {
    await apiClient.postObject(
      '/caja-menor/$idCajaACerrar/cerrar',
      <String, dynamic>{},
    );
    if (cajaMenorFiltroId == idCajaACerrar) {
      onLimpiarCajaFiltroId(null);
    }
    await onRecargar();
  });

  if (cerrada) {
    mostrarMensaje('Caja menor cerrada exitosamente');
  }
}

Future<void> mostrarDialogoMovimientoCaja({
  required BuildContext context,
  required bool puedeRegistrarFlujoCaja,
  required Catalogos? catalogos,
  required String? cajaMenorFiltroId,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(MovimientoCaja) onGuardarMovimientoCajaLocal,
  required void Function({
    bool catalogos,
    bool presupuesto,
    bool clientes,
    bool cobrosRuta,
    bool creditos,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano,
}) async {
  if (!puedeRegistrarFlujoCaja) {
    mostrarMensaje('No tienes permiso para registrar flujo en caja menor');
    return;
  }

  if (catalogos == null) {
    mostrarMensaje('Los datos todavía están cargando. Intenta nuevamente.');
    return;
  }
  if (catalogos.cajasMenoresActivas.isEmpty) {
    mostrarMensaje(
      'No hay ninguna caja menor abierta disponible para registrar movimientos.',
    );
    return;
  }
  if (catalogos.tiposMovimientoCaja.isEmpty) {
    mostrarMensaje('No hay tipos de movimiento configurados');
    return;
  }

  final bool? creado = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final TextEditingController montoController = TextEditingController();
      final TextEditingController motivoController = TextEditingController();
      String cajaMenorId = catalogos.cajasMenoresActivas.any(
        (CajaMenorCatalogo caja) => caja.id == cajaMenorFiltroId,
      )
          ? cajaMenorFiltroId!
          : catalogos.cajasMenoresActivas.first.id;
      String tipoMovimientoCodigo = catalogos.tiposMovimientoCaja.first.codigo;
      DateTime fechaMovimiento = DateTime.now();

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: const Text('Movimiento de caja'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CobroDropdownField<String>(
                      labelText: 'Caja menor',
                      prefixIcon: const Icon(Icons.savings_rounded),
                      value: cajaMenorId,
                      items: catalogos.cajasMenoresActivas
                          .map(itemCajaMenor)
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => cajaMenorId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CobroDropdownField<String>(
                      labelText: 'Tipo de movimiento',
                      prefixIcon: const Icon(Icons.swap_vert_rounded),
                      value: tipoMovimientoCodigo,
                      items: catalogos.tiposMovimientoCaja
                          .map(itemTipoMovimientoCaja)
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => tipoMovimientoCodigo = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime? selected = await showDatePicker(
                          context: context,
                          initialDate: fechaMovimiento,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          final DateTime now = DateTime.now();
                          setDialogState(
                            () => fechaMovimiento = DateTime(
                              selected.year,
                              selected.month,
                              selected.day,
                              now.hour,
                              now.minute,
                              now.second,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(formatDateLabel(fechaMovimiento)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: montoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: motivoController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Motivo',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final double monto;
                  try {
                    monto = parseMontoInput(montoController.text);
                  } catch (error) {
                    mostrarMensaje(mensajeError(error));
                    return;
                  }

                  if (motivoController.text.trim().length < 2) {
                    mostrarMensaje('El motivo es obligatorio');
                    return;
                  }

                  final bool guardado = await ejecutarAccion(() async {
                    final MovimientoCaja creadoMov = MovimientoCaja.fromJson(
                      await apiClient.postObject(
                        '/caja-menor/movimientos',
                        <String, dynamic>{
                          'cajaMenorId': cajaMenorId,
                          'tipoMovimientoCodigo': tipoMovimientoCodigo,
                          'fechaMovimiento':
                              formatDateTimeValue(fechaMovimiento),
                          'monto': monto,
                          'motivo': motivoController.text.trim(),
                        },
                        queueOffline: true,
                      ),
                    );
                    onGuardarMovimientoCajaLocal(creadoMov);
                    onRecargarEnSegundoPlano(
                      catalogos: false,
                      presupuesto: true,
                      clientes: false,
                      cobrosRuta: true,
                      creditos: true,
                      movimientosCaja: true,
                    );
                  });

                  if (guardado && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
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

  if (creado == true) {
    mostrarMensaje('Movimiento registrado');
  }
}

Future<void> mostrarDialogoEditarMovimientoCaja({
  required BuildContext context,
  required MovimientoCaja movimiento,
  required bool puedeModificarMovimientos,
  required bool puedeModificarCreditos,
  required Catalogos? catalogos,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required void Function(String) setError,
  required void Function(MovimientoCaja) onGuardarMovimientoCajaLocal,
  required Future<void> Function(OfflineMutationQueuedException)
      onMarcarAccionOfflinePendiente,
  required void Function({
    bool catalogos,
    bool presupuesto,
    bool clientes,
    bool cobrosRuta,
    bool creditos,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano,
}) async {
  if (!puedeModificarMovimientos) {
    mostrarMensaje('No tienes permiso para modificar movimientos');
    return;
  }
  if (!movimiento.esEditablePorAdmin) {
    mostrarMensaje('Este movimiento no se puede modificar desde caja menor');
    return;
  }
  if (movimiento.referenciaTabla == 'credito_desembolso' &&
      !puedeModificarCreditos) {
    mostrarMensaje('No tienes permiso para modificar creditos');
    return;
  }

  if (catalogos == null) {
    mostrarMensaje('Los datos todavia estan cargando. Intenta nuevamente.');
    return;
  }
  if (!catalogos.cajasMenoresActivas.any(
    (CajaMenorCatalogo caja) => caja.id == movimiento.cajaMenorId,
  )) {
    mostrarMensaje('La caja menor del movimiento no esta activa');
    return;
  }
  if (!catalogos.tiposMovimientoCaja.any(
    (TipoMovimientoCaja tipo) =>
        tipo.codigo == movimiento.tipoMovimiento.codigo,
  )) {
    mostrarMensaje('El tipo del movimiento ya no esta disponible');
    return;
  }

  final bool? guardado = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final TextEditingController montoController = TextEditingController(
        text: formatNumber(movimiento.monto),
      );
      final TextEditingController motivoController = TextEditingController(
        text: movimiento.motivo,
      );
      String cajaMenorId = movimiento.cajaMenorId;
      String tipoMovimientoCodigo = movimiento.tipoMovimiento.codigo;
      DateTime fechaMovimiento = movimiento.fechaMovimiento;
      final bool tipoBloqueado = movimiento.referenciaTabla != null;

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: const Text('Modificar movimiento'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CobroDropdownField<String>(
                      labelText: 'Caja menor',
                      prefixIcon: const Icon(Icons.savings_rounded),
                      value: cajaMenorId,
                      items: catalogos.cajasMenoresActivas
                          .map(itemCajaMenor)
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => cajaMenorId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CobroDropdownField<String>(
                      labelText: 'Tipo de movimiento',
                      prefixIcon: const Icon(Icons.swap_vert_rounded),
                      value: tipoMovimientoCodigo,
                      enabled: !tipoBloqueado,
                      items: catalogos.tiposMovimientoCaja
                          .map(itemTipoMovimientoCaja)
                          .toList(growable: false),
                      onChanged: tipoBloqueado
                          ? null
                          : (String? value) {
                              if (value != null) {
                                setDialogState(
                                  () => tipoMovimientoCodigo = value,
                                );
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime? selected = await showDatePicker(
                          context: context,
                          initialDate: fechaMovimiento,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          final DateTime now = DateTime.now();
                          setDialogState(
                            () => fechaMovimiento = DateTime(
                              selected.year,
                              selected.month,
                              selected.day,
                              now.hour,
                              now.minute,
                              now.second,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(formatDateLabel(fechaMovimiento)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: montoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: motivoController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Motivo',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final double monto;
                  try {
                    monto = parseMontoInput(montoController.text);
                  } catch (error) {
                    mostrarMensaje(mensajeError(error));
                    return;
                  }

                  if (motivoController.text.trim().length < 2) {
                    mostrarMensaje('El motivo es obligatorio');
                    return;
                  }

                  final CajaMenorCatalogo caja =
                      catalogos.cajasMenores.firstWhere(
                    (CajaMenorCatalogo item) => item.id == cajaMenorId,
                  );
                  final TipoMovimientoCaja tipo =
                      catalogos.tiposMovimientoCaja.firstWhere(
                    (TipoMovimientoCaja item) =>
                        item.codigo == tipoMovimientoCodigo,
                  );
                  final String motivo = motivoController.text.trim();
                  final Map<String, dynamic> payload = <String, dynamic>{
                    'cajaMenorId': cajaMenorId,
                    'tipoMovimientoCodigo': tipoMovimientoCodigo,
                    'fechaMovimiento': formatDateTimeValue(fechaMovimiento),
                    'monto': monto,
                    'motivo': motivo,
                  };
                  final MovimientoCaja optimista = movimiento.copyWith(
                    cajaMenorId: caja.id,
                    cajaMenor: caja.nombre,
                    tipoMovimiento: tipo,
                    fechaMovimiento: fechaMovimiento,
                    monto: monto,
                    montoConNaturaleza:
                        tipo.naturaleza.toUpperCase() == 'S' ? -monto : monto,
                    motivo: motivo,
                  );

                  onGuardarMovimientoCajaLocal(optimista);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }

                  unawaited(() async {
                    try {
                      final MovimientoCaja respuesta = MovimientoCaja.fromJson(
                        await apiClient.patchObject(
                          '/caja-menor/movimientos/${movimiento.id}',
                          payload,
                          queueOffline: true,
                        ),
                      );
                      onGuardarMovimientoCajaLocal(respuesta);
                      onRecargarEnSegundoPlano(
                        catalogos: false,
                        presupuesto: true,
                        clientes: false,
                        cobrosRuta: true,
                        creditos: true,
                        movimientosCaja: true,
                      );
                    } on OfflineMutationQueuedException catch (error) {
                      await onMarcarAccionOfflinePendiente(error);
                    } catch (error) {
                      setError(mensajeError(error));
                      onGuardarMovimientoCajaLocal(movimiento);
                      mostrarMensaje(mensajeError(error));
                    }
                  }());
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Guardar'),
              ),
            ],
          );
        },
      );
    },
  );

  if (guardado == true) {
    mostrarMensaje('Movimiento modificado');
  }
}

Future<void> mostrarDialogoEliminarMovimientoCaja({
  required BuildContext context,
  required MovimientoCaja movimiento,
  required bool puedeEliminarMovimientos,
  required bool puedeEliminarCreditos,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required Future<bool> Function(Future<void> Function()) ejecutarAccion,
  required void Function(String) onEliminarMovimientoLocal,
  required void Function(MovimientoCaja) onRestaurarMovimientoLocal,
  required Future<void> Function(OfflineMutationQueuedException)
      onMarcarAccionOfflinePendiente,
  required void Function({
    bool catalogos,
    bool presupuesto,
    bool clientes,
    bool cobrosRuta,
    bool creditos,
    bool movimientosCaja,
  }) onRecargarEnSegundoPlano,
}) async {
  if (!puedeEliminarMovimientos) {
    mostrarMensaje('No tienes permiso para eliminar movimientos');
    return;
  }
  if (!movimiento.esEditablePorAdmin) {
    mostrarMensaje('Este movimiento no se puede eliminar desde caja menor');
    return;
  }
  if (movimiento.referenciaTabla == 'credito_desembolso' &&
      !puedeEliminarCreditos) {
    mostrarMensaje('No tienes permiso para eliminar creditos');
    return;
  }

  final bool? confirmado = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('¿Seguro que quieres eliminar?'),
        content: Text(
          'Se eliminara "${movimiento.motivoVisible}" y caja, recaudado, gastos y presupuesto quedaran como si no se hubiera hecho.',
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
    onEliminarMovimientoLocal(movimiento.id);
    try {
      await apiClient.deleteObject(
        '/caja-menor/movimientos/${movimiento.id}',
        queueOffline: true,
      );
    } on OfflineMutationQueuedException catch (error) {
      await onMarcarAccionOfflinePendiente(error);
    } catch (_) {
      onRestaurarMovimientoLocal(movimiento);
      rethrow;
    }
    onRecargarEnSegundoPlano(
      catalogos: false,
      presupuesto: true,
      clientes: false,
      cobrosRuta: true,
      creditos: true,
      movimientosCaja: true,
    );
  });

  if (eliminado) {
    mostrarMensaje('Movimiento eliminado');
  }
}
