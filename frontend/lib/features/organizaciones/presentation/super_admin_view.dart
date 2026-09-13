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
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _DialogoDatosOrganizacionAdminContent(
      organizacion: organizacion,
      mostrarMensaje: mostrarMensaje,
    ),
  );
}

class _DialogoDatosOrganizacionAdminContent extends StatefulWidget {
  const _DialogoDatosOrganizacionAdminContent({
    this.organizacion,
    required this.mostrarMensaje,
  });

  final OrganizacionAdmin? organizacion;
  final void Function(String) mostrarMensaje;

  @override
  State<_DialogoDatosOrganizacionAdminContent> createState() =>
      _DialogoDatosOrganizacionAdminContentState();
}

class _DialogoDatosOrganizacionAdminContentState
    extends State<_DialogoDatosOrganizacionAdminContent> {
  late final TextEditingController _nombreController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _correoController;
  late final TextEditingController _montoController;
  late final TextEditingController _accesoController;
  late String _moneda;
  late DateTime? _accesoHasta;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.organizacion?.nombre ?? '',
    );
    _telefonoController = TextEditingController(
      text: widget.organizacion?.telefono ?? '',
    );
    _correoController = TextEditingController(
      text: widget.organizacion?.correo ?? '',
    );
    _montoController = TextEditingController(
      text: formatNumber(widget.organizacion?.montoPlan ?? 0),
    );
    _accesoController = TextEditingController(
      text: widget.organizacion?.accesoHasta ?? '',
    );
    _moneda = widget.organizacion?.monedaPlan ?? 'COP';
    _accesoHasta = widget.organizacion?.accesoHasta == null
        ? null
        : DateTime.tryParse(widget.organizacion!.accesoHasta!);
  }

  @override
  void dispose() {
    _montoController.dispose();
    _accesoController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  void _guardar() {
    final String nombre = _nombreController.text.trim();
    final String telefono = _telefonoController.text.trim();
    final String correo = _correoController.text.trim().toLowerCase();
    final double? monto = parseNumero(_montoController.text);

    if (nombre.length < 3) {
      widget.mostrarMensaje('El nombre debe tener minimo 3 caracteres');
      return;
    }

    if (correo.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) {
      widget.mostrarMensaje('Ingresa un email valido');
      return;
    }

    if (monto == null || monto < 0) {
      widget.mostrarMensaje('Ingresa un monto valido');
      return;
    }

    Navigator.of(context).pop(<String, dynamic>{
      'nombre': nombre,
      'telefono': telefono.isEmpty ? null : telefono,
      'correo': correo.isEmpty ? null : correo,
      'montoPlan': monto,
      'monedaPlan': _moneda,
      'accesoHasta': _accesoHasta == null
          ? null
          : formatDateValue(_accesoHasta!),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.organizacion == null ? 'Crear institucion' : 'Editar institucion',
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _nombreController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.business_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  prefixIcon: Icon(Icons.call_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _correoController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _montoController,
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
                value: _moneda,
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
                    setState(() => _moneda = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accesoController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Acceso hasta',
                  hintText: 'Sin vencimiento',
                  prefixIcon: const Icon(Icons.event_available_rounded),
                  suffixIcon: _accesoHasta == null
                      ? const Icon(Icons.calendar_month_rounded)
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              _accesoHasta = null;
                              _accesoController.clear();
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Quitar fecha',
                        ),
                ),
                onTap: () async {
                  final DateTime initialDate =
                      _accesoHasta ?? DateTime.now();
                  final DateTime? selected = await showDatePicker(
                    context: context,
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
                    setState(() {
                      _accesoHasta = selected;
                      _accesoController.text = formatDateValue(selected);
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

Future<Map<String, dynamic>?> pedirDatosAdministradorAdmin(
  BuildContext context, {
  required List<OrganizacionAdmin> organizaciones,
  required ApiClient apiClient,
  required void Function(String) mostrarMensaje,
  required String Function(Object) mensajeError,
  required void Function(bool) setGuardando,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _DialogoDatosAdministradorAdminContent(
      organizaciones: organizaciones,
      apiClient: apiClient,
      mostrarMensaje: mostrarMensaje,
      mensajeError: mensajeError,
      setGuardando: setGuardando,
    ),
  );
}

class _DialogoDatosAdministradorAdminContent extends StatefulWidget {
  const _DialogoDatosAdministradorAdminContent({
    required this.organizaciones,
    required this.apiClient,
    required this.mostrarMensaje,
    required this.mensajeError,
    required this.setGuardando,
  });

  final List<OrganizacionAdmin> organizaciones;
  final ApiClient apiClient;
  final void Function(String) mostrarMensaje;
  final String Function(Object) mensajeError;
  final void Function(bool) setGuardando;

  @override
  State<_DialogoDatosAdministradorAdminContent> createState() =>
      _DialogoDatosAdministradorAdminContentState();
}

class _DialogoDatosAdministradorAdminContentState
    extends State<_DialogoDatosAdministradorAdminContent> {
  late final TextEditingController _organizacionController;
  late final FocusNode _organizacionFocusNode;
  late final TextEditingController _nombreController;
  late final TextEditingController _usuarioController;
  late final TextEditingController _correoController;
  late final TextEditingController _contrasenaController;
  late OrganizacionAdmin? _organizacionSeleccionada;
  bool _mostrarContrasena = false;
  bool _guardandoDialog = false;

  @override
  void initState() {
    super.initState();
    final OrganizacionAdmin organizacionInicial = widget.organizaciones.first;
    _organizacionController =
        TextEditingController(text: organizacionInicial.nombre);
    _organizacionFocusNode = FocusNode();
    _nombreController = TextEditingController();
    _usuarioController = TextEditingController();
    _correoController = TextEditingController();
    _contrasenaController = TextEditingController();
    _organizacionSeleccionada = organizacionInicial;
  }

  @override
  void dispose() {
    _organizacionController.dispose();
    _organizacionFocusNode.dispose();
    _nombreController.dispose();
    _usuarioController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _crearAdministrador() async {
    final OrganizacionAdmin? organizacion = _organizacionSeleccionada;
    final String nombre = _nombreController.text.trim();
    final String usuario = _usuarioController.text.trim().toLowerCase();
    final String correo = _correoController.text.trim().toLowerCase();
    final String contrasena = _contrasenaController.text;

    if (organizacion == null) {
      widget.mostrarMensaje('Selecciona una institucion');
      return;
    }

    if (nombre.length < 3) {
      widget.mostrarMensaje('El nombre debe tener minimo 3 caracteres');
      return;
    }

    if (usuario.length < 3 ||
        !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(usuario)) {
      widget.mostrarMensaje('El usuario debe tener minimo 3 caracteres validos');
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) {
      widget.mostrarMensaje('Ingresa un email valido');
      return;
    }

    if (contrasena.length < 12) {
      widget.mostrarMensaje('La contrasena debe tener 12 caracteres');
      return;
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'organizacionId': organizacion.id,
      'nombreCompleto': nombre,
      'usuario': usuario,
      'correo': correo,
      'contrasena': contrasena,
    };

    setState(() => _guardandoDialog = true);
    widget.setGuardando(true);

    try {
      final Map<String, dynamic> creado = await widget.apiClient.postObject(
        '/super-admin/usuarios/admin',
        body,
      );
      final Object? rawRoles = creado['roles'];
      final List<String> roles = rawRoles is List<dynamic>
          ? rawRoles.whereType<String>().toList(growable: false)
          : const <String>[];
      final String? idCreado =
          creado['id'] is String ? creado['id'] as String : null;
      final String? usuarioCreado =
          creado['usuario'] is String ? creado['usuario'] as String : null;

      if (idCreado == null ||
          usuarioCreado == null ||
          usuarioCreado.isEmpty ||
          !roles.contains('ADMINISTRADOR')) {
        throw const ApiException(
          statusCode: 500,
          message: 'El servidor no confirmo el administrador creado',
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(<String, dynamic>{
        ...creado,
        '_organizacionNombre': organizacion.nombre,
      });
    } catch (error) {
      if (mounted) {
        widget.mostrarMensaje(widget.mensajeError(error));
        setState(() => _guardandoDialog = false);
      }
    } finally {
      widget.setGuardando(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear administrador'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              OrganizacionAdminPicker(
                organizaciones: widget.organizaciones,
                controller: _organizacionController,
                focusNode: _organizacionFocusNode,
                seleccionada: _organizacionSeleccionada,
                onChanged: (OrganizacionAdmin? value) {
                  setState(() => _organizacionSeleccionada = value);
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
                controller: _nombreController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usuarioController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _correoController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contrasenaController,
                obscureText: !_mostrarContrasena,
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  helperText: 'Minimo 12 caracteres',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _mostrarContrasena = !_mostrarContrasena);
                    },
                    icon: Icon(
                      _mostrarContrasena
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
          onPressed: _guardandoDialog ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardandoDialog ? null : _crearAdministrador,
          icon: _guardandoDialog
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Crear'),
        ),
      ],
    );
  }
}
