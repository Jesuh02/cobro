import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/ui/cobro_dropdown.dart';
import '../../../core/ui/page_layout.dart';
import '../../../data/models/models.dart';
import '../../empleados/presentation/gestion_empleados_page.dart';
import 'widgets/organizacion_admin_picker.dart';

class SuperAdminView extends StatelessWidget {
  const SuperAdminView({
    required this.organizaciones,
    required this.guardando,
    required this.cargando,
    required this.onRefresh,
    required this.onCrearOrganizacion,
    required this.onCrearAdministrador,
    required this.onEditarOrganizacion,
    required this.onActivoChanged,
    this.error,
    super.key,
  });

  final List<OrganizacionAdmin> organizaciones;
  final bool guardando;
  final bool cargando;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCrearOrganizacion;
  final Future<void> Function() onCrearAdministrador;
  final void Function(OrganizacionAdmin) onEditarOrganizacion;
  final void Function(OrganizacionAdmin, bool) onActivoChanged;

  @override
  Widget build(BuildContext context) {
    final int suspendidas = organizaciones
        .where((OrganizacionAdmin organizacion) => organizacion.suspendida)
        .length;
    final int activas = organizaciones.length - suspendidas;

    return Pagina(
      titulo: 'Instituciones',
      subtitulo: 'Administracion global de accesos y pagos',
      error: error,
      onRefresh: onRefresh,
      acciones: <Widget>[
        FilledButton.icon(
          onPressed: guardando ? null : onCrearOrganizacion,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Institucion'),
        ),
        FilledButton.tonalIcon(
          onPressed: guardando ? null : onCrearAdministrador,
          icon: const Icon(Icons.admin_panel_settings_rounded),
          label: const Text('Administrador'),
        ),
        IconButton.filledTonal(
          onPressed: cargando ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recargar',
        ),
      ],
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            EmpleadoGestionMetrica(
              icono: Icons.apartment_rounded,
              etiqueta: 'Instituciones',
              valor: organizaciones.length.toString(),
            ),
            EmpleadoGestionMetrica(
              icono: Icons.check_circle_rounded,
              etiqueta: 'Activas',
              valor: activas.toString(),
              color: CobroAppTheme.success,
            ),
            EmpleadoGestionMetrica(
              icono: Icons.pause_circle_rounded,
              etiqueta: 'Suspendidas',
              valor: suspendidas.toString(),
              color: CobroAppTheme.danger,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (organizaciones.isEmpty)
          const EstadoVacio(
            icono: Icons.apartment_outlined,
            titulo: 'Sin instituciones',
            mensaje: 'No hay instituciones registradas.',
          )
        else
          ...organizaciones.map(
            (OrganizacionAdmin organizacion) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OrganizacionAdminItem(
                organizacion: organizacion,
                guardando: guardando,
                onEditar: () => onEditarOrganizacion(organizacion),
                onActivoChanged: (bool activo) => onActivoChanged(
                  organizacion,
                  activo,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<Map<String, dynamic>?> pedirDatosOrganizacionAdmin(
  BuildContext context, {
  OrganizacionAdmin? organizacion,
  required void Function(String) mostrarMensaje,
}) async {
  final TextEditingController nombreController = TextEditingController(
    text: organizacion?.nombre ?? '',
  );
  final TextEditingController telefonoController = TextEditingController(
    text: organizacion?.telefono ?? '',
  );
  final TextEditingController correoController = TextEditingController(
    text: organizacion?.correo ?? '',
  );
  final TextEditingController montoController = TextEditingController(
    text: formatNumber(organizacion?.montoPlan ?? 0),
  );
  final TextEditingController accesoController = TextEditingController(
    text: organizacion?.accesoHasta ?? '',
  );
  String moneda = organizacion?.monedaPlan ?? 'COP';
  DateTime? accesoHasta = organizacion?.accesoHasta == null
      ? null
      : DateTime.tryParse(organizacion!.accesoHasta!);

  final Map<String, dynamic>? datos = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
          title: Text(
            organizacion == null ? 'Crear institucion' : 'Editar institucion',
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nombreController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.business_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: telefonoController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Telefono',
                      prefixIcon: Icon(Icons.call_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: montoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cuanto pagan',
                      prefixIcon: Icon(Icons.payments_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CobroDropdownField<String>(
                    labelText: 'Moneda',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    value: moneda,
                    menuWidth: 280,
                    items: const <CobroDropdownItem<String>>[
                      CobroDropdownItem<String>(
                        value: 'COP',
                        label: 'COP',
                        subtitle: 'Peso colombiano',
                        icon: Icons.monetization_on_rounded,
                        iconColor: Color(0xFF10B981),
                      ),
                      CobroDropdownItem<String>(
                        value: 'USD',
                        label: 'USD',
                        subtitle: 'Dolar estadounidense',
                        icon: Icons.attach_money_rounded,
                        iconColor: Color(0xFF3B82F6),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() => moneda = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accesoController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Acceso hasta',
                      hintText: 'Sin vencimiento',
                      prefixIcon: const Icon(Icons.event_available_rounded),
                      suffixIcon: accesoHasta == null
                          ? const Icon(Icons.calendar_month_rounded)
                          : IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  accesoHasta = null;
                                  accesoController.clear();
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Quitar fecha',
                            ),
                    ),
                    onTap: () async {
                      final DateTime initialDate =
                          accesoHasta ?? DateTime.now();
                      final DateTime? selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: initialDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        switchToInputEntryModeIcon: const Icon(
                          Icons.edit_calendar_rounded,
                          color: CobroAppTheme.primary,
                        ),
                        switchToCalendarEntryModeIcon: const Icon(
                          Icons.calendar_month_rounded,
                          color: CobroAppTheme.primary,
                        ),
                      );

                      if (selected != null) {
                        setDialogState(() {
                          accesoHasta = selected;
                          accesoController.text = formatDateValue(selected);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final String nombre = nombreController.text.trim();
                final String telefono = telefonoController.text.trim();
                final String correo =
                    correoController.text.trim().toLowerCase();
                final double? monto = parseNumero(montoController.text);

                if (nombre.length < 3) {
                  mostrarMensaje('El nombre debe tener minimo 3 caracteres');
                  return;
                }

                if (correo.isNotEmpty &&
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) {
                  mostrarMensaje('Ingresa un email valido');
                  return;
                }

                if (monto == null || monto < 0) {
                  mostrarMensaje('Ingresa un monto valido');
                  return;
                }

                Navigator.of(dialogContext).pop(<String, dynamic>{
                  'nombre': nombre,
                  'telefono': telefono.isEmpty ? null : telefono,
                  'correo': correo.isEmpty ? null : correo,
                  'montoPlan': monto,
                  'monedaPlan': moneda,
                  'accesoHasta': accesoHasta == null
                      ? null
                      : formatDateValue(accesoHasta!),
                });
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Guardar'),
            ),
          ],
        ),
      );
    },
  );

  montoController.dispose();
  accesoController.dispose();
  nombreController.dispose();
  telefonoController.dispose();
  correoController.dispose();

  return datos;
}

Future<Map<String, dynamic>?> pedirDatosAdministradorAdmin(
  BuildContext context, {
  required List<OrganizacionAdmin> organizaciones,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required void Function(bool) setGuardando,
}) async {
  final OrganizacionAdmin organizacionInicial = organizaciones.first;
  final TextEditingController organizacionController =
      TextEditingController(text: organizacionInicial.nombre);
  final FocusNode organizacionFocusNode = FocusNode();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController contrasenaController = TextEditingController();
  OrganizacionAdmin? organizacionSeleccionada = organizacionInicial;
  bool mostrarContrasena = false;
  bool guardandoDialog = false;

  final Map<String, dynamic>? datos = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
          title: const Text('Crear administrador'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  OrganizacionAdminPicker(
                    organizaciones: organizaciones,
                    controller: organizacionController,
                    focusNode: organizacionFocusNode,
                    seleccionada: organizacionSeleccionada,
                    onChanged: (OrganizacionAdmin? value) {
                      setDialogState(
                        () => organizacionSeleccionada = value,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                    ),
                    child: Text(
                      'ADMINISTRADOR',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombreController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usuarioController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contrasenaController,
                    obscureText: !mostrarContrasena,
                    decoration: InputDecoration(
                      labelText: 'Contrasena',
                      helperText: 'Minimo 12 caracteres',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(
                            () => mostrarContrasena = !mostrarContrasena,
                          );
                        },
                        icon: Icon(
                          mostrarContrasena
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: guardandoDialog
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: guardandoDialog
                  ? null
                  : () async {
                      final OrganizacionAdmin? organizacion =
                          organizacionSeleccionada;
                      final String nombre = nombreController.text.trim();
                      final String usuario =
                          usuarioController.text.trim().toLowerCase();
                      final String correo =
                          correoController.text.trim().toLowerCase();
                      final String contrasena = contrasenaController.text;

                      if (organizacion == null) {
                        mostrarMensaje('Selecciona una institucion');
                        return;
                      }

                      if (nombre.length < 3) {
                        mostrarMensaje(
                          'El nombre debe tener minimo 3 caracteres',
                        );
                        return;
                      }

                      if (usuario.length < 3 ||
                          !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(usuario)) {
                        mostrarMensaje(
                          'El usuario debe tener minimo 3 caracteres validos',
                        );
                        return;
                      }

                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(correo)) {
                        mostrarMensaje('Ingresa un email valido');
                        return;
                      }

                      if (contrasena.length < 12) {
                        mostrarMensaje(
                          'La contrasena debe tener 12 caracteres',
                        );
                        return;
                      }

                      final Map<String, dynamic> body = <String, dynamic>{
                        'organizacionId': organizacion.id,
                        'nombreCompleto': nombre,
                        'usuario': usuario,
                        'correo': correo,
                        'contrasena': contrasena,
                      };

                      setDialogState(() => guardandoDialog = true);
                      setGuardando(true);

                      try {
                        final Map<String, dynamic> creado =
                            await apiClient.postObject(
                          '/super-admin/usuarios/admin',
                          body,
                        );
                        final Object? rawRoles = creado['roles'];
                        final List<String> roles = rawRoles is List<dynamic>
                            ? rawRoles
                                .whereType<String>()
                                .toList(growable: false)
                            : const <String>[];
                        final String? idCreado = creado['id'] is String
                            ? creado['id'] as String
                            : null;
                        final String? usuarioCreado =
                            creado['usuario'] is String
                                ? creado['usuario'] as String
                                : null;

                        if (idCreado == null ||
                            usuarioCreado == null ||
                            usuarioCreado.isEmpty ||
                            !roles.contains('ADMINISTRADOR')) {
                          throw const ApiException(
                            statusCode: 500,
                            message:
                                'El servidor no confirmo el administrador creado',
                          );
                        }

                        if (!dialogContext.mounted) {
                          return;
                        }

                        Navigator.of(dialogContext).pop(<String, dynamic>{
                          ...creado,
                          '_organizacionNombre': organizacion.nombre,
                        });
                      } catch (error) {
                        if (dialogContext.mounted) {
                          mostrarMensaje(mensajeError(error));
                          setDialogState(() => guardandoDialog = false);
                        }
                      } finally {
                        setGuardando(false);
                      }
                    },
              icon: guardandoDialog
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Crear'),
            ),
          ],
        ),
      );
    },
  );

  organizacionController.dispose();
  organizacionFocusNode.dispose();
  nombreController.dispose();
  usuarioController.dispose();
  correoController.dispose();
  contrasenaController.dispose();

  return datos;
}
