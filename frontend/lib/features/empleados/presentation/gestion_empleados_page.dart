import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/constants/permisos_constants.dart';
import '../../../../core/formatters/app_formatters.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/ui/cobro_dropdown.dart';
import '../../../../core/ui/page_layout.dart';
import '../../../../data/models/models.dart';

const double _mobileBreakpoint = 760;

class PermisoEmpleadoDef {
  const PermisoEmpleadoDef({
    required this.codigo,
    required this.nombre,
  });

  final String codigo;
  final String nombre;
}

const List<PermisoEmpleadoDef> permisosEmpleado = <PermisoEmpleadoDef>[
  PermisoEmpleadoDef(
    codigo: permisoVerEmpleados,
    nombre: 'Ver empleados',
  ),
  PermisoEmpleadoDef(
    codigo: permisoCrearCajaMenor,
    nombre: 'Crear caja menor',
  ),
  PermisoEmpleadoDef(
    codigo: permisoRegistrarFlujoCaja,
    nombre: 'Registrar flujo en caja menor',
  ),
  PermisoEmpleadoDef(
    codigo: permisoCrearCreditos,
    nombre: 'Crear creditos',
  ),
  PermisoEmpleadoDef(
    codigo: permisoRefinanciarCreditos,
    nombre: 'Refinanciar creditos',
  ),
  PermisoEmpleadoDef(
    codigo: permisoModificarCreditos,
    nombre: 'Modificar creditos',
  ),
  PermisoEmpleadoDef(
    codigo: permisoEliminarCreditos,
    nombre: 'Eliminar creditos',
  ),
  PermisoEmpleadoDef(
    codigo: permisoModificarClientes,
    nombre: 'Modificar clientes',
  ),
  PermisoEmpleadoDef(
    codigo: permisoAgregarCuota,
    nombre: 'Agregar cuota',
  ),
  PermisoEmpleadoDef(
    codigo: permisoModificarMovimientos,
    nombre: 'Modificar movimientos',
  ),
  PermisoEmpleadoDef(
    codigo: permisoEliminarMovimientos,
    nombre: 'Eliminar movimientos',
  ),
];

class GestionEmpleadosPage extends StatefulWidget {
  const GestionEmpleadosPage({
    required this.apiClient,
    required this.cargarEmpleados,
    required this.cargarActividadEmpleados,
    required this.crearEmpleado,
    required this.modificarEmpleado,
    required this.puedeGestionar,
    required this.mensajeError,
    required this.mostrarMensaje,
    this.embebida = false,
    super.key,
  });

  final ApiClient apiClient;
  final Future<List<EmpleadoGestion>> Function() cargarEmpleados;
  final Future<List<ActividadEmpleado>> Function(
    ActividadEmpleadosFiltros filtros,
  ) cargarActividadEmpleados;
  final Future<bool> Function() crearEmpleado;
  final Future<EmpleadoGestion?> Function(EmpleadoGestion empleado)
      modificarEmpleado;
  final bool puedeGestionar;
  final String Function(Object error) mensajeError;
  final void Function(String message) mostrarMensaje;
  final bool embebida;

  @override
  State<GestionEmpleadosPage> createState() => _GestionEmpleadosPageState();
}

class _GestionEmpleadosPageState extends State<GestionEmpleadosPage> {
  List<EmpleadoGestion> _empleados = const <EmpleadoGestion>[];
  List<ActividadEmpleado> _actividades = const <ActividadEmpleado>[];
  late DateTime _actividadFechaInicio;
  late DateTime _actividadFechaFin;
  final TextEditingController _buscarActividadEmpleadoController =
      TextEditingController();
  String? _empleadoSeleccionadoId;
  Set<String> _permisosSeleccionados = Set<String>.of(
    permisosEmpleadoCodigos,
  );
  bool _aplicarATodos = false;
  bool _cargando = true;
  bool _cargandoActividad = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final DateTime hoy = _hoyColombia();
    _actividadFechaInicio = hoy;
    _actividadFechaFin = hoy;
    _buscarActividadEmpleadoController.addListener(_actualizarFiltroActividad);
    unawaited(_recargarEmpleados());
  }

  @override
  void dispose() {
    _buscarActividadEmpleadoController
        .removeListener(_actualizarFiltroActividad);
    _buscarActividadEmpleadoController.dispose();
    super.dispose();
  }

  EmpleadoGestion? _empleadoPorId(String? empleadoId) {
    for (final EmpleadoGestion empleado in _empleados) {
      if (empleado.id == empleadoId) {
        return empleado;
      }
    }
    return null;
  }

  DateTime _hoyColombia() {
    final DateTime ahora = fechaHoraColombia();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }

  bool get _actividadHoyActiva {
    final DateTime hoy = _hoyColombia();
    return _mismaFecha(_actividadFechaInicio, hoy) &&
        _mismaFecha(_actividadFechaFin, hoy);
  }

  bool get _actividadFiltrosActivos {
    return !_actividadHoyActiva ||
        _buscarActividadEmpleadoController.text.trim().isNotEmpty;
  }

  bool _mismaFecha(DateTime izquierda, DateTime derecha) {
    return izquierda.year == derecha.year &&
        izquierda.month == derecha.month &&
        izquierda.day == derecha.day;
  }

  ActividadEmpleadosFiltros _filtrosActividad() {
    return ActividadEmpleadosFiltros(
      fechaInicio: _actividadFechaInicio,
      fechaFin: _actividadFechaFin,
    );
  }

  List<ActividadEmpleado> get _actividadesFiltradas {
    final String consulta =
        _buscarActividadEmpleadoController.text.trim().toLowerCase();
    if (consulta.isEmpty) {
      return _actividades;
    }

    return _actividades.where((ActividadEmpleado actividad) {
      return actividad.nombreCompleto.toLowerCase().contains(consulta) ||
          actividad.usuario.toLowerCase().contains(consulta) ||
          actividad.correo.toLowerCase().contains(consulta);
    }).toList(growable: false);
  }

  String get _actividadPeriodoTexto {
    if (_actividadHoyActiva) {
      return 'Actividad de hoy';
    }

    if (_mismaFecha(_actividadFechaInicio, _actividadFechaFin)) {
      return 'Actividad del ${formatDateLabel(_actividadFechaInicio)}';
    }

    return 'Actividad del ${formatDateLabel(_actividadFechaInicio)} al '
        '${formatDateLabel(_actividadFechaFin)}';
  }

  void _actualizarFiltroActividad() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _recargarEmpleados() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<dynamic> resultados = await Future.wait<dynamic>([
        widget.cargarEmpleados(),
        widget.cargarActividadEmpleados(_filtrosActividad()),
      ]);
      final List<EmpleadoGestion> empleados =
          resultados[0] as List<EmpleadoGestion>;
      final List<ActividadEmpleado> actividades =
          resultados[1] as List<ActividadEmpleado>;
      if (!mounted) {
        return;
      }
      setState(() {
        _empleados = empleados;
        _actividades = actividades;
        _sincronizarSeleccion(resetPermisos: true);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = widget.mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _recargarActividadEmpleados() async {
    if (!mounted) {
      return;
    }
    setState(() => _cargandoActividad = true);

    try {
      final List<ActividadEmpleado> actividades =
          await widget.cargarActividadEmpleados(_filtrosActividad());
      if (!mounted) {
        return;
      }
      setState(() => _actividades = actividades);
    } catch (error) {
      widget.mostrarMensaje(widget.mensajeError(error));
    } finally {
      if (mounted) {
        setState(() => _cargandoActividad = false);
      }
    }
  }

  Future<void> _seleccionarFechaActividad({required bool esInicio}) async {
    final DateTime actual =
        esInicio ? _actividadFechaInicio : _actividadFechaFin;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (esInicio) {
        _actividadFechaInicio = selected;
        if (_actividadFechaFin.isBefore(selected)) {
          _actividadFechaFin = selected;
        }
      } else {
        _actividadFechaFin = selected;
        if (_actividadFechaInicio.isAfter(selected)) {
          _actividadFechaInicio = selected;
        }
      }
    });
    await _recargarActividadEmpleados();
  }

  Future<void> _mostrarActividadHoy() async {
    final DateTime hoy = _hoyColombia();
    setState(() {
      _actividadFechaInicio = hoy;
      _actividadFechaFin = hoy;
    });
    await _recargarActividadEmpleados();
  }

  Future<void> _limpiarFiltrosActividad() async {
    final DateTime hoy = _hoyColombia();
    setState(() {
      _actividadFechaInicio = hoy;
      _actividadFechaFin = hoy;
      _buscarActividadEmpleadoController.clear();
    });
    await _recargarActividadEmpleados();
  }

  void _sincronizarSeleccion({required bool resetPermisos}) {
    if (_empleados.isEmpty) {
      _empleadoSeleccionadoId = null;
      _permisosSeleccionados = Set<String>.of(permisosEmpleadoCodigos);
      return;
    }

    if (_aplicarATodos) {
      if (resetPermisos) {
        _permisosSeleccionados = Set<String>.of(permisosEmpleadoCodigos);
      }
      return;
    }

    final bool seleccionValida = _empleados.any(
      (EmpleadoGestion empleado) => empleado.id == _empleadoSeleccionadoId,
    );
    if (!seleccionValida) {
      _empleadoSeleccionadoId = _empleados.first.id;
    }

    if (resetPermisos) {
      _permisosSeleccionados =
          _empleadoPorId(_empleadoSeleccionadoId)?.permisos.toSet() ??
              Set<String>.of(permisosEmpleadoCodigos);
    }
  }

  void _seleccionarEmpleado(String? empleadoId) {
    final EmpleadoGestion? empleado = _empleadoPorId(empleadoId);
    setState(() {
      _aplicarATodos = false;
      _empleadoSeleccionadoId = empleado?.id;
      _permisosSeleccionados = empleado == null
          ? Set<String>.of(permisosEmpleadoCodigos)
          : empleado.permisos.toSet();
    });
  }

  Future<void> _crearEmpleado() async {
    if (_guardando || !widget.puedeGestionar) {
      return;
    }
    setState(() => _guardando = true);
    try {
      final bool creado = await widget.crearEmpleado();
      if (creado) {
        await _recargarEmpleados();
      }
    } catch (error) {
      widget.mostrarMensaje(widget.mensajeError(error));
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _modificarEmpleado(EmpleadoGestion empleado) async {
    if (_guardando || !widget.puedeGestionar) {
      return;
    }
    setState(() => _guardando = true);

    try {
      final EmpleadoGestion? actualizado =
          await widget.modificarEmpleado(empleado);
      if (!mounted || actualizado == null) {
        return;
      }
      setState(() {
        _empleados = _empleados
            .map(
              (EmpleadoGestion item) =>
                  item.id == actualizado.id ? actualizado : item,
            )
            .toList(growable: false);
        if (!_aplicarATodos && _empleadoSeleccionadoId == actualizado.id) {
          _permisosSeleccionados = actualizado.permisos.toSet();
        }
      });
      widget.mostrarMensaje('Empleado modificado');
    } catch (error) {
      widget.mostrarMensaje(widget.mensajeError(error));
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _actualizarEstadoEmpleado(
    EmpleadoGestion empleado,
    bool activo,
  ) async {
    if (_guardando || !widget.puedeGestionar) {
      return;
    }
    setState(() => _guardando = true);

    try {
      final EmpleadoGestion actualizado = EmpleadoGestion.fromJson(
        await widget.apiClient.patchObject(
          '/usuarios/${empleado.id}/estado',
          <String, dynamic>{'activo': activo},
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _empleados = _empleados
            .map(
              (EmpleadoGestion item) =>
                  item.id == actualizado.id ? actualizado : item,
            )
            .toList(growable: false);
        if (!_aplicarATodos && _empleadoSeleccionadoId == actualizado.id) {
          _permisosSeleccionados = actualizado.permisos.toSet();
        }
      });
      widget.mostrarMensaje(
        activo ? 'Empleado activado' : 'Empleado desactivado',
      );
    } catch (error) {
      widget.mostrarMensaje(widget.mensajeError(error));
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _guardarPermisos() async {
    final EmpleadoGestion? empleadoSeleccionado =
        _empleadoPorId(_empleadoSeleccionadoId);
    if (_guardando ||
        !widget.puedeGestionar ||
        _empleados.isEmpty ||
        (!_aplicarATodos && empleadoSeleccionado == null)) {
      return;
    }

    setState(() => _guardando = true);
    try {
      final List<dynamic> respuesta = await widget.apiClient.patchList(
        '/usuarios/permisos',
        <String, dynamic>{
          'todos': _aplicarATodos,
          if (!_aplicarATodos) 'usuarioIds': <String>[empleadoSeleccionado!.id],
          'permisos': _permisosSeleccionados.toList(growable: false),
        },
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _empleados = respuesta
            .map(
              (dynamic item) =>
                  EmpleadoGestion.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false);
        _sincronizarSeleccion(resetPermisos: !_aplicarATodos);
      });
      widget.mostrarMensaje('Permisos actualizados');
    } catch (error) {
      widget.mostrarMensaje(widget.mensajeError(error));
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esMovil = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final bool mostrarGuardarMovil = widget.puedeGestionar &&
        esMovil &&
        !_cargando &&
        _error == null &&
        _empleados.isNotEmpty;

    if (widget.embebida) {
      return _construirCuerpo(
        esMovil,
        usarBarraGuardarMovil: false,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de empleado'),
        actions: <Widget>[
          Tooltip(
            message: 'Recargar',
            child: IconButton(
              onPressed: _cargando || _guardando ? null : _recargarEmpleados,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          if (!esMovil && widget.puedeGestionar)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _guardando ? null : _crearEmpleado,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Agregar empleado'),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.clay.border),
        ),
      ),
      body: SafeArea(
        bottom: !esMovil,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.clay.background),
          child: _construirCuerpo(
            esMovil,
            usarBarraGuardarMovil: true,
          ),
        ),
      ),
      floatingActionButton:
          esMovil && widget.puedeGestionar && !_cargando && _error == null
              ? FloatingActionButton(
                  onPressed: _guardando ? null : _crearEmpleado,
                  tooltip: 'Agregar empleado',
                  child: const Icon(Icons.person_add_alt_1_rounded),
                )
              : null,
      bottomNavigationBar:
          mostrarGuardarMovil ? _construirBarraGuardarMovil() : null,
    );
  }

  Widget _construirCuerpo(
    bool esMovil, {
    required bool usarBarraGuardarMovil,
  }) {
    if (_cargando && _empleados.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _empleados.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: EstadoVacio(
              icono: Icons.warning_amber_rounded,
              titulo: 'No se pudo cargar',
              mensaje: _error!,
              accion: OutlinedButton.icon(
                onPressed: _recargarEmpleados,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _recargarEmpleados,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          esMovil ? 14 : 24,
          esMovil ? 14 : 24,
          esMovil ? 14 : 24,
          esMovil && usarBarraGuardarMovil ? 112 : 28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _construirEncabezado(esMovil),
                const SizedBox(height: 14),
                if (esMovil)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _construirPanelEmpleados(),
                      if (widget.puedeGestionar) ...<Widget>[
                        const SizedBox(height: 14),
                        _construirPanelPermisos(
                          esMovil,
                          usarBarraGuardarMovil: usarBarraGuardarMovil,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _construirPanelActividad(esMovil),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 390,
                        child: _construirPanelEmpleados(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (widget.puedeGestionar) ...<Widget>[
                              _construirPanelPermisos(
                                esMovil,
                                usarBarraGuardarMovil: usarBarraGuardarMovil,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _construirPanelActividad(esMovil),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirEncabezado(bool esMovil) {
    final int activos =
        _empleados.where((EmpleadoGestion e) => e.activo).length;
    final int inactivos = _empleados.length - activos;

    return ClaySurface(
      radius: 18,
      padding: EdgeInsets.all(esMovil ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ClayIcon(icon: Icons.manage_accounts_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Gestion de empleado',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.puedeGestionar
                          ? 'Administra empleados, permisos y actividad diaria.'
                          : 'Consulta el equipo y la actividad diaria.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.clay.subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              EmpleadoGestionMetrica(
                icono: Icons.groups_rounded,
                etiqueta: 'Empleados',
                valor: _empleados.length.toString(),
              ),
              EmpleadoGestionMetrica(
                icono: Icons.check_circle_rounded,
                etiqueta: 'Activos',
                valor: activos.toString(),
                color: CobroAppTheme.success,
              ),
              EmpleadoGestionMetrica(
                icono: Icons.pause_circle_rounded,
                etiqueta: 'Inactivos',
                valor: inactivos.toString(),
                color: CobroAppTheme.danger,
              ),
            ],
          ),
          if (widget.embebida) ...<Widget>[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: esMovil ? double.infinity : null,
                child: FilledButton.icon(
                  onPressed: _guardando ? null : _crearEmpleado,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Agregar empleado'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirPanelEmpleados() {
    return ClaySurface(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Empleados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (_cargando)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_empleados.isEmpty)
            const MensajePanel(
              icono: Icons.groups_outlined,
              titulo: 'Sin empleados',
              mensaje: 'Agrega un empleado para asignar permisos.',
            )
          else
            ..._empleados.map(
              (EmpleadoGestion empleado) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: EmpleadoGestionItem(
                  empleado: empleado,
                  seleccionado:
                      empleado.id == _empleadoSeleccionadoId && !_aplicarATodos,
                  guardando: _guardando,
                  puedeGestionar: widget.puedeGestionar,
                  onSeleccionar: () => _seleccionarEmpleado(empleado.id),
                  onModificar: () => _modificarEmpleado(empleado),
                  onActivoChanged: (bool activo) =>
                      _actualizarEstadoEmpleado(empleado, activo),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirPanelPermisos(
    bool esMovil, {
    required bool usarBarraGuardarMovil,
  }) {
    final EmpleadoGestion? empleadoSeleccionado =
        _empleadoPorId(_empleadoSeleccionadoId);
    final String destinoPermisos = _aplicarATodos
        ? 'Todos los empleados'
        : empleadoSeleccionado?.nombreCompleto ?? 'Selecciona un empleado';

    return ClaySurface(
      radius: 18,
      padding: EdgeInsets.all(esMovil ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Permisos de empleados',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      destinoPermisos,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.clay.subtleText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              if (!esMovil) const Icon(Icons.admin_panel_settings_rounded),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _aplicarATodos,
            onChanged: _guardando || _empleados.isEmpty
                ? null
                : (bool value) {
                    setState(() {
                      _aplicarATodos = value;
                      if (value) {
                        _permisosSeleccionados = Set<String>.of(
                          permisosEmpleadoCodigos,
                        );
                      } else {
                        _empleadoSeleccionadoId ??= _empleados.first.id;
                        _permisosSeleccionados =
                            _empleadoPorId(_empleadoSeleccionadoId)
                                    ?.permisos
                                    .toSet() ??
                                Set<String>.of(permisosEmpleadoCodigos);
                      }
                    });
                  },
            title: const Text('Aplicar a todos los empleados'),
            secondary: const Icon(Icons.groups_rounded),
            contentPadding: EdgeInsets.zero,
          ),
          if (!_aplicarATodos && _empleados.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            CobroDropdownField<String>(
              key: ValueKey<String?>(_empleadoSeleccionadoId),
              labelText: 'Empleado',
              prefixIcon: const Icon(Icons.person_rounded),
              value: _empleadoSeleccionadoId,
              items: _empleados.map((EmpleadoGestion empleado) {
                final String inicial = empleado.nombreCompleto.trim().isNotEmpty
                    ? empleado.nombreCompleto
                        .trim()
                        .substring(0, 1)
                        .toUpperCase()
                    : '?';
                return CobroDropdownItem<String>(
                  value: empleado.id,
                  label: empleado.nombreCompleto,
                  subtitle: empleado.usuario.isNotEmpty
                      ? '@${empleado.usuario}'
                      : null,
                  avatarText: inicial,
                );
              }).toList(growable: false),
              onChanged: _guardando ? null : _seleccionarEmpleado,
            ),
          ],
          const SizedBox(height: 16),
          if (_empleados.isEmpty)
            const MensajePanel(
              icono: Icons.lock_open_rounded,
              titulo: 'Permisos pendientes',
              mensaje: 'Cuando agregues empleados podras asignar accesos.',
            )
          else
            ...permisosEmpleado.map(
              (PermisoEmpleadoDef permiso) => CheckboxListTile(
                value: _permisosSeleccionados.contains(permiso.codigo),
                onChanged: _guardando
                    ? null
                    : (bool? value) {
                        setState(() {
                          if (value ?? false) {
                            _permisosSeleccionados.add(permiso.codigo);
                          } else {
                            _permisosSeleccionados.remove(permiso.codigo);
                          }
                        });
                      },
                title: Text(permiso.nombre),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!esMovil || !usarBarraGuardarMovil) ...<Widget>[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _construirGuardarPermisosButton(expandido: esMovil),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirPanelActividad(bool esMovil) {
    final List<ActividadEmpleado> actividades = _actividadesFiltradas;

    return ClaySurface(
      radius: 18,
      padding: EdgeInsets.all(esMovil ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Actividad de los empleados',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _actividadPeriodoTexto,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.clay.subtleText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              if (_cargando)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_cargandoActividad)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.timeline_rounded),
            ],
          ),
          const SizedBox(height: 12),
          _construirFiltrosActividad(esMovil),
          const SizedBox(height: 12),
          if (_actividades.isEmpty)
            const MensajePanel(
              icono: Icons.route_outlined,
              titulo: 'Sin actividad',
              mensaje: 'No hay rutas, creditos o recaudos para mostrar.',
            )
          else if (actividades.isEmpty)
            const MensajePanel(
              icono: Icons.search_off_rounded,
              titulo: 'Sin resultados',
              mensaje: 'No hay empleados que coincidan con el filtro.',
            )
          else
            ...actividades.map(
              (ActividadEmpleado actividad) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ActividadEmpleadoCard(actividad: actividad),
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirFiltrosActividad(bool esMovil) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (!esMovil)
          SizedBox(
            width: 260,
            child: TextField(
              controller: _buscarActividadEmpleadoController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Buscar empleado',
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _actividadHoyActiva || _cargandoActividad
              ? null
              : _mostrarActividadHoy,
          icon: const Icon(Icons.today_rounded),
          label: const Text('Hoy'),
        ),
        OutlinedButton.icon(
          onPressed: _cargandoActividad
              ? null
              : () => _seleccionarFechaActividad(esInicio: true),
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text('Inicio ${formatDateLabel(_actividadFechaInicio)}'),
        ),
        OutlinedButton.icon(
          onPressed: _cargandoActividad
              ? null
              : () => _seleccionarFechaActividad(esInicio: false),
          icon: const Icon(Icons.event_available_rounded),
          label: Text('Fin ${formatDateLabel(_actividadFechaFin)}'),
        ),
        if (_actividadFiltrosActivos)
          Tooltip(
            message: 'Limpiar filtros',
            child: IconButton.outlined(
              onPressed: _cargandoActividad ? null : _limpiarFiltrosActividad,
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
          ),
      ],
    );
  }

  Widget _construirGuardarPermisosButton({required bool expandido}) {
    final EmpleadoGestion? empleadoSeleccionado =
        _empleadoPorId(_empleadoSeleccionadoId);
    final bool habilitado = !_guardando &&
        widget.puedeGestionar &&
        _empleados.isNotEmpty &&
        (_aplicarATodos || empleadoSeleccionado != null);
    final Widget button = FilledButton.icon(
      onPressed: habilitado ? _guardarPermisos : null,
      icon: _guardando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_rounded),
      label: const Text('Guardar permisos'),
    );

    return expandido ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _construirBarraGuardarMovil() {
    return ColoredBox(
      color: context.clay.background,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: _construirGuardarPermisosButton(expandido: true),
      ),
    );
  }
}

class ActividadEmpleadoCard extends StatelessWidget {
  const ActividadEmpleadoCard({super.key, required this.actividad});

  final ActividadEmpleado actividad;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Color estadoColor = switch (actividad.estadoRuta) {
      EstadoActividadEmpleado.cumplido => CobroAppTheme.success,
      EstadoActividadEmpleado.pendiente => CobroAppTheme.warning,
      EstadoActividadEmpleado.sinRutaHoy => CobroAppTheme.primary,
    };
    final String estadoTexto = switch (actividad.estadoRuta) {
      EstadoActividadEmpleado.cumplido => 'Cumplido',
      EstadoActividadEmpleado.pendiente => 'Pendiente',
      EstadoActividadEmpleado.sinRutaHoy => 'Sin ruta hoy',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: clay.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: clay.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: estadoColor.withValues(alpha: 0.12),
                  foregroundColor: estadoColor,
                  child: Text(
                    actividad.nombreCompleto.isEmpty
                        ? '?'
                        : actividad.nombreCompleto
                            .substring(0, 1)
                            .toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        actividad.nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${actividad.usuario} - ${actividad.rutas.length} rutas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: clay.subtleText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  estadoTexto,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: estadoColor,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: actividad.porcentajeCumplimiento / 100,
                backgroundColor: clay.border.withValues(alpha: 0.42),
                valueColor: AlwaysStoppedAnimation<Color>(estadoColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${actividad.resumen.cumplidosHoy}/${actividad.resumen.deberesHoy} deberes cumplidos hoy',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: clay.subtleText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ActividadDato(
                  icono: Icons.payments_rounded,
                  etiqueta: 'Recaudo hoy',
                  valor: formatMoney(actividad.resumen.recaudoHoy),
                  color: CobroAppTheme.success,
                ),
                ActividadDato(
                  icono: Icons.calendar_month_rounded,
                  etiqueta: 'Recaudo mes',
                  valor: formatMoney(actividad.resumen.recaudoMes),
                ),
                ActividadDato(
                  icono: Icons.add_business_rounded,
                  etiqueta: 'Creditos mes',
                  valor: actividad.resumen.creditosMes.toString(),
                ),
                ActividadDato(
                  icono: Icons.warning_amber_rounded,
                  etiqueta: 'Pendientes',
                  valor: actividad.resumen.pendientesHoy.toString(),
                  color: actividad.resumen.pendientesHoy > 0
                      ? CobroAppTheme.warning
                      : CobroAppTheme.success,
                ),
                ActividadDato(
                  icono: Icons.priority_high_rounded,
                  etiqueta: 'Atrasados',
                  valor: actividad.resumen.atrasados.toString(),
                  color: actividad.resumen.atrasados > 0
                      ? CobroAppTheme.danger
                      : CobroAppTheme.success,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (actividad.rutas.isEmpty)
              Text(
                'Sin rutas asignadas por creditos creados.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: clay.subtleText,
                      fontWeight: FontWeight.w700,
                    ),
              )
            else
              Column(
                children: actividad.rutas
                    .map(
                      (ActividadRutaEmpleado ruta) => ActividadRutaRow(
                        ruta: ruta,
                      ),
                    )
                    .toList(growable: false),
              ),
            if (actividad.ultimaActividad != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Ultima actividad ${formatDateTimeLabel(actividad.ultimaActividad)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: clay.subtleText,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ActividadDato extends StatelessWidget {
  const ActividadDato({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = color ?? Theme.of(context).colorScheme.primary;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icono, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.clay.subtleText,
                          ),
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

class ActividadRutaRow extends StatelessWidget {
  const ActividadRutaRow({super.key, required this.ruta});

  final ActividadRutaEmpleado ruta;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final int deberes = ruta.debenHoy;
    final int cumplidos = ruta.cumplidosHoy;
    final double progreso = deberes == 0 ? 1 : cumplidos / deberes;
    final Color color = ruta.pendientesHoy > 0 || ruta.atrasados > 0
        ? CobroAppTheme.warning
        : CobroAppTheme.success;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: clay.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.route_rounded, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ruta.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    formatMoney(ruta.recaudadoHoy),
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: math.max(0.0, math.min(1.0, progreso)),
                  backgroundColor: clay.border.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${ruta.creditos} creditos - ${ruta.clientes} clientes - '
                '$cumplidos/$deberes hoy - ${ruta.atrasados} atrasados',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: clay.subtleText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmpleadoGestionMetrica extends StatelessWidget {
  const EmpleadoGestionMetrica({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Color acento = color ?? Theme.of(context).colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          acento.withValues(alpha: clay.isDark ? 0.16 : 0.09),
          clay.surfaceHigh,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: acento.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icono, size: 18, color: acento),
            const SizedBox(width: 8),
            Text(
              valor,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: acento,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(width: 5),
            Text(
              etiqueta,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: clay.subtleText,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class MensajePanel extends StatelessWidget {
  const MensajePanel({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: <Widget>[
          Icon(icono, size: 34, color: CobroAppTheme.primary),
          const SizedBox(height: 9),
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.clay.subtleText,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class EmpleadoGestionItem extends StatelessWidget {
  const EmpleadoGestionItem({
    super.key,
    required this.empleado,
    required this.seleccionado,
    required this.guardando,
    required this.puedeGestionar,
    required this.onSeleccionar,
    required this.onModificar,
    required this.onActivoChanged,
  });

  final EmpleadoGestion empleado;
  final bool seleccionado;
  final bool guardando;
  final bool puedeGestionar;
  final VoidCallback onSeleccionar;
  final VoidCallback onModificar;
  final ValueChanged<bool> onActivoChanged;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Color estadoColor =
        empleado.activo ? CobroAppTheme.success : CobroAppTheme.danger;
    final int permisosActivos = empleado.permisos.length;

    return ClaySurface(
      radius: 12,
      padding: EdgeInsets.zero,
      color: seleccionado ? clay.surfaceHigh : clay.surface,
      borderColor: seleccionado
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.42)
          : clay.border,
      onTap: guardando ? null : onSeleccionar,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget avatar = CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            foregroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              empleado.nombreCompleto.isEmpty
                  ? '?'
                  : empleado.nombreCompleto.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          );
          final Widget estado = Text(
            empleado.activo ? 'Activo' : 'Inactivo',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: estadoColor,
                  fontWeight: FontWeight.w900,
                ),
          );
          final Widget switchEstado = Switch(
            value: empleado.activo,
            onChanged: guardando || !puedeGestionar ? null : onActivoChanged,
          );
          final Widget? botonEditar = puedeGestionar
              ? IconButton(
                  tooltip: 'Modificar empleado',
                  onPressed: guardando ? null : onModificar,
                  icon: const Icon(Icons.edit_outlined),
                )
              : null;

          if (constraints.maxWidth >= 380) {
            return ListTile(
              leading: avatar,
              title: Text(
                empleado.nombreCompleto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${empleado.usuario} - $permisosActivos permisos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  estado,
                  if (botonEditar != null) botonEditar,
                  switchEstado,
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            empleado.nombreCompleto,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            empleado.usuario,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: clay.subtleText,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (botonEditar != null) botonEditar,
                    switchEstado,
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    estado,
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$permisosActivos permisos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
