export '../../../data/models/models.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_theme.dart';
import '../../../app/session_cache.dart';
import '../../../core/constants/permisos_constants.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/offline_mutation.dart';
import '../../../core/ui/marca_aplicacion.dart';
import '../../../core/ui/page_layout.dart';
import '../../../data/models/models.dart';
import '../../auth/presentation/login_view.dart';
import '../../caja_menor/presentation/caja_menor_view.dart';
import '../../caja_menor/presentation/dialogs/caja_menor_dialogs.dart';
import '../../clientes/presentation/clientes_view.dart';
import '../../clientes/presentation/dialogs/cliente_dialogs.dart';
import '../../creditos/presentation/creditos_view.dart';
import '../../creditos/presentation/dialogs/credito_dialogs.dart';
import '../../dashboard/presentation/widgets/exportacion_helpers.dart';
import '../../empleados/presentation/dialogs/empleado_dialogs.dart';
import '../../empleados/presentation/gestion_empleados_page.dart';
import '../../organizaciones/presentation/super_admin_view.dart';
import '../../presupuesto/presentation/inicio_presupuesto_view.dart';
import '../../rutas/presentation/dialogs/pago_ruta_dialogs.dart';
import '../../rutas/presentation/ruta_cobro_view.dart';
import '../../routes/data/api_road_router.dart';
import '../../routes/data/device_location_service.dart';
import '../../routes/presentation/desktop_collection_route.dart';

part 'dashboard_charts.dart';

const String _permisoVerEmpleados = permisoVerEmpleados;
const String _permisoCrearCajaMenor = permisoCrearCajaMenor;
const String _permisoRegistrarFlujoCaja = permisoRegistrarFlujoCaja;
const String _permisoCrearCreditos = permisoCrearCreditos;
const String _permisoRefinanciarCreditos = permisoRefinanciarCreditos;
const String _permisoModificarCreditos = permisoModificarCreditos;
const String _permisoEliminarCreditos = permisoEliminarCreditos;
const String _permisoAgregarCuota = permisoAgregarCuota;
const String _permisoModificarMovimientos = permisoModificarMovimientos;
const String _permisoEliminarMovimientos = permisoEliminarMovimientos;

class HomePage extends StatefulWidget {
  const HomePage({
    required this.apiBaseUrl,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.apiClient,
    super.key,
  });

  final String apiBaseUrl;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ApiClient? apiClient;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ApiClient _apiClient;
  late final ApiRoadRouter _roadRouter;
  late final bool _cerrarApiClientAlSalir;
  static const double _mobileBreakpoint = 760;
  static const int _pageSize = 40;
  static const String _todasLasCajasFiltro = todasLasCajasFiltro;
  static const int _indiceCredito = 2;
  static const int _indiceGestionEmpleados = 5;
  static const List<_DestinoMenu> _destinosMenuBase = <_DestinoMenu>[
    _DestinoMenu(
      icono: Icons.home_outlined,
      iconoSeleccionado: Icons.home_rounded,
      etiqueta: 'Inicio',
    ),
    _DestinoMenu(
      icono: Icons.route_outlined,
      iconoSeleccionado: Icons.route_rounded,
      etiqueta: 'Ruta',
    ),
    _DestinoMenu(
      icono: Icons.add_business_outlined,
      iconoSeleccionado: Icons.add_business_rounded,
      etiqueta: 'Credito',
    ),
    _DestinoMenu(
      icono: Icons.savings_outlined,
      iconoSeleccionado: Icons.savings_rounded,
      etiqueta: 'Caja menor',
    ),
    _DestinoMenu(
      icono: Icons.groups_outlined,
      iconoSeleccionado: Icons.groups_rounded,
      etiqueta: 'Cliente',
    ),
  ];
  static const _DestinoMenu _destinoGestionEmpleados = _DestinoMenu(
    icono: Icons.manage_accounts_outlined,
    iconoSeleccionado: Icons.manage_accounts_rounded,
    etiqueta: 'Empleado',
  );

  final TextEditingController _buscarRutaController = TextEditingController();
  final TextEditingController _buscarCajaInicioController =
      TextEditingController();
  final TextEditingController _buscarCreditoController =
      TextEditingController();
  final TextEditingController _buscarCajaController = TextEditingController();
  final TextEditingController _buscarClienteController =
      TextEditingController();
  final TextEditingController _loginUsuarioController = TextEditingController();
  final TextEditingController _loginContrasenaController =
      TextEditingController();

  SesionUsuario? _usuarioSesion;
  Catalogos? _catalogos;
  Presupuesto? _presupuesto;
  List<Cliente> _clientes = const <Cliente>[];
  List<CobroRuta> _cobrosRuta = const <CobroRuta>[];
  List<CreditoRegistro> _creditos = const <CreditoRegistro>[];
  List<MovimientoCaja> _movimientosCaja = const <MovimientoCaja>[];
  List<OrganizacionAdmin> _organizacionesAdmin = const <OrganizacionAdmin>[];
  ConteoCreditosInicio _conteoCreditosInicio =
      const ConteoCreditosInicio.vacio();
  int _siguienteOffsetCreditos = 0;
  int _siguienteOffsetMovimientosCaja = 0;
  bool _hayMasCreditos = false;
  bool _hayMasMovimientosCaja = false;
  bool _cargandoCreditos = false;
  bool _cargandoMovimientosCaja = false;
  bool _cargandoMasCreditos = false;
  bool _cargandoMasMovimientosCaja = false;

  int _seccionActual = 0;
  bool _cargando = false;
  bool _guardando = false;
  bool _exportando = false;
  bool _menuLateralExpandido = true;
  FiltroEstadoRuta _filtroEstadoRuta = FiltroEstadoRuta.todos;
  FiltroEstadoCredito _filtroCredito = FiltroEstadoCredito.todos;
  FiltroMovimientoCaja _filtroMovimientoCaja = FiltroMovimientoCaja.todos;
  final Set<String> _cuotasEnPago = <String>{};
  final Set<String> _cobrosConPagoInstantaneo = <String>{};
  String? _error;
  OverlayEntry? _mensajeOverlay;
  Timer? _mensajeTimer;
  Timer? _refrescoTimer;
  Timer? _filtrosListasTimer;
  Timer? _offlineSyncTimer;
  int _cargaSerial = 0;
  int _accionesPendientesOffline = 0;
  bool _sincronizandoOffline = false;
  DateTime? _fechaCajaDesde;
  DateTime? _fechaCajaHasta;
  DateTime? _fechaInicioDesde;
  DateTime? _fechaInicioHasta;
  String? _cajaInicioFiltroId;
  DateTime? _fechaCreditoDesde;
  DateTime? _fechaCreditoHasta;
  String? _cajaMenorFiltroId;
  String? _rutaFiltroId;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient(baseUrl: widget.apiBaseUrl);
    _roadRouter = ApiRoadRouter(_apiClient);
    _cerrarApiClientAlSalir = widget.apiClient == null;
    _aplicarFechaInicioHoy();
    _buscarRutaController.addListener(_refrescar);
    _buscarCajaInicioController.addListener(_programarRecargaPresupuesto);
    _buscarCreditoController.addListener(_programarRecargaListasPesadas);
    _buscarCajaController.addListener(_programarRecargaListasPesadas);
    _buscarClienteController.addListener(_refrescar);
    unawaited(_cargarAccionesPendientesOffline());
    unawaited(_restaurarSesionGuardada());
    _refrescoTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) {
        if (mounted && _usuarioSesion != null) {
          _recargarEnSegundoPlano();
        }
      },
    );
    _offlineSyncTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (mounted && _usuarioSesion != null) {
          _sincronizarAccionesOffline();
        }
      },
    );
  }

  List<_DestinoMenu> get _destinosMenuActual {
    if (_puedeVerEmpleados) {
      return <_DestinoMenu>[
        ..._destinosMenuBase,
        _destinoGestionEmpleados,
      ];
    }
    return _destinosMenuBase;
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apiClient != oldWidget.apiClient && widget.apiClient != null) {
      _apiClient = widget.apiClient!;
      _roadRouter = ApiRoadRouter(_apiClient);
    }
  }

  @override
  void dispose() {
    _mensajeTimer?.cancel();
    _refrescoTimer?.cancel();
    _filtrosListasTimer?.cancel();
    _offlineSyncTimer?.cancel();
    _mensajeOverlay?.remove();
    if (_cerrarApiClientAlSalir) {
      _apiClient.close();
    }
    _buscarRutaController.dispose();
    _buscarCajaInicioController.dispose();
    _buscarCreditoController.dispose();
    _buscarCajaController.dispose();
    _buscarClienteController.dispose();
    _loginUsuarioController.dispose();
    _loginContrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SesionUsuario? usuarioSesion = _usuarioSesion;
    final bool esMovil = MediaQuery.sizeOf(context).width < _mobileBreakpoint;

    if (usuarioSesion == null) {
      return LoginView(
        usuarioController: _loginUsuarioController,
        contrasenaController: _loginContrasenaController,
        guardando: _guardando,
        error: _error,
        onIniciarSesion: _iniciarSesion,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const MarcaAplicacion(),
        actions: <Widget>[
          if (!esMovil) ...<Widget>[
            if (_accionesPendientesOffline > 0)
              Tooltip(
                message: _sincronizandoOffline
                    ? 'Sincronizando acciones pendientes'
                    : 'Sincronizar acciones pendientes',
                child: IconButton(
                  onPressed: _sincronizandoOffline
                      ? null
                      : _sincronizarAccionesOffline,
                  icon: Badge(
                    label: Text('$_accionesPendientesOffline'),
                    child: const Icon(Icons.cloud_sync_rounded),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    usuarioSesion.nombreCompleto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: context.clay.subtleText,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Recargar',
              child: IconButton(
                onPressed: _cargando ? null : _cargar,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Cambiar tema',
              child: IconButton(
                onPressed: () {
                  widget.onThemeModeChanged(
                    widget.themeMode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  );
                },
                icon: Icon(
                  widget.themeMode == ThemeMode.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Cerrar sesion',
              child: IconButton(
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout_rounded),
              ),
            ),
          ],
          if (esMovil)
            PopupMenuButton<_AccionSesion>(
              tooltip: 'Abrir menu',
              icon: const Icon(Icons.menu_rounded),
              onSelected: (_AccionSesion accion) {
                switch (accion) {
                  case _AccionSesion.recargar:
                    _cargar();
                  case _AccionSesion.cambiarTema:
                    widget.onThemeModeChanged(
                      widget.themeMode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                    );
                  case _AccionSesion.sincronizarPendientes:
                    _sincronizarAccionesOffline();
                  case _AccionSesion.gestionEmpleados:
                    _abrirGestionEmpleados();
                  case _AccionSesion.cerrarSesion:
                    _cerrarSesion();
                }
              },
              itemBuilder: (BuildContext context) {
                return <PopupMenuEntry<_AccionSesion>>[
                  const PopupMenuItem<_AccionSesion>(
                    value: _AccionSesion.recargar,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.refresh_rounded),
                        SizedBox(width: 12),
                        Text('Actualizar datos'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_AccionSesion>(
                    value: _AccionSesion.cambiarTema,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          widget.themeMode == ThemeMode.dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.themeMode == ThemeMode.dark
                              ? 'Usar tema claro'
                              : 'Usar tema oscuro',
                        ),
                      ],
                    ),
                  ),
                  if (!usuarioSesion.esSuperAdmin &&
                      usuarioSesion.puede(_permisoVerEmpleados))
                    const PopupMenuItem<_AccionSesion>(
                      value: _AccionSesion.gestionEmpleados,
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.manage_accounts_rounded),
                          SizedBox(width: 12),
                          Text('Gestion de empleado'),
                        ],
                      ),
                    ),
                  if (!usuarioSesion.esSuperAdmin &&
                      _accionesPendientesOffline > 0)
                    PopupMenuItem<_AccionSesion>(
                      value: _AccionSesion.sincronizarPendientes,
                      enabled: !_sincronizandoOffline,
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.cloud_sync_rounded),
                          const SizedBox(width: 12),
                          Text('Sincronizar $_accionesPendientesOffline'),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<_AccionSesion>(
                    value: _AccionSesion.cerrarSesion,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.logout_rounded),
                        SizedBox(width: 12),
                        Text('Cerrar sesion'),
                      ],
                    ),
                  ),
                ];
              },
            ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.clay.border),
        ),
      ),
      body: SafeArea(
        bottom: !esMovil,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.clay.background,
          ),
          child: Row(
            children: <Widget>[
              if (!esMovil && !usuarioSesion.esSuperAdmin) ...<Widget>[
                _construirMenuLateral(context),
                VerticalDivider(width: 1, color: context.clay.border),
              ],
              Expanded(
                child: usuarioSesion.esSuperAdmin
                    ? SuperAdminView(
                        organizaciones: _organizacionesAdmin,
                        guardando: _guardando,
                        cargando: _cargando,
                        error: _error,
                        onRefresh: _cargar,
                        onCrearOrganizacion: _crearOrganizacionAdmin,
                        onCrearAdministrador: _crearAdministradorAdmin,
                        onEditarOrganizacion: _editarOrganizacionAdmin,
                        onActivoChanged: (
                          OrganizacionAdmin organizacion,
                          bool activo,
                        ) =>
                            _actualizarOrganizacionAdmin(
                          organizacion,
                          <String, dynamic>{
                            'activo': activo,
                            if (!activo)
                              'motivoSuspension':
                                  'Suspendido por falta de pagos',
                          },
                          activo
                              ? 'Institución reactivada'
                              : 'Institución suspendida',
                        ),
                      )
                    : _cargando && _catalogos == null
                        ? const Center(child: CircularProgressIndicator())
                        : _construirVistaActual(context),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: esMovil && !usuarioSesion.esSuperAdmin
          ? _construirNavegacionInferior(context)
          : null,
    );
  }

  Widget _construirMenuLateral(BuildContext context) {
    final ClayTokens clay = context.clay;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: _menuLateralExpandido ? 256 : 88,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[clay.surfaceHigh, clay.surface],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: clay.shadow.withValues(alpha: clay.isDark ? 0.34 : 0.12),
            blurRadius: 18,
            offset: const Offset(7, 0),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool mostrarMenuExpandido = constraints.maxWidth >= 210;
          return mostrarMenuExpandido
              ? Padding(
                  key: const ValueKey<String>('menu-expandido'),
                  padding: const EdgeInsets.all(14),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Navegacion',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: clay.subtleText,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          Tooltip(
                            message: 'Cerrar menu',
                            child: IconButton(
                              onPressed: () {
                                setState(() => _menuLateralExpandido = false);
                              },
                              icon: const Icon(
                                Icons.keyboard_double_arrow_left_rounded,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._destinosMenuActual.asMap().entries.map(
                        (MapEntry<int, _DestinoMenu> entry) {
                          final int index = entry.key;
                          final _DestinoMenu destino = entry.value;
                          final bool seleccionado = _seccionActual == index;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                selected: seleccionado,
                                leading: AnimatedScale(
                                  scale: seleccionado ? 1.08 : 1,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    seleccionado
                                        ? destino.iconoSeleccionado
                                        : destino.icono,
                                  ),
                                ),
                                title: Text(destino.etiqueta),
                                onTap: () => _seleccionarSeccion(index),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : Column(
                  key: const ValueKey<String>('menu-compacto'),
                  children: <Widget>[
                    const SizedBox(height: 10),
                    Tooltip(
                      message: 'Abrir menu',
                      child: IconButton(
                        onPressed: () {
                          setState(() => _menuLateralExpandido = true);
                        },
                        icon: const Icon(Icons.menu_open_rounded),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: NavigationRail(
                        backgroundColor: Colors.transparent,
                        selectedIndex: _seccionActual,
                        onDestinationSelected: _seleccionarSeccion,
                        labelType: NavigationRailLabelType.none,
                        groupAlignment: -1,
                        minWidth: 72,
                        scrollable: true,
                        destinations: _destinosMenuActual
                            .map(
                              (_DestinoMenu destino) =>
                                  NavigationRailDestination(
                                icon: Tooltip(
                                  message: destino.etiqueta,
                                  child: Icon(destino.icono),
                                ),
                                selectedIcon: Tooltip(
                                  message: destino.etiqueta,
                                  child: Icon(destino.iconoSeleccionado),
                                ),
                                label: Text(destino.etiqueta),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                );
        },
      ),
    );
  }

  Widget _construirNavegacionInferior(BuildContext context) {
    const List<_DestinoMenu> destinosMovil = _destinosMenuBase;
    return ColoredBox(
      color: context.clay.background,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: ClaySurface(
          height: 74,
          radius: 22,
          padding: const EdgeInsets.all(5),
          color: context.clay.surface,
          child: Row(
            children: destinosMovil.asMap().entries.map(
              (MapEntry<int, _DestinoMenu> entry) {
                return Expanded(
                  child: _BotonNavegacionInferior(
                    destino: entry.value,
                    seleccionado: _seccionActual == entry.key,
                    onTap: () => _seleccionarSeccion(entry.key),
                  ),
                );
              },
            ).toList(growable: false),
          ),
        ),
      ),
    );
  }

  Widget _construirVistaActual(BuildContext context) {
    switch (_seccionActual) {
      case 0:
        return KeyedSubtree(
          key: const ValueKey<String>('inicio'),
          child: _construirPresupuesto(context),
        );
      case 1:
        return KeyedSubtree(
          key: const ValueKey<String>('ruta'),
          child: _construirRutaActiva(context),
        );
      case _indiceCredito:
        return KeyedSubtree(
          key: const ValueKey<String>('credito'),
          child: _construirNuevoCredito(context),
        );
      case 3:
        return KeyedSubtree(
          key: const ValueKey<String>('caja-menor'),
          child: _construirCajaMenor(context),
        );
      case 4:
        return KeyedSubtree(
          key: const ValueKey<String>('clientes'),
          child: _construirClientes(context),
        );
      case _indiceGestionEmpleados:
        return KeyedSubtree(
          key: const ValueKey<String>('gestion-empleados'),
          child: _construirGestionEmpleados(context),
        );
      default:
        return KeyedSubtree(
          key: const ValueKey<String>('inicio'),
          child: _construirPresupuesto(context),
        );
    }
  }

  void _seleccionarSeccion(int index) {
    if (index == _indiceGestionEmpleados && !_puedeVerEmpleados) {
      _mostrarMensaje('No tienes permiso para ver empleados');
      return;
    }

    if (_seccionActual == index) {
      return;
    }

    setState(() => _seccionActual = index);
  }

  Widget _construirGestionEmpleados(BuildContext context) {
    if (!_puedeVerEmpleados) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: const EstadoVacio(
              icono: Icons.lock_outline_rounded,
              titulo: 'Acceso restringido',
              mensaje: 'No tienes permiso para ver empleados.',
            ),
          ),
        ),
      );
    }

    return GestionEmpleadosPage(
      embebida: true,
      apiClient: _apiClient,
      cargarEmpleados: _obtenerEmpleadosGestion,
      cargarActividadEmpleados: _obtenerActividadEmpleadosGestion,
      crearEmpleado: _abrirCrearEmpleado,
      modificarEmpleado: _modificarEmpleadoGestion,
      puedeGestionar: _usuarioSesion?.esAdministrador ?? false,
      mensajeError: _mensajeError,
      mostrarMensaje: _mostrarMensaje,
    );
  }

  bool get _puedeVerEmpleados =>
      _usuarioSesion?.puede(_permisoVerEmpleados) ?? false;
  bool get _puedeCrearCajaMenor =>
      _usuarioSesion?.puede(_permisoCrearCajaMenor) ?? false;
  bool get _puedeRegistrarFlujoCaja =>
      _usuarioSesion?.puede(_permisoRegistrarFlujoCaja) ?? false;
  bool get _puedeCrearCreditos =>
      _usuarioSesion?.puede(_permisoCrearCreditos) ?? false;
  bool get _puedeRefinanciarCreditos =>
      _usuarioSesion?.puede(_permisoRefinanciarCreditos) ?? false;
  bool get _puedeModificarCreditos =>
      _usuarioSesion?.puede(_permisoModificarCreditos) ?? false;
  bool get _puedeEliminarCreditos =>
      _usuarioSesion?.puede(_permisoEliminarCreditos) ?? false;
  bool get _puedeAgregarCuota =>
      _usuarioSesion?.puede(_permisoAgregarCuota) ?? false;
  bool get _puedeModificarMovimientos =>
      _usuarioSesion?.puede(_permisoModificarMovimientos) ?? false;
  bool get _puedeEliminarMovimientos =>
      _usuarioSesion?.puede(_permisoEliminarMovimientos) ?? false;

  Widget _construirPresupuesto(BuildContext context) {
    final List<CajaMenorCatalogo> cajasInicio = _filtrarCajasInicio();
    final String? cajaInicioSeleccionada = _cajaInicioFiltroIdValida(
      cajasInicio,
    );
    final bool filtradoPorBusqueda =
        (_catalogos?.cajasMenores.isNotEmpty ?? false) && cajasInicio.isEmpty;
    final List<PresupuestoItem> itemsInicio = filtradoPorBusqueda
        ? const <PresupuestoItem>[]
        : _filtrarItemsPresupuestoInicio(cajaInicioSeleccionada);
    final PresupuestoTotales totales = _totalesPresupuesto(itemsInicio);
    final int clientesCreditos = totales.clientesCreditos;
    final double cartera = _cobrosRuta.fold<double>(
      0,
      (double total, CobroRuta cobro) => total + cobro.saldo,
    );
    final int creditosAtrasados = _cobrosRuta
        .where((CobroRuta cobro) => cobro.estadoCobro == EstadoCobro.atrasado)
        .length;
    final DateTime ahora = DateTime.now();
    DateTime inicioPeriodo = DateTime(ahora.year, ahora.month);

    for (final MovimientoCaja movimiento in _movimientosCaja) {
      final DateTime fecha = movimiento.fechaMovimiento;
      if (!fecha.isAfter(ahora) && fecha.isAfter(inicioPeriodo)) {
        inicioPeriodo = fecha;
      }
    }

    return PaginaInicioPresupuesto(
      totales: totales,
      graficas: _GraficasInicio(totales: totales),
      clientesActivos: clientesCreditos,
      cartera: cartera,
      conteoCreditos: _conteoCreditosInicio,
      creditosAtrasados: creditosAtrasados,
      fechaInicio: inicioPeriodo,
      fechaFin: ahora,
      items: itemsInicio,
      cajasMenores: cajasInicio,
      cajaMenorId: cajaInicioSeleccionada,
      buscarCajaController: _buscarCajaInicioController,
      fechaDesde: _fechaInicioDesde,
      fechaHasta: _fechaInicioHasta,
      hayFiltros: _hayFiltrosInicio,
      onCajaChanged: _cambiarCajaInicio,
      fechaHoyActiva: _inicioMostrandoHoy,
      todosLosDiasActivo: _inicioMostrandoTodosLosDias,
      onFechaHoy: _mostrarInicioHoy,
      onTodosLosDias: _mostrarInicioTodosLosDias,
      onFechaDesde: () => _seleccionarFechaInicio(esDesde: true),
      onFechaHasta: () => _seleccionarFechaInicio(esDesde: false),
      onLimpiarFiltros: _limpiarFiltrosInicio,
      onVerCreditos: () => _mostrarCreditosInicio(FiltroEstadoCredito.todos),
      onVerActivos: () => _mostrarCreditosInicio(FiltroEstadoCredito.activos),
      onVerInactivos: () =>
          _mostrarCreditosInicio(FiltroEstadoCredito.inactivos),
      onVerAtrasados: _mostrarAtrasadosInicio,
      error: _error,
      onRefresh: _cargar,
    );
  }

  List<CajaMenorCatalogo> _filtrarCajasInicio() {
    final List<CajaMenorCatalogo> cajas =
        _catalogos?.cajasMenores ?? const <CajaMenorCatalogo>[];
    final String consulta =
        _buscarCajaInicioController.text.trim().toLowerCase();

    return cajas.where((CajaMenorCatalogo caja) {
      if (consulta.isNotEmpty &&
          !caja.nombre.toLowerCase().contains(consulta)) {
        return false;
      }

      return true;
    }).toList(growable: false);
  }

  String? _cajaInicioFiltroIdValida(List<CajaMenorCatalogo> cajas) {
    if (_cajaInicioFiltroId == _todasLasCajasFiltro) {
      return _todasLasCajasFiltro;
    }

    final Set<String> ids =
        cajas.map((CajaMenorCatalogo caja) => caja.id).toSet();
    if (_cajaInicioFiltroId != null && ids.contains(_cajaInicioFiltroId)) {
      return _cajaInicioFiltroId;
    }

    return _cajaActivaMasRecienteId(cajas) ??
        (cajas.isEmpty ? null : cajas.first.id);
  }

  List<PresupuestoItem> _filtrarItemsPresupuestoInicio(
    String? cajaMenorId, {
    Presupuesto? presupuesto,
  }) {
    final List<PresupuestoItem> items =
        (presupuesto ?? _presupuesto)?.items ?? const <PresupuestoItem>[];
    if (cajaMenorId == null || cajaMenorId == _todasLasCajasFiltro) {
      return items;
    }

    final List<PresupuestoItem> filtrados = items
        .where((PresupuestoItem item) => item.cajaMenorId == cajaMenorId)
        .toList(growable: false);
    if (filtrados.isNotEmpty || items.isEmpty) {
      return filtrados;
    }

    return items;
  }

  PresupuestoTotales _totalesPresupuesto(List<PresupuestoItem> items) {
    if (items.isEmpty) {
      return const PresupuestoTotales.vacio();
    }

    return PresupuestoTotales(
      cajaMenor: items.fold<double>(
        0,
        (double total, PresupuestoItem item) => total + item.cajaMenor,
      ),
      recaudado: items.fold<double>(
        0,
        (double total, PresupuestoItem item) => total + item.recaudado,
      ),
      gastos: items.fold<double>(
        0,
        (double total, PresupuestoItem item) => total + item.gastos,
      ),
      creditos: items.fold<double>(
        0,
        (double total, PresupuestoItem item) => total + item.creditos,
      ),
      creditosRefinanciados: items.fold<int>(
        0,
        (int total, PresupuestoItem item) => total + item.creditosRefinanciados,
      ),
      clientesCreditos: items.fold<int>(
        0,
        (int total, PresupuestoItem item) => total + item.clientesCreditos,
      ),
      valorRefinanciado: items.fold<double>(
        0,
        (double total, PresupuestoItem item) => total + item.valorRefinanciado,
      ),
      presupuesto: items.fold<double>(
        0,
        (double total, PresupuestoItem item) => total + item.presupuesto,
      ),
    );
  }

  Widget _construirRutaActiva(BuildContext context) {
    return RutaCobroView(
      cobros: _filtrarCobros(),
      cobrosBase: _filtrarCobros(incluirEstado: false),
      buscarRutaController: _buscarRutaController,
      rutas: _catalogos?.rutas ?? const <RutaCatalogo>[],
      rutaFiltroId: _rutaFiltroId,
      filtroEstadoRuta: _filtroEstadoRuta,
      cuotasEnPago: _cuotasEnPago,
      cobrosConPagoInstantaneo: _cobrosConPagoInstantaneo,
      puedeAgregarCuota: _puedeAgregarCuota,
      puedeCrearCreditos: _puedeCrearCreditos,
      guardando: _guardando,
      exportando: _exportando,
      hayFiltrosRuta: _hayFiltrosRuta,
      error: _error,
      roadRouter: _roadRouter,
      onRefresh: _cargar,
      onRutaChanged: (String? rutaId) {
        setState(() => _rutaFiltroId = rutaId);
      },
      onFiltroEstadoChanged: (FiltroEstadoRuta filtro) {
        setState(() {
          _filtroEstadoRuta =
              _filtroEstadoRuta == filtro ? FiltroEstadoRuta.todos : filtro;
        });
      },
      onExportarCobrosRuta: _exportarCobrosRuta,
      onLimpiarFiltrosRuta: _limpiarFiltrosRuta,
      onCrearCreditoModal: _abrirCrearCreditoModal,
      onRegistrarPago: _abrirRegistrarPago,
      onGuardarUbicacionCliente: _guardarUbicacionCliente,
      puedeRegistrarPagoRuta: _puedeRegistrarPagoRuta,
      mapCustomerBuilder: _mapCustomerFromCobro,
    );
  }

  Widget _construirNuevoCredito(BuildContext context) {
    final Catalogos? catalogos = _catalogos;
    final List<CreditoRegistro> creditos = _filtrarCreditos();
    final bool listo = catalogos != null &&
        _clientes.isNotEmpty &&
        catalogos.frecuenciasPago.isNotEmpty &&
        catalogos.monedas.isNotEmpty &&
        catalogos.cajasMenoresActivas.isNotEmpty;
    final bool puedeCrearClienteConCredito = catalogos != null &&
        catalogos.frecuenciasPago.isNotEmpty &&
        catalogos.monedas.isNotEmpty &&
        catalogos.cajasMenoresActivas.isNotEmpty;
    final bool faltanClientes = _clientes.isEmpty;

    return CreditosView(
      creditos: creditos,
      sinCreditosRegistrados: _creditos.isEmpty,
      mostrandoCargaInicial: _cargandoCreditos && creditos.isEmpty,
      cargandoMasCreditos: _cargandoMasCreditos,
      hayCreditoActivo:
          _creditos.any((CreditoRegistro credito) => credito.activo),
      listo: listo,
      faltanClientes: faltanClientes,
      puedeCrearClienteConCredito: puedeCrearClienteConCredito,
      mensajeDatosBase: _mensajeDatosBaseCredito(catalogos),
      puedeRefinanciarCreditos: _puedeRefinanciarCreditos,
      puedeCrearCreditos: _puedeCrearCreditos,
      puedeModificarCreditos: _puedeModificarCreditos,
      puedeEliminarCreditos: _puedeEliminarCreditos,
      guardando: _guardando,
      error: _error,
      onRefresh: _cargar,
      onNearEnd: _cargarMasCreditosSiHaceFalta,
      onRefinanciarGeneral: _abrirSeleccionRefinanciacion,
      onCrearCredito: _abrirCrearCreditoModal,
      onModificarCredito: _abrirModificarCredito,
      onEliminarCredito: _confirmarEliminarCredito,
      onRefinanciarCredito: _abrirRefinanciarCredito,
      buscarController: _buscarCreditoController,
      filtros: _construirFiltrosCredito(context),
    );
  }

  String _mensajeDatosBaseCredito(Catalogos? catalogos) {
    return mensajeDatosBaseCredito(catalogos, sinClientes: _clientes.isEmpty);
  }

  Widget _construirFiltrosCredito(BuildContext context) {
    return FiltrosCredito(
      filtroCredito: _filtroCredito,
      onFiltroCreditoChanged: (FiltroEstadoCredito value) {
        setState(() => _filtroCredito = value);
        _recargarDatos(creditos: true);
      },
      fechaCreditoDesde: _fechaCreditoDesde,
      fechaCreditoHasta: _fechaCreditoHasta,
      onSeleccionarFechaDesde: () => _seleccionarFechaCredito(esDesde: true),
      onSeleccionarFechaHasta: () => _seleccionarFechaCredito(esDesde: false),
      exportando: _exportando,
      onExportar: _exportarCreditos,
      hayFiltrosCredito: _hayFiltrosCredito,
      onLimpiarFiltros: _limpiarFiltrosCredito,
    );
  }

  Widget _construirCajaMenor(BuildContext context) {
    return CajaMenorView(
      movimientos: _filtrarMovimientosCaja(),
      hayCajaMenor: _catalogos?.cajasMenoresActivas.isNotEmpty ?? false,
      mostrandoCargaMovimientosCaja: _cargandoMovimientosCaja,
      cargandoMasMovimientosCaja: _cargandoMasMovimientosCaja,
      puedeCrearCajaMenor: _puedeCrearCajaMenor,
      puedeRegistrarFlujoCaja: _puedeRegistrarFlujoCaja,
      puedeModificarMovimientos: _puedeModificarMovimientos,
      puedeModificarCreditos: _puedeModificarCreditos,
      puedeEliminarMovimientos: _puedeEliminarMovimientos,
      puedeEliminarCreditos: _puedeEliminarCreditos,
      esAdministrador: _usuarioSesion?.esAdministrador ?? false,
      guardando: _guardando,
      error: _error,
      onRefresh: _cargar,
      onNearEnd: _cargarMasMovimientosCajaSiHaceFalta,
      onCerrarCajaMenor: _confirmarCerrarCajaMenorSeleccionada,
      onCrearCajaMenor: _abrirCrearCajaMenor,
      onMovimientoCaja: _abrirMovimientoCaja,
      onModificarMovimiento: _abrirEditarMovimientoCaja,
      onEliminarMovimiento: _confirmarEliminarMovimientoCaja,
      buscarController: _buscarCajaController,
      filtros: _construirFiltrosCaja(context),
    );
  }

  Widget _construirFiltrosCaja(BuildContext context) {
    return FiltrosCajaMenor(
      cajas: _catalogos?.cajasMenores ?? const <CajaMenorCatalogo>[],
      cajaMenorFiltroId: _cajaMenorFiltroId,
      todasLasCajasFiltro: _todasLasCajasFiltro,
      onCajaChanged: (String? value) {
        if (value == null) {
          return;
        }

        setState(() {
          _cajaMenorFiltroId = value == _todasLasCajasFiltro ? null : value;
        });
        _recargarDatos(movimientosCaja: true);
      },
      filtroMovimientoCaja: _filtroMovimientoCaja,
      onFiltroMovimientoCajaChanged: (FiltroMovimientoCaja value) {
        setState(() => _filtroMovimientoCaja = value);
        _recargarDatos(movimientosCaja: true);
      },
      fechaCajaDesde: _fechaCajaDesde,
      fechaCajaHasta: _fechaCajaHasta,
      onSeleccionarFechaDesde: () => _seleccionarFechaCaja(esDesde: true),
      onSeleccionarFechaHasta: () => _seleccionarFechaCaja(esDesde: false),
      exportando: _exportando,
      onExportar: _exportarMovimientosCaja,
      hayFiltrosCaja: _hayFiltrosCaja,
      onLimpiarFiltros: _limpiarFiltrosCaja,
    );
  }

  Widget _construirClientes(BuildContext context) {
    return ClientesView(
      clientes: _filtrarClientes(),
      sinClientesRegistrados: _clientes.isEmpty,
      esAdministrador: _usuarioSesion?.esAdministrador ?? false,
      buscarController: _buscarClienteController,
      onRefresh: _cargar,
      onCrearCliente: _abrirCrearClienteConCredito,
      onModificarCliente: _abrirModificarCliente,
      onEliminarCliente: _confirmarEliminarCliente,
      error: _error,
      guardando: _guardando,
    );
  }

  void _cambiarCajaInicio(String? value) {
    setState(() => _cajaInicioFiltroId = value);
    _recargarDatos(presupuesto: true, creditos: true);
  }

  bool _puedeRegistrarPagoRuta(CobroRuta cobro) {
    return !_guardando &&
        _puedeAgregarCuota &&
        cobro.proximaCuotaId != null &&
        !_cuotasEnPago.contains(cobro.proximaCuotaId) &&
        !_cobrosConPagoInstantaneo.contains(cobro.id) &&
        cobro.saldo > 0.009;
  }

  bool _cobroActivoParaRuta(CobroRuta cobro) {
    return cobro.proximaCuotaId != null &&
        !_cobrosConPagoInstantaneo.contains(cobro.id) &&
        cobro.saldo > 0.009 &&
        cobro.estadoCobro != EstadoCobro.pagado;
  }

  Future<void> _guardarUbicacionCliente(CobroRuta cobro) async {
    if (_guardando) {
      return;
    }

    final String? direccion = (cobro.direccion ?? '').trim().isNotEmpty
        ? cobro.direccion!.trim()
        : await _solicitarDireccionParaMapa(cobro);
    if (direccion == null || !mounted) {
      return;
    }
    final bool? confirmarCaptura = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            cobro.tieneUbicacion
                ? 'Actualizar punto del cliente'
                : 'Guardar punto del cliente',
          ),
          content: SizedBox(
            width: 430,
            child: Text(
              'Confirma que estás físicamente en la dirección de ${cobro.cliente}. '
              'Se guardará la ubicación actual de este dispositivo para "$direccion".',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Estoy aquí, guardar'),
            ),
          ],
        );
      },
    );
    if (confirmarCaptura != true || !mounted) {
      return;
    }

    final bool guardada = await _ejecutarAccion(() async {
      _mostrarMensaje('Obteniendo ubicación precisa del cliente…');
      final LatLng position =
          await const DeviceRouteLocationService().currentPosition();
      await _apiClient.patchObject(
        '/clientes/${cobro.clienteId}/ubicacion',
        <String, dynamic>{
          'direccion': direccion,
          'latitud': position.latitude,
          'longitud': position.longitude,
        },
        queueOffline: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _cobrosRuta = _cobrosRuta
            .map(
              (CobroRuta item) => item.clienteId == cobro.clienteId
                  ? item.copyWith(
                      direccion: direccion,
                      latitude: position.latitude,
                      longitude: position.longitude,
                    )
                  : item,
            )
            .toList(growable: false);
      });
    });

    if (guardada) {
      _mostrarMensaje('Ubicación del cliente guardada en el mapa');
      _recargarEnSegundoPlano(
        clientes: true,
        cobrosRuta: true,
      );
    }
  }

  Future<String?> _solicitarDireccionParaMapa(CobroRuta cobro) async {
    final TextEditingController controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Dirección del cliente'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Escribe la dirección de ${cobro.cliente} antes de guardar el punto GPS.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                    onSubmitted: (String value) {
                      final String direccion = value.trim();
                      if (direccion.isNotEmpty) {
                        Navigator.of(dialogContext).pop(direccion);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  final String direccion = controller.text.trim();
                  if (direccion.isEmpty) {
                    _mostrarMensaje('Escribe la dirección del cliente');
                    return;
                  }
                  Navigator.of(dialogContext).pop(direccion);
                },
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Continuar'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  CollectionMapCustomer _mapCustomerFromCobro(CobroRuta cobro) {
    return mapCustomerFromCobro(
      cobro,
      canCollect: _puedeRegistrarPagoRuta(cobro),
      canRoute: _cobroActivoParaRuta(cobro),
    );
  }

  void _aplicarFechaInicioHoy() {
    final DateTime hoy = _soloFecha(fechaHoraColombia());
    _fechaInicioDesde = hoy;
    _fechaInicioHasta = hoy;
  }

  void _mostrarInicioHoy() {
    setState(() {
      _aplicarFechaInicioHoy();
      _cajaInicioFiltroId = _cajaInicioFiltroIdValida(_filtrarCajasInicio());
    });
    _recargarDatos(presupuesto: true, creditos: true);
  }

  void _mostrarInicioTodosLosDias() {
    setState(() {
      _fechaInicioDesde = null;
      _fechaInicioHasta = null;
      _cajaInicioFiltroId = _cajaInicioFiltroIdValida(_filtrarCajasInicio());
    });
    _recargarDatos(presupuesto: true, creditos: true);
  }

  bool get _inicioMostrandoHoy {
    final DateTime hoy = _soloFecha(fechaHoraColombia());
    return _fechaInicioDesde != null &&
        _fechaInicioHasta != null &&
        _soloFecha(_fechaInicioDesde!) == hoy &&
        _soloFecha(_fechaInicioHasta!) == hoy;
  }

  bool get _inicioMostrandoTodosLosDias =>
      _fechaInicioDesde == null && _fechaInicioHasta == null;

  Future<void> _seleccionarFechaInicio({required bool esDesde}) async {
    final DateTime ahora = DateTime.now();
    final DateTime? actual = esDesde ? _fechaInicioDesde : _fechaInicioHasta;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: actual ?? ahora,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      if (esDesde) {
        _fechaInicioDesde = selected;
        if (_fechaInicioHasta != null &&
            _soloFecha(_fechaInicioHasta!).isBefore(_soloFecha(selected))) {
          _fechaInicioHasta = selected;
        }
      } else {
        _fechaInicioHasta = selected;
        if (_fechaInicioDesde != null &&
            _soloFecha(_fechaInicioDesde!).isAfter(_soloFecha(selected))) {
          _fechaInicioDesde = selected;
        }
      }
      _cajaInicioFiltroId = _cajaInicioFiltroIdValida(_filtrarCajasInicio());
    });
    _recargarDatos(presupuesto: true, creditos: true);
  }

  Future<void> _seleccionarFechaCredito({required bool esDesde}) async {
    final DateTime ahora = DateTime.now();
    final DateTime? actual = esDesde ? _fechaCreditoDesde : _fechaCreditoHasta;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: actual ?? ahora,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      if (esDesde) {
        _fechaCreditoDesde = selected;
        if (_fechaCreditoHasta != null &&
            _soloFecha(_fechaCreditoHasta!).isBefore(_soloFecha(selected))) {
          _fechaCreditoHasta = selected;
        }
      } else {
        _fechaCreditoHasta = selected;
        if (_fechaCreditoDesde != null &&
            _soloFecha(_fechaCreditoDesde!).isAfter(_soloFecha(selected))) {
          _fechaCreditoDesde = selected;
        }
      }
    });
    _recargarDatos(creditos: true);
  }

  Future<void> _seleccionarFechaCaja({required bool esDesde}) async {
    final DateTime ahora = DateTime.now();
    final DateTime? actual = esDesde ? _fechaCajaDesde : _fechaCajaHasta;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: actual ?? ahora,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      if (esDesde) {
        _fechaCajaDesde = selected;
        if (_fechaCajaHasta != null &&
            _soloFecha(_fechaCajaHasta!).isBefore(_soloFecha(selected))) {
          _fechaCajaHasta = selected;
        }
      } else {
        _fechaCajaHasta = selected;
        if (_fechaCajaDesde != null &&
            _soloFecha(_fechaCajaDesde!).isAfter(_soloFecha(selected))) {
          _fechaCajaDesde = selected;
        }
      }
    });
    _recargarDatos(movimientosCaja: true);
  }

  void _limpiarFiltrosCaja() {
    setState(() {
      _cajaMenorFiltroId = null;
      _filtroMovimientoCaja = FiltroMovimientoCaja.todos;
      _fechaCajaDesde = null;
      _fechaCajaHasta = null;
    });
    _recargarDatos(movimientosCaja: true);
  }

  bool get _hayFiltrosCaja =>
      _cajaMenorFiltroId != null ||
      _filtroMovimientoCaja != FiltroMovimientoCaja.todos ||
      _fechaCajaDesde != null ||
      _fechaCajaHasta != null;

  void _limpiarFiltrosInicio() {
    setState(() {
      _buscarCajaInicioController.clear();
      _aplicarFechaInicioHoy();
      _cajaInicioFiltroId = _cajaActivaPredeterminadaId(_catalogos);
    });
    _recargarDatos(presupuesto: true, creditos: true);
  }

  bool get _hayFiltrosInicio =>
      _buscarCajaInicioController.text.trim().isNotEmpty ||
      !_inicioMostrandoHoy ||
      _cajaInicioFiltroId != _cajaActivaPredeterminadaId(_catalogos);

  void _limpiarFiltrosCredito() {
    setState(() {
      _filtroCredito = FiltroEstadoCredito.todos;
      _fechaCreditoDesde = null;
      _fechaCreditoHasta = null;
    });
    _recargarDatos(creditos: true);
  }

  bool get _hayFiltrosCredito =>
      _filtroCredito != FiltroEstadoCredito.todos ||
      _fechaCreditoDesde != null ||
      _fechaCreditoHasta != null;

  void _mostrarCreditosInicio(FiltroEstadoCredito filtro) {
    if (_buscarCreditoController.text.isNotEmpty) {
      _buscarCreditoController.clear();
    }

    setState(() {
      _seccionActual = _indiceCredito;
      _filtroCredito = filtro;
      _fechaCreditoDesde = _fechaInicioDesde;
      _fechaCreditoHasta = _fechaInicioHasta;
    });
    _recargarDatos(creditos: true);
  }

  void _limpiarFiltrosRuta() {
    if (_buscarRutaController.text.isNotEmpty) {
      _buscarRutaController.clear();
    }

    setState(() {
      _rutaFiltroId = null;
      _filtroEstadoRuta = FiltroEstadoRuta.todos;
    });
  }

  bool get _hayFiltrosRuta =>
      _buscarRutaController.text.trim().isNotEmpty ||
      _rutaFiltroId != null ||
      _filtroEstadoRuta != FiltroEstadoRuta.todos;

  void _mostrarAtrasadosInicio() {
    if (_buscarRutaController.text.isNotEmpty) {
      _buscarRutaController.clear();
    }

    setState(() {
      _seccionActual = 1;
      _rutaFiltroId = null;
      _filtroEstadoRuta = FiltroEstadoRuta.atrasado;
    });
  }

  Future<void> _iniciarSesion() async {
    final String usuario = _loginUsuarioController.text.trim().toLowerCase();
    final String contrasena = _loginContrasenaController.text;

    if (usuario.length < 3 || contrasena.length < 8) {
      debugPrint(
        '[Login] Validacion local bloqueada: usuarioLength=${usuario.length} contrasenaLength=${contrasena.length}',
      );
      setState(() {
        _error = 'Ingresa usuario y contrasena validos';
      });
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      debugPrint('[Login] Enviando POST /auth/login');
      final Sesion sesion = Sesion.fromJson(
        await _apiClient.postObject('/auth/login', <String, dynamic>{
          'usuario': usuario,
          'contrasena': contrasena,
        }),
      );

      _apiClient.setAuthToken(sesion.token);
      await _guardarSesionLocal(sesion);
      if (!mounted) {
        return;
      }

      setState(() {
        _usuarioSesion = sesion.usuario;
        _seccionActual = 0;
        _catalogos = null;
        _presupuesto = null;
        _clientes = const <Cliente>[];
        _cobrosRuta = const <CobroRuta>[];
        _organizacionesAdmin = const <OrganizacionAdmin>[];
        _movimientosCaja = const <MovimientoCaja>[];
        _cajaMenorFiltroId = null;
        _aplicarFechaInicioHoy();
      });

      await _cargar();
    } catch (error) {
      if (mounted) {
        final String mensaje = _mensajeError(error);
        debugPrint('[Login] Error: $mensaje detalle=$error');
        setState(() => _error = mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _cerrarSesion() {
    _apiClient.setAuthToken(null);
    unawaited(clearCachedSessionPayload());
    _loginContrasenaController.clear();
    _filtrosListasTimer?.cancel();

    setState(() {
      _usuarioSesion = null;
      _catalogos = null;
      _presupuesto = null;
      _clientes = const <Cliente>[];
      _cobrosRuta = const <CobroRuta>[];
      _creditos = const <CreditoRegistro>[];
      _movimientosCaja = const <MovimientoCaja>[];
      _organizacionesAdmin = const <OrganizacionAdmin>[];
      _siguienteOffsetCreditos = 0;
      _siguienteOffsetMovimientosCaja = 0;
      _hayMasCreditos = false;
      _hayMasMovimientosCaja = false;
      _cargandoCreditos = false;
      _cargandoMovimientosCaja = false;
      _cargandoMasCreditos = false;
      _cargandoMasMovimientosCaja = false;
      _seccionActual = 0;
      _cajaMenorFiltroId = null;
      _cargando = false;
      _guardando = false;
      _error = null;
    });
  }

  Future<void> _restaurarSesionGuardada() async {
    final String? payload = await loadCachedSessionPayload();
    if (payload == null || payload.trim().isEmpty || !mounted) {
      return;
    }

    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final Sesion sesion = Sesion.fromJson(decoded);
      _apiClient.setAuthToken(sesion.token);
      final SesionUsuario usuarioActual = SesionUsuario.fromJson(
        await _apiClient.getObject('/auth/me'),
      );
      await _guardarSesionLocal(
        Sesion(token: sesion.token, usuario: usuarioActual),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _usuarioSesion = usuarioActual;
        _seccionActual = 0;
        _error = null;
        _aplicarFechaInicioHoy();
      });

      unawaited(_cargar());
    } catch (_) {
      _apiClient.setAuthToken(null);
      await clearCachedSessionPayload();
    }
  }

  Future<void> _guardarSesionLocal(Sesion sesion) async {
    await saveCachedSessionPayload(jsonEncode(sesion.toJson()));
  }

  Future<void> _cargarAccionesPendientesOffline() async {
    if (_usuarioSesion?.esSuperAdmin == true) {
      return;
    }

    final int pendientes = await _apiClient.pendingOfflineActions();
    if (!mounted) {
      return;
    }

    setState(() => _accionesPendientesOffline = pendientes);
  }

  Future<void> _sincronizarAccionesOffline() async {
    if (_usuarioSesion == null ||
        _usuarioSesion!.esSuperAdmin ||
        _sincronizandoOffline) {
      return;
    }

    setState(() => _sincronizandoOffline = true);

    try {
      final OfflineSyncResult resultado = await _apiClient.syncOfflineActions();
      if (!mounted) {
        return;
      }

      setState(() => _accionesPendientesOffline = resultado.pending);

      if (resultado.synced > 0) {
        _mostrarMensaje(
          '${resultado.synced} accion(es) sincronizada(s) con exito',
        );
        _recargarEnSegundoPlano();
      }

      if (resultado.blockedBy != null) {
        _mostrarMensaje(
          'No se sincronizaron ${resultado.pending} accion(es): ${_mensajeError(resultado.blockedBy!)}',
        );
      }
    } catch (error) {
      if (mounted) {
        _mostrarMensaje(_mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _sincronizandoOffline = false);
      }
    }
  }

  Future<void> _marcarAccionOfflinePendiente(
    OfflineMutationQueuedException error,
  ) async {
    if (!mounted) {
      return;
    }

    final int pendientes = await _apiClient.pendingOfflineActions();
    if (!mounted) {
      return;
    }

    setState(() => _accionesPendientesOffline = pendientes);
    _mostrarMensaje(error.message);
  }

  Future<void> _cargar() async {
    if (_usuarioSesion == null) {
      return;
    }

    if (_usuarioSesion!.esSuperAdmin) {
      await _cargarOrganizacionesSuperAdmin();
      return;
    }

    final int cargaActual = ++_cargaSerial;
    setState(() {
      _cargando = true;
      _cargandoCreditos = true;
      _cargandoMovimientosCaja = true;
      _cargandoMasCreditos = false;
      _cargandoMasMovimientosCaja = false;
      _error = null;
    });

    try {
      final List<dynamic> resultados =
          await Future.wait<dynamic>(<Future<dynamic>>[
        _obtenerCatalogos(),
        _obtenerPresupuesto(),
        _obtenerClientes(),
        _obtenerCobrosRuta(),
        _obtenerCreditosPagina(),
        _obtenerMovimientosCajaPagina(),
        _obtenerConteoCreditosInicio(),
      ]);

      if (!mounted || cargaActual != _cargaSerial) {
        return;
      }

      setState(() {
        _catalogos = resultados[0] as Catalogos;
        _presupuesto = resultados[1] as Presupuesto;
        _clientes = resultados[2] as List<Cliente>;
        _cobrosRuta = resultados[3] as List<CobroRuta>;
        final PaginaDatos<CreditoRegistro> creditos =
            resultados[4] as PaginaDatos<CreditoRegistro>;
        final PaginaDatos<MovimientoCaja> movimientosCaja =
            resultados[5] as PaginaDatos<MovimientoCaja>;
        _creditos = creditos.items;
        _siguienteOffsetCreditos = creditos.nextOffset ?? _creditos.length;
        _hayMasCreditos = creditos.hasMore;
        _movimientosCaja = movimientosCaja.items;
        _siguienteOffsetMovimientosCaja =
            movimientosCaja.nextOffset ?? _movimientosCaja.length;
        _hayMasMovimientosCaja = movimientosCaja.hasMore;
        _conteoCreditosInicio = resultados[6] as ConteoCreditosInicio;
        _ajustarSelecciones();
      });
      unawaited(_sincronizarAccionesOffline());
    } catch (error, stackTrace) {
      if (!mounted || cargaActual != _cargaSerial) {
        return;
      }
      debugPrint('[ErrorCargaInicial] $error\n$stackTrace');
      _manejarErrorCarga(error);
    } finally {
      if (mounted && cargaActual == _cargaSerial) {
        setState(() {
          _cargando = false;
          _cargandoCreditos = false;
          _cargandoMovimientosCaja = false;
        });
      }
    }
  }

  Future<void> _cargarOrganizacionesSuperAdmin() async {
    final int cargaActual = ++_cargaSerial;
    setState(() {
      _cargando = true;
      _cargandoCreditos = false;
      _cargandoMovimientosCaja = false;
      _error = null;
    });

    try {
      final List<OrganizacionAdmin> organizaciones =
          await _obtenerOrganizacionesSuperAdmin();
      if (!mounted || cargaActual != _cargaSerial) {
        return;
      }
      setState(() => _organizacionesAdmin = organizaciones);
    } catch (error) {
      if (!mounted || cargaActual != _cargaSerial) {
        return;
      }
      _manejarErrorCarga(error);
    } finally {
      if (mounted && cargaActual == _cargaSerial) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<List<OrganizacionAdmin>> _obtenerOrganizacionesSuperAdmin() async {
    return (await _apiClient.getList('/super-admin/organizaciones'))
        .map(
          (dynamic item) =>
              OrganizacionAdmin.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> _actualizarOrganizacionAdmin(
    OrganizacionAdmin organizacion,
    Map<String, dynamic> body,
    String mensaje,
  ) async {
    if (_guardando) {
      return;
    }

    setState(() => _guardando = true);
    try {
      final OrganizacionAdmin actualizada = OrganizacionAdmin.fromJson(
        await _apiClient.patchObject(
          '/super-admin/organizaciones/${organizacion.id}',
          body,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _organizacionesAdmin = _organizacionesAdmin
            .map(
              (OrganizacionAdmin item) =>
                  item.id == actualizada.id ? actualizada : item,
            )
            .toList(growable: false);
      });
      _mostrarMensaje(mensaje);
    } catch (error) {
      _mostrarMensaje(_mensajeError(error));
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _crearOrganizacionAdmin() async {
    final Map<String, dynamic>? datos = await pedirDatosOrganizacionAdmin(
      context,
      mostrarMensaje: _mostrarMensaje,
    );

    if (datos == null || _guardando) {
      return;
    }

    setState(() => _guardando = true);
    try {
      final OrganizacionAdmin creada = OrganizacionAdmin.fromJson(
        await _apiClient.postObject('/super-admin/organizaciones', datos),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _organizacionesAdmin = <OrganizacionAdmin>[
          creada,
          ..._organizacionesAdmin,
        ]..sort(
            (OrganizacionAdmin a, OrganizacionAdmin b) =>
                a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
          );
      });
      _mostrarMensaje('Institucion creada');
    } catch (error) {
      _mostrarMensaje(_mensajeError(error));
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _editarOrganizacionAdmin(
    OrganizacionAdmin organizacion,
  ) async {
    final Map<String, dynamic>? datos = await pedirDatosOrganizacionAdmin(
      context,
      organizacion: organizacion,
      mostrarMensaje: _mostrarMensaje,
    );

    if (datos == null) {
      return;
    }

    await _actualizarOrganizacionAdmin(
      organizacion,
      datos,
      'Institucion actualizada',
    );
  }

  Future<void> _crearAdministradorAdmin() async {
    if (_organizacionesAdmin.isEmpty) {
      _mostrarMensaje('Crea una institucion antes de agregar administradores');
      return;
    }

    final Map<String, dynamic>? creado = await pedirDatosAdministradorAdmin(
      context,
      apiClient: _apiClient,
      organizaciones: _organizacionesAdmin,
      mostrarMensaje: _mostrarMensaje,
      setGuardando: (bool g) {
        if (mounted) {
          setState(() => _guardando = g);
        }
      },
      mensajeError: _mensajeError,
    );

    if (creado == null || !mounted) {
      return;
    }

    await _cargarOrganizacionesSuperAdmin();
    final String usuarioCreado =
        creado['usuario'] is String ? creado['usuario'] as String : 'usuario';
    final String organizacionNombre = creado['_organizacionNombre'] is String
        ? creado['_organizacionNombre'] as String
        : 'la institucion';
    _mostrarMensaje(
      'Administrador $usuarioCreado creado en $organizacionNombre',
    );
  }

  Future<Catalogos> _obtenerCatalogos() async {
    return Catalogos.fromJson(await _apiClient.getObject('/catalogos'));
  }

  Future<Presupuesto> _obtenerPresupuesto() async {
    return Presupuesto.fromJson(
      await _apiClient.getObject(
        '/presupuesto',
        query: _queryPresupuesto(),
      ),
    );
  }

  Future<List<Cliente>> _obtenerClientes() async {
    return (await _apiClient.getList('/clientes'))
        .map((dynamic item) => Cliente.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<CobroRuta>> _obtenerCobrosRuta() async {
    return (await _apiClient.getList('/cobros/ruta'))
        .map((dynamic item) => CobroRuta.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<PaginaDatos<CreditoRegistro>> _obtenerCreditosPagina({
    int offset = 0,
  }) async {
    final Map<String, dynamic> response = await _apiClient.getObject(
      '/creditos',
      query: _queryCreditos(offset: offset),
    );
    return PaginaDatos.fromJson(
      response,
      CreditoRegistro.fromJson,
    );
  }

  Future<ConteoCreditosInicio> _obtenerConteoCreditosInicio() async {
    return ConteoCreditosInicio.fromJson(
      await _apiClient.getObject(
        '/creditos/resumen',
        query: <String, String?>{
          'fechaDesde': _fechaInicioDesde == null
              ? null
              : formatDateValue(_fechaInicioDesde!),
          'fechaHasta': _fechaInicioHasta == null
              ? null
              : formatDateValue(_fechaInicioHasta!),
        },
      ),
    );
  }

  Future<PaginaDatos<MovimientoCaja>> _obtenerMovimientosCajaPagina({
    int offset = 0,
  }) async {
    final Map<String, dynamic> response = await _apiClient.getObject(
      '/caja-menor/movimientos',
      query: _queryMovimientosCaja(offset: offset),
    );
    return PaginaDatos.fromJson(
      response,
      MovimientoCaja.fromJson,
    );
  }

  Map<String, String?> _queryCreditos({required int offset, int? limit}) {
    final String search = _buscarCreditoController.text.trim();
    return <String, String?>{
      'limit': (limit ?? _pageSize).toString(),
      'offset': offset.toString(),
      'search': search.isEmpty ? null : search,
      'estado': switch (_filtroCredito) {
        FiltroEstadoCredito.todos => 'todos',
        FiltroEstadoCredito.activos => 'activos',
        FiltroEstadoCredito.inactivos => 'inactivos',
      },
      'fechaDesde': _fechaCreditoDesde == null
          ? null
          : formatDateValue(_fechaCreditoDesde!),
      'fechaHasta': _fechaCreditoHasta == null
          ? null
          : formatDateValue(_fechaCreditoHasta!),
    };
  }

  Map<String, String?> _queryPresupuesto() {
    final String search = _buscarCajaInicioController.text.trim();
    final SesionUsuario? usuario = _usuarioSesion;
    final bool usarDatosCobrador = usuario != null &&
        !usuario.esAdministrador &&
        usuario.roles.contains('COBRADOR');
    return <String, String?>{
      'alcance': usarDatosCobrador ? 'cobrador' : null,
      'cajaMenorId': _cajaInicioFiltroId == _todasLasCajasFiltro
          ? null
          : _cajaInicioFiltroId,
      'search': search.isEmpty ? null : search,
      'fechaDesde': _fechaInicioDesde == null
          ? null
          : formatDateValue(_fechaInicioDesde!),
      'fechaHasta': _fechaInicioHasta == null
          ? null
          : formatDateValue(_fechaInicioHasta!),
    };
  }

  Map<String, String?> _queryMovimientosCaja(
      {required int offset, int? limit}) {
    final String search = _buscarCajaController.text.trim();
    return <String, String?>{
      'limit': (limit ?? _pageSize).toString(),
      'offset': offset.toString(),
      'cajaMenorId': _cajaMenorFiltroId,
      'search': search.isEmpty ? null : search,
      'tipo': switch (_filtroMovimientoCaja) {
        FiltroMovimientoCaja.todos => 'todos',
        FiltroMovimientoCaja.entradas => 'entradas',
        FiltroMovimientoCaja.salidas => 'salidas',
      },
      'fechaDesde':
          _fechaCajaDesde == null ? null : formatDateValue(_fechaCajaDesde!),
      'fechaHasta':
          _fechaCajaHasta == null ? null : formatDateValue(_fechaCajaHasta!),
    };
  }

  Future<void> _recargarDatos({
    bool catalogos = false,
    bool presupuesto = false,
    bool clientes = false,
    bool cobrosRuta = false,
    bool creditos = false,
    bool movimientosCaja = false,
  }) async {
    if (_usuarioSesion == null || _usuarioSesion!.esSuperAdmin) {
      return;
    }

    final int cargaActual = ++_cargaSerial;
    if (creditos || movimientosCaja) {
      setState(() {
        if (creditos) {
          _cargandoCreditos = true;
          _cargandoMasCreditos = false;
        }
        if (movimientosCaja) {
          _cargandoMovimientosCaja = true;
          _cargandoMasMovimientosCaja = false;
        }
      });
    }
    final List<Future<dynamic>> tareas = <Future<dynamic>>[];
    int? catalogosIndex;
    int? presupuestoIndex;
    int? clientesIndex;
    int? cobrosRutaIndex;
    int? creditosIndex;
    int? conteoCreditosIndex;
    int? movimientosCajaIndex;

    void agregar(Future<dynamic> tarea, void Function(int index) asignar) {
      asignar(tareas.length);
      tareas.add(tarea);
    }

    if (catalogos) {
      agregar(_obtenerCatalogos(), (int index) => catalogosIndex = index);
    }
    if (presupuesto) {
      agregar(_obtenerPresupuesto(), (int index) => presupuestoIndex = index);
    }
    if (clientes) {
      agregar(_obtenerClientes(), (int index) => clientesIndex = index);
    }
    if (cobrosRuta) {
      agregar(_obtenerCobrosRuta(), (int index) => cobrosRutaIndex = index);
    }
    if (creditos) {
      agregar(
        _obtenerCreditosPagina(),
        (int index) => creditosIndex = index,
      );
    }
    if (creditos || presupuesto) {
      agregar(
        _obtenerConteoCreditosInicio(),
        (int index) => conteoCreditosIndex = index,
      );
    }
    if (movimientosCaja) {
      agregar(
        _obtenerMovimientosCajaPagina(),
        (int index) => movimientosCajaIndex = index,
      );
    }

    if (tareas.isEmpty) {
      return;
    }

    try {
      final List<dynamic> resultados = await Future.wait<dynamic>(tareas);
      if (!mounted || cargaActual != _cargaSerial) {
        return;
      }

      setState(() {
        if (catalogosIndex != null) {
          _catalogos = resultados[catalogosIndex!] as Catalogos;
        }
        if (presupuestoIndex != null) {
          _presupuesto = resultados[presupuestoIndex!] as Presupuesto;
        }
        if (clientesIndex != null) {
          _clientes = resultados[clientesIndex!] as List<Cliente>;
        }
        if (cobrosRutaIndex != null) {
          _cobrosRuta = resultados[cobrosRutaIndex!] as List<CobroRuta>;
          _cobrosConPagoInstantaneo.clear();
        }
        if (creditosIndex != null) {
          final PaginaDatos<CreditoRegistro> pagina =
              resultados[creditosIndex!] as PaginaDatos<CreditoRegistro>;
          _creditos = pagina.items;
          _siguienteOffsetCreditos = pagina.nextOffset ?? _creditos.length;
          _hayMasCreditos = pagina.hasMore;
        }
        if (conteoCreditosIndex != null) {
          _conteoCreditosInicio =
              resultados[conteoCreditosIndex!] as ConteoCreditosInicio;
        }
        if (movimientosCajaIndex != null) {
          final PaginaDatos<MovimientoCaja> pagina =
              resultados[movimientosCajaIndex!] as PaginaDatos<MovimientoCaja>;
          _movimientosCaja = pagina.items;
          _siguienteOffsetMovimientosCaja =
              pagina.nextOffset ?? _movimientosCaja.length;
          _hayMasMovimientosCaja = pagina.hasMore;
        }
        _ajustarSelecciones();
      });
    } catch (error, stackTrace) {
      if (!mounted || cargaActual != _cargaSerial) {
        return;
      }
      debugPrint('[ErrorCarga] $error\n$stackTrace');
      _manejarErrorCarga(error);
    } finally {
      if (mounted && cargaActual == _cargaSerial) {
        setState(() {
          if (creditos) {
            _cargandoCreditos = false;
          }
          if (movimientosCaja) {
            _cargandoMovimientosCaja = false;
          }
        });
      }
    }
  }

  void _manejarErrorCarga(Object error) {
    final String mensaje = _mensajeError(error);
    if (!mounted) {
      return;
    }

    setState(() {
      _error = mensaje;
      _cargando = false;
      _cargandoCreditos = false;
      _cargandoMovimientosCaja = false;
      _cargandoMasCreditos = false;
      _cargandoMasMovimientosCaja = false;
    });

    if (error is ApiException && error.statusCode == 401) {
      _cerrarSesion();
      return;
    }

    _mostrarMensaje(mensaje);
  }

  void _recargarEnSegundoPlano({
    bool catalogos = true,
    bool presupuesto = true,
    bool clientes = true,
    bool cobrosRuta = true,
    bool creditos = true,
    bool movimientosCaja = true,
  }) {
    if (_usuarioSesion == null) {
      return;
    }

    if (_usuarioSesion!.esSuperAdmin) {
      unawaited(_cargarOrganizacionesSuperAdmin());
      return;
    }

    unawaited(
      _recargarDatos(
        catalogos: catalogos,
        presupuesto: presupuesto,
        clientes: clientes,
        cobrosRuta: cobrosRuta,
        creditos: creditos,
        movimientosCaja: movimientosCaja,
      ),
    );
  }

  Future<void> _abrirGestionEmpleados() async {
    if (!_puedeVerEmpleados) {
      _mostrarMensaje('No tienes permiso para ver empleados');
      return;
    }

    _seleccionarSeccion(_indiceGestionEmpleados);
  }

  Future<List<EmpleadoGestion>> _obtenerEmpleadosGestion() async {
    return (await _apiClient.getList('/usuarios'))
        .map(
          (dynamic item) =>
              EmpleadoGestion.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<List<ActividadEmpleado>> _obtenerActividadEmpleadosGestion(
    ActividadEmpleadosFiltros filtros,
  ) async {
    return (await _apiClient.getList(
      '/usuarios/actividad',
      query: filtros.toQuery(),
    ))
        .map(
          (dynamic item) =>
              ActividadEmpleado.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<bool> _abrirCrearEmpleado() async {
    return mostrarDialogoCrearEmpleado(
      context: context,
      apiClient: _apiClient,
      esAdministrador: _usuarioSesion?.esAdministrador ?? false,
      onRecargar: _cargar,
      mostrarMensaje: _mostrarMensaje,
      setGuardando: (bool g) {
        if (mounted) {
          setState(() => _guardando = g);
        }
      },
      mensajeError: _mensajeError,
    );
  }

  Future<EmpleadoGestion?> _modificarEmpleadoGestion(
    EmpleadoGestion empleado,
  ) async {
    return mostrarDialogoModificarEmpleado(
      context: context,
      apiClient: _apiClient,
      esAdministrador: _usuarioSesion?.esAdministrador ?? false,
      empleado: empleado,
      mostrarMensaje: _mostrarMensaje,
    );
  }

  void _ajustarSelecciones() {
    final Catalogos? catalogos = _catalogos;
    if (catalogos == null) {
      return;
    }

    _rutaFiltroId = _mantenerSeleccion(
      _rutaFiltroId,
      catalogos.rutas.map((RutaCatalogo ruta) => ruta.id),
      permitirNulo: true,
    );
    _cajaInicioFiltroId = _mantenerSeleccion(
      _cajaInicioFiltroId,
      catalogos.cajasMenores.map((CajaMenorCatalogo caja) => caja.id),
      valorTodos: _todasLasCajasFiltro,
      valorPredeterminado: _cajaActivaPredeterminadaId(catalogos),
    );
    _cajaMenorFiltroId = _mantenerSeleccion(
      _cajaMenorFiltroId,
      catalogos.cajasMenores.map((CajaMenorCatalogo caja) => caja.id),
      permitirNulo: true,
    );
  }

  String? _mantenerSeleccion(
    String? actual,
    Iterable<String> valores, {
    bool permitirNulo = false,
    String? valorTodos,
    String? valorPredeterminado,
  }) {
    final List<String> disponibles = valores.toList(growable: false);
    if (valorTodos != null && actual == valorTodos) {
      return valorTodos;
    }
    if (actual != null && disponibles.contains(actual)) {
      return actual;
    }
    if (permitirNulo) {
      return null;
    }
    if (valorPredeterminado != null &&
        disponibles.contains(valorPredeterminado)) {
      return valorPredeterminado;
    }
    return disponibles.isEmpty ? null : disponibles.first;
  }

  String? _cajaActivaPredeterminadaId(Catalogos? catalogos) {
    return _cajaActivaMasRecienteId(
      catalogos?.cajasMenores ?? const <CajaMenorCatalogo>[],
    );
  }

  String? _cajaActivaMasRecienteId(List<CajaMenorCatalogo> cajas) {
    final List<CajaMenorCatalogo> activas = cajas
        .where((CajaMenorCatalogo caja) => caja.activa)
        .toList(growable: false);
    if (activas.isEmpty) {
      return null;
    }

    CajaMenorCatalogo masReciente = activas.first;
    for (final CajaMenorCatalogo caja in activas.skip(1)) {
      final DateTime? fechaCaja = caja.fechaApertura;
      final DateTime? fechaActual = masReciente.fechaApertura;
      if (fechaActual == null ||
          (fechaCaja != null && fechaCaja.isAfter(fechaActual))) {
        masReciente = caja;
      }
    }

    return masReciente.id;
  }

  void _guardarClienteLocal(Cliente cliente) {
    if (!mounted) {
      return;
    }

    setState(() {
      final List<Cliente> actualizados = _clientes
          .where((Cliente item) => item.id != cliente.id)
          .toList(growable: true)
        ..add(cliente)
        ..sort(
          (Cliente left, Cliente right) =>
              left.nombreCompleto.compareTo(right.nombreCompleto),
        );
      _clientes = actualizados.toList(growable: false);
      _ajustarSelecciones();
    });
  }

  void _eliminarClienteLocal(String clienteId) {
    if (!mounted) {
      return;
    }

    setState(() {
      _clientes = _clientes
          .where((Cliente item) => item.id != clienteId)
          .toList(growable: false);
      _ajustarSelecciones();
    });
  }

  void _guardarCajaMenorLocal(CajaMenorCatalogo caja) {
    final Catalogos? catalogos = _catalogos;
    if (!mounted || catalogos == null) {
      return;
    }

    setState(() {
      final List<CajaMenorCatalogo> cajas = catalogos.cajasMenores
          .where((CajaMenorCatalogo item) => item.id != caja.id)
          .toList(growable: true)
        ..add(caja)
        ..sort((CajaMenorCatalogo left, CajaMenorCatalogo right) {
          if (left.activa != right.activa) {
            return left.activa ? -1 : 1;
          }
          return left.nombre.compareTo(right.nombre);
        });
      _catalogos = catalogos.copyWith(
        cajasMenores: cajas.toList(growable: false),
      );
      _ajustarSelecciones();
    });
  }

  void _guardarMovimientoCajaLocal(MovimientoCaja movimiento) {
    if (!mounted) {
      return;
    }

    setState(() {
      _movimientosCaja = <MovimientoCaja>[
        movimiento,
        ..._movimientosCaja.where(
          (MovimientoCaja item) => item.id != movimiento.id,
        ),
      ].toList(growable: false);
    });
  }

  void _guardarCreditoLocal(CreditoRegistro credito) {
    if (!mounted) {
      return;
    }

    setState(() {
      final List<CreditoRegistro> actualizados = _creditos
          .where((CreditoRegistro item) => item.id != credito.id)
          .toList(growable: true)
        ..add(credito)
        ..sort(
          (CreditoRegistro left, CreditoRegistro right) =>
              right.fechaInicio.compareTo(left.fechaInicio),
        );
      _creditos = actualizados.toList(growable: false);
    });
  }

  List<CobroRuta> _filtrarCobros({bool incluirEstado = true}) {
    final String consulta = _buscarRutaController.text.trim().toLowerCase();
    return _cobrosRuta.where((CobroRuta cobro) {
      if (incluirEstado &&
          _filtroEstadoRuta.estadoCobro != null &&
          cobro.estadoCobro != _filtroEstadoRuta.estadoCobro) {
        return false;
      }

      final bool coincideRuta =
          _rutaFiltroId == null || cobro.rutaId == _rutaFiltroId;
      final bool coincideBusqueda = consulta.isEmpty ||
          cobro.cliente.toLowerCase().contains(consulta) ||
          (cobro.cedula ?? '').toLowerCase().contains(consulta) ||
          (cobro.negocio ?? '').toLowerCase().contains(consulta) ||
          (cobro.direccion ?? '').toLowerCase().contains(consulta) ||
          cobro.ruta.toLowerCase().contains(consulta);
      return coincideRuta && coincideBusqueda;
    }).toList(growable: false);
  }

  List<CreditoRegistro> _filtrarCreditos() {
    final String consulta = _buscarCreditoController.text.trim().toLowerCase();
    final DateTime? desde =
        _fechaCreditoDesde == null ? null : _soloFecha(_fechaCreditoDesde!);
    final DateTime? hasta =
        _fechaCreditoHasta == null ? null : _soloFecha(_fechaCreditoHasta!);

    return _creditos.where((CreditoRegistro credito) {
      final DateTime fechaInicio = _soloFecha(credito.fechaInicio);

      if (_filtroCredito == FiltroEstadoCredito.activos && !credito.activo) {
        return false;
      }

      if (_filtroCredito == FiltroEstadoCredito.inactivos &&
          !credito.inactivo) {
        return false;
      }

      if (desde != null && fechaInicio.isBefore(desde)) {
        return false;
      }

      if (hasta != null && fechaInicio.isAfter(hasta)) {
        return false;
      }

      if (consulta.isEmpty) {
        return true;
      }

      return credito.cliente.toLowerCase().contains(consulta) ||
          (credito.cedula ?? '').toLowerCase().contains(consulta) ||
          (credito.negocio ?? '').toLowerCase().contains(consulta) ||
          (credito.direccion ?? '').toLowerCase().contains(consulta) ||
          credito.ruta.toLowerCase().contains(consulta) ||
          (credito.cajaMenor ?? '').toLowerCase().contains(consulta) ||
          credito.estado.nombre.toLowerCase().contains(consulta);
    }).toList(growable: false);
  }

  void _mostrarCuotasRegistradas() {
    if (!mounted) {
      return;
    }

    if (_buscarRutaController.text.isNotEmpty) {
      _buscarRutaController.clear();
    }

    setState(() {
      _seccionActual = 1;
      _rutaFiltroId = null;
    });
  }

  List<Cliente> _filtrarClientes() {
    final String consulta = _buscarClienteController.text.trim().toLowerCase();
    if (consulta.isEmpty) {
      return _clientes;
    }

    return _clientes
        .where(
          (Cliente cliente) =>
              cliente.nombreCompleto.toLowerCase().contains(consulta) ||
              (cliente.cedula ?? '').toLowerCase().contains(consulta) ||
              (cliente.direccion ?? '').toLowerCase().contains(consulta) ||
              (cliente.nombreComercial ?? '')
                  .toLowerCase()
                  .contains(consulta) ||
              (cliente.telefono ?? '').toLowerCase().contains(consulta) ||
              (cliente.correo ?? '').toLowerCase().contains(consulta),
        )
        .toList(growable: false);
  }

  List<MovimientoCaja> _filtrarMovimientosCaja() {
    final String consulta = _buscarCajaController.text.trim().toLowerCase();
    final DateTime? desde =
        _fechaCajaDesde == null ? null : _soloFecha(_fechaCajaDesde!);
    final DateTime? hasta =
        _fechaCajaHasta == null ? null : _soloFecha(_fechaCajaHasta!);

    return _movimientosCaja.where(
      (MovimientoCaja movimiento) {
        final String naturaleza =
            movimiento.tipoMovimiento.naturaleza.toUpperCase();
        final DateTime fechaMovimiento = _soloFecha(movimiento.fechaMovimiento);

        if (_cajaMenorFiltroId != null &&
            movimiento.cajaMenorId != _cajaMenorFiltroId) {
          return false;
        }

        if (_filtroMovimientoCaja == FiltroMovimientoCaja.entradas &&
            naturaleza != 'E') {
          return false;
        }

        if (_filtroMovimientoCaja == FiltroMovimientoCaja.salidas &&
            naturaleza != 'S') {
          return false;
        }

        if (desde != null && fechaMovimiento.isBefore(desde)) {
          return false;
        }

        if (hasta != null && fechaMovimiento.isAfter(hasta)) {
          return false;
        }

        if (consulta.isEmpty) {
          return true;
        }

        return movimiento.cajaMenor.toLowerCase().contains(consulta) ||
            (movimiento.cliente ?? '').toLowerCase().contains(consulta) ||
            (movimiento.clienteIdentificacion ?? '')
                .toLowerCase()
                .contains(consulta) ||
            movimiento.motivo.toLowerCase().contains(consulta) ||
            movimiento.tipoMovimiento.nombre.toLowerCase().contains(consulta) ||
            (movimiento.usuario?.nombreCompleto ?? '')
                .toLowerCase()
                .contains(consulta);
      },
    ).toList(growable: false);
  }

  DateTime _soloFecha(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  PresupuestoItem? _presupuestoPorCaja(String cajaMenorId) {
    final List<PresupuestoItem> items =
        _presupuesto?.items ?? const <PresupuestoItem>[];

    for (final PresupuestoItem item in items) {
      if (item.cajaMenorId == cajaMenorId) {
        return item;
      }
    }

    return null;
  }

  bool _validarPresupuestoCaja(String cajaMenorId, double valorPrincipal) {
    final PresupuestoItem? item = _presupuestoPorCaja(cajaMenorId);
    if (item != null && valorPrincipal > item.presupuesto) {
      _mostrarMensaje(
        'Caja menor insuficiente. El prestamo supera el dinero disponible.',
      );
      return false;
    }
    return true;
  }

  CajaMenorCatalogo? _obtenerCajaMenorAbiertaDeUsuario(String? usuarioId) {
    if (usuarioId == null || usuarioId.isEmpty) {
      return null;
    }
    final List<CajaMenorCatalogo> cajas =
        _catalogos?.cajasMenores ?? const <CajaMenorCatalogo>[];
    return cajas.cast<CajaMenorCatalogo?>().firstWhere(
      (CajaMenorCatalogo? c) {
        if (c == null || !c.estaAbierta) {
          return false;
        }
        if (c.responsable != null) {
          return c.responsable!.id == usuarioId;
        }
        return usuarioId == _usuarioSesion?.id;
      },
      orElse: () => null,
    );
  }

  Future<void> _abrirCrearCreditoModal() async {
    await mostrarDialogoCrearCredito(
      context: context,
      apiClient: _apiClient,
      catalogos: _catalogos,
      clientes: _clientes,
      creditos: _creditos,
      puedeCrearCreditos: _puedeCrearCreditos,
      onAbrirCrearClienteConCredito: _abrirCrearClienteConCredito,
      mensajeDatosBaseCredito: _mensajeDatosBaseCredito,
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      ejecutarAccion: _ejecutarAccion,
      guardarCreditoLocal: _guardarCreditoLocal,
      marcarAccionOfflinePendiente: _marcarAccionOfflinePendiente,
      mostrarCuotasRegistradas: _mostrarCuotasRegistradas,
      recargarEnSegundoPlano: _recargarEnSegundoPlano,
      validarPresupuestoCaja: _validarPresupuestoCaja,
      defaultCajaMenorId:
          _obtenerCajaMenorAbiertaDeUsuario(_usuarioSesion?.id)?.id,
    );
  }

  Future<void> _abrirSeleccionRefinanciacion() async {
    await mostrarDialogoSeleccionRefinanciacion(
      context: context,
      puedeRefinanciar: _puedeRefinanciarCreditos,
      creditosActivos: _creditos
          .where((CreditoRegistro c) => c.activo)
          .toList(growable: false),
      mostrarMensaje: _mostrarMensaje,
      onRefinanciarCredito: _abrirRefinanciarCredito,
    );
  }

  Future<void> _abrirRefinanciarCredito(CreditoRegistro credito) async {
    await mostrarDialogoRefinanciarCredito(
      context: context,
      credito: credito,
      puedeRefinanciar: _puedeRefinanciarCreditos,
      catalogos: _catalogos,
      clientes: _clientes,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      validarPresupuestoCaja: _validarPresupuestoCaja,
      ejecutarAccion: _ejecutarAccion,
      onGuardarCreditoLocal: _guardarCreditoLocal,
      onRecargarEnSegundoPlano: ({
        bool catalogos = false,
        bool cobrosRuta = false,
        bool movimientosCaja = false,
        bool presupuesto = false,
      }) =>
          _recargarEnSegundoPlano(
        catalogos: catalogos,
        cobrosRuta: cobrosRuta,
        movimientosCaja: movimientosCaja,
        presupuesto: presupuesto,
      ),
    );
  }

  Future<void> _abrirModificarCredito(CreditoRegistro credito) async {
    await mostrarDialogoModificarCredito(
      context: context,
      credito: credito,
      puedeModificar: _puedeModificarCreditos,
      catalogos: _catalogos,
      clientes: _clientes,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      setError: (String err) {
        if (mounted) {
          setState(() => _error = err);
        }
      },
      onGuardarCreditoLocal: _guardarCreditoLocal,
      onMarcarAccionOfflinePendiente: _marcarAccionOfflinePendiente,
      onRecargarEnSegundoPlano: _recargarEnSegundoPlano,
    );
  }

  Future<void> _confirmarEliminarCredito(CreditoRegistro credito) async {
    await mostrarDialogoEliminarCredito(
      context: context,
      credito: credito,
      puedeEliminar: _puedeEliminarCreditos,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      ejecutarAccion: _ejecutarAccion,
      onEliminarCreditoLocal: (String id) {
        if (mounted) {
          setState(() {
            _creditos = _creditos
                .where((CreditoRegistro item) => item.id != id)
                .toList(growable: false);
          });
        }
      },
      onRestaurarCreditoLocal: _guardarCreditoLocal,
      onMarcarAccionOfflinePendiente: _marcarAccionOfflinePendiente,
      onRecargarEnSegundoPlano: _recargarEnSegundoPlano,
    );
  }

  Future<void> _abrirRegistrarPago(CobroRuta cobro) async {
    await mostrarDialogoRegistrarPago(
      context: context,
      cobro: cobro,
      puedeAgregarCuota: _puedeAgregarCuota,
      mediosPago: _catalogos?.mediosPago ?? const <MedioPago>[],
      cobrosRuta: _cobrosRuta,
      cuotasEnPago: _cuotasEnPago,
      rutaFiltroId: _rutaFiltroId,
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      onRegistrarPagos: _registrarPagosRuta,
    );
  }

  Future<void> _exportarCobrosRuta() async {
    await exportarCobrosRutaHelper(
      context: context,
      apiClient: _apiClient,
      rutaFiltroId: _rutaFiltroId,
      searchText: _buscarRutaController.text,
      filtroEstadoRuta: _filtroEstadoRuta,
      exportando: _exportando,
      setExportando: (bool exp) {
        if (mounted) {
          setState(() => _exportando = exp);
        }
      },
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      setError: (String err) {
        if (mounted) {
          setState(() => _error = err);
        }
      },
    );
  }

  Future<void> _exportarCreditos() async {
    await exportarCreditosHelper(
      context: context,
      apiClient: _apiClient,
      searchText: _buscarCreditoController.text,
      filtroCredito: _filtroCredito,
      fechaCreditoDesde: _fechaCreditoDesde,
      fechaCreditoHasta: _fechaCreditoHasta,
      exportando: _exportando,
      setExportando: (bool exp) {
        if (mounted) {
          setState(() => _exportando = exp);
        }
      },
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      setError: (String err) {
        if (mounted) {
          setState(() => _error = err);
        }
      },
    );
  }

  Future<void> _exportarMovimientosCaja() async {
    await exportarMovimientosCajaHelper(
      context: context,
      apiClient: _apiClient,
      cajaMenorFiltroId: _cajaMenorFiltroId == _todasLasCajasFiltro
          ? null
          : _cajaMenorFiltroId,
      searchText: _buscarCajaController.text,
      filtroMovimientoCaja: _filtroMovimientoCaja,
      fechaCajaDesde: _fechaCajaDesde,
      fechaCajaHasta: _fechaCajaHasta,
      exportando: _exportando,
      setExportando: (bool exp) {
        if (mounted) {
          setState(() => _exportando = exp);
        }
      },
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      setError: (String err) {
        if (mounted) {
          setState(() => _error = err);
        }
      },
    );
  }

  Future<void> _abrirModificarCliente(Cliente cliente) async {
    await mostrarDialogoModificarCliente(
      context: context,
      cliente: cliente,
      esAdministrador: _usuarioSesion?.esAdministrador ?? false,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      ejecutarAccion: _ejecutarAccion,
      onClienteModificado: _guardarClienteLocal,
      onRecargarEnSegundoPlano: () => _recargarEnSegundoPlano(clientes: true),
    );
  }

  Future<void> _confirmarEliminarCliente(Cliente cliente) async {
    await mostrarDialogoEliminarCliente(
      context: context,
      cliente: cliente,
      esAdministrador: _usuarioSesion?.esAdministrador ?? false,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      ejecutarAccion: _ejecutarAccion,
      onClienteEliminado: _eliminarClienteLocal,
      onRecargarEnSegundoPlano: () => _recargarEnSegundoPlano(clientes: true),
    );
  }

  Future<void> _abrirCrearClienteConCredito() async {
    await mostrarDialogoCrearClienteConCredito(
      context: context,
      catalogos: _catalogos,
      apiClient: _apiClient,
      puedeCrearCreditos: _puedeCrearCreditos,
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      ejecutarAccion: _ejecutarAccion,
      onClienteCreado: _guardarClienteLocal,
      onMostrarCuotasRegistradas: _mostrarCuotasRegistradas,
      onRecargarEnSegundoPlano: _recargarEnSegundoPlano,
      validarPresupuestoCaja: _validarPresupuestoCaja,
    );
  }

  Future<void> _abrirCrearCajaMenor() async {
    await mostrarDialogoCrearCajaMenor(
      context: context,
      puedeCrearCajaMenor: _puedeCrearCajaMenor,
      catalogos: _catalogos,
      usuarioSesion: _usuarioSesion,
      obtenerCajaMenorAbiertaDeUsuario: _obtenerCajaMenorAbiertaDeUsuario,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      ejecutarAccion: _ejecutarAccion,
      onGuardarCajaMenorLocal: _guardarCajaMenorLocal,
      onRecargarEnSegundoPlano: ({
        bool catalogos = false,
        bool cobrosRuta = false,
        bool movimientosCaja = false,
      }) =>
          _recargarEnSegundoPlano(
        catalogos: catalogos,
        cobrosRuta: cobrosRuta,
        movimientosCaja: movimientosCaja,
      ),
    );
  }

  Future<void> _confirmarCerrarCajaMenorSeleccionada() async {
    await mostrarDialogoCerrarCajaMenor(
      context: context,
      puedeCrearCajaMenor: _puedeCrearCajaMenor,
      cajasActivas:
          _catalogos?.cajasMenoresActivas ?? const <CajaMenorCatalogo>[],
      cajaMenorFiltroId: _cajaMenorFiltroId,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      ejecutarAccion: _ejecutarAccion,
      onRecargar: _cargar,
      onLimpiarCajaFiltroId: (String? nuevoFiltroId) {
        if (mounted) {
          setState(() => _cajaMenorFiltroId = nuevoFiltroId);
        }
      },
    );
  }

  Future<void> _abrirMovimientoCaja() async {
    await mostrarDialogoMovimientoCaja(
      context: context,
      puedeRegistrarFlujoCaja: _puedeRegistrarFlujoCaja,
      catalogos: _catalogos,
      cajaMenorFiltroId: _cajaMenorFiltroId,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      ejecutarAccion: _ejecutarAccion,
      onGuardarMovimientoCajaLocal: _guardarMovimientoCajaLocal,
      onRecargarEnSegundoPlano: _recargarEnSegundoPlano,
    );
  }

  Future<void> _abrirEditarMovimientoCaja(MovimientoCaja movimiento) async {
    await mostrarDialogoEditarMovimientoCaja(
      context: context,
      movimiento: movimiento,
      puedeModificarMovimientos: _puedeModificarMovimientos,
      puedeModificarCreditos: _puedeModificarCreditos,
      catalogos: _catalogos,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      mensajeError: _mensajeError,
      setError: (String err) {
        if (mounted) {
          setState(() => _error = err);
        }
      },
      onGuardarMovimientoCajaLocal: _guardarMovimientoCajaLocal,
      onMarcarAccionOfflinePendiente: _marcarAccionOfflinePendiente,
      onRecargarEnSegundoPlano: _recargarEnSegundoPlano,
    );
  }

  Future<void> _confirmarEliminarMovimientoCaja(
    MovimientoCaja movimiento,
  ) async {
    await mostrarDialogoEliminarMovimientoCaja(
      context: context,
      movimiento: movimiento,
      puedeEliminarMovimientos: _puedeEliminarMovimientos,
      puedeEliminarCreditos: _puedeEliminarCreditos,
      apiClient: _apiClient,
      mostrarMensaje: _mostrarMensaje,
      ejecutarAccion: _ejecutarAccion,
      onEliminarMovimientoLocal: (String id) {
        if (mounted) {
          setState(() {
            _movimientosCaja = _movimientosCaja
                .where((MovimientoCaja item) => item.id != id)
                .toList(growable: false);
          });
        }
      },
      onRestaurarMovimientoLocal: (MovimientoCaja m) {
        _guardarMovimientoCajaLocal(m);
      },
      onMarcarAccionOfflinePendiente: _marcarAccionOfflinePendiente,
      onRecargarEnSegundoPlano: _recargarEnSegundoPlano,
    );
  }

  Future<void> _registrarPagosRuta(List<PagoRutaSolicitud> pagos) async {
    if (!_puedeAgregarCuota) {
      _mostrarMensaje('No tienes permiso para agregar cuota');
      return;
    }

    final List<PagoRutaSolicitud> pagosPendientes = pagos
        .where(
          (PagoRutaSolicitud pago) => !_cuotasEnPago.contains(pago.cuotaId),
        )
        .toList(growable: false);
    if (pagosPendientes.isEmpty) {
      _mostrarMensaje('Este pago ya se esta procesando');
      return;
    }

    final List<String> cuotasIds = pagosPendientes
        .map((PagoRutaSolicitud pago) => pago.cuotaId)
        .toList(growable: false);
    if (mounted) {
      setState(() {
        _error = null;
        _cuotasEnPago.addAll(cuotasIds);
      });
    }

    final List<CobroRuta> cobrosAntes = _cobrosRuta;
    final List<String> cobrosAplicados = <String>[];
    for (final PagoRutaSolicitud pago in pagosPendientes) {
      cobrosAplicados.addAll(
        _aplicarPagoRutaOptimista(pago.cuotaId, pago.monto),
      );
    }
    _mostrarMensaje(
      pagosPendientes.length == 1
          ? 'Pago aplicado en pantalla. Confirmando...'
          : '${pagosPendientes.length} pagos aplicados en pantalla. '
              'Confirmando...',
    );

    try {
      await Future.wait<Map<String, dynamic>>(
        pagosPendientes.map((PagoRutaSolicitud pago) {
          return _apiClient.postObject(
            '/pagos',
            <String, dynamic>{
              'creditoCuotaId': pago.cuotaId,
              'montoPagado': pago.monto,
              'medioPagoCodigo': pago.medioPagoCodigo,
              if (pago.observacion != null) 'observacion': pago.observacion,
            },
            queueOffline: true,
          );
        }),
      );
      _mostrarMensaje(
        pagosPendientes.length == 1 ? 'Pago registrado' : 'Pagos registrados',
      );
      _recargarEnSegundoPlano();
    } on OfflineMutationQueuedException catch (error) {
      await _marcarAccionOfflinePendiente(error);
    } catch (error) {
      if (mounted) {
        setState(() {
          _cobrosRuta = cobrosAntes;
          _cobrosConPagoInstantaneo.removeAll(cobrosAplicados);
          _error = _mensajeError(error);
        });
        _mostrarMensaje(_mensajeError(error));
        _recargarEnSegundoPlano();
      }
    } finally {
      if (mounted) {
        setState(() {
          _cuotasEnPago.removeAll(cuotasIds);
        });
      }
    }
  }

  List<String> _aplicarPagoRutaOptimista(String cuotaId, double monto) {
    if (!mounted) {
      return const <String>[];
    }

    final List<String> cobrosAplicados = <String>[];
    setState(() {
      _cobrosRuta = _cobrosRuta.map((CobroRuta cobro) {
        if (cobro.proximaCuotaId != cuotaId) {
          return cobro;
        }

        final double pagoAplicado = math.min(monto, cobro.saldo);
        final double nuevoSaldo = math.max(0, cobro.saldo - pagoAplicado);
        final double nuevoAbonado = math.min(
          cobro.valorTotal,
          cobro.totalAbonado + pagoAplicado,
        );
        final double saldoCuota = math.max(
          0,
          cobro.proximoSaldoCuota - pagoAplicado,
        );
        final bool cuotaCubierta = saldoCuota <= 0.009;
        final bool creditoCubierto = nuevoSaldo <= 0.009;
        final double montoDespuesDeCuota = math.max(
          0,
          pagoAplicado - cobro.proximoSaldoCuota,
        );
        final int cuotasAdicionalesCubiertas =
            cuotaCubierta && cobro.valorCuota > 0
                ? math.min(
                    math.max(0, cobro.cuotasRestantes - 1),
                    montoDespuesDeCuota ~/ cobro.valorCuota,
                  )
                : 0;
        final int cuotasCubiertas =
            cuotaCubierta ? 1 + cuotasAdicionalesCubiertas : 0;
        final int cuotasRestantes = creditoCubierto
            ? 0
            : math.max(0, cobro.cuotasRestantes - cuotasCubiertas);
        cobrosAplicados.add(cobro.id);
        _cobrosConPagoInstantaneo.add(cobro.id);

        return cobro.copyWith(
          totalAbonado: nuevoAbonado,
          saldo: nuevoSaldo,
          cuotasRestantes: cuotasRestantes,
          proximoSaldoCuota: cuotaCubierta ? 0 : saldoCuota,
          proximaCuotaId: cuotaCubierta ? null : cobro.proximaCuotaId,
          proximaNumeroCuota: cuotaCubierta ? null : cobro.proximaNumeroCuota,
          proximaFechaPago: cuotaCubierta ? null : cobro.proximaFechaPago,
          estadoCobro: creditoCubierto ? EstadoCobro.pagado : cobro.estadoCobro,
        );
      }).toList(growable: false);
    });
    return cobrosAplicados;
  }

  Future<bool> _ejecutarAccion(Future<void> Function() action) async {
    if (_guardando) {
      return false;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await action();
      return true;
    } on OfflineMutationQueuedException catch (error) {
      await _marcarAccionOfflinePendiente(error);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _error = _mensajeError(error));
        _mostrarMensaje(_mensajeError(error));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _programarRecargaListasPesadas() {
    _filtrosListasTimer?.cancel();
    _filtrosListasTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || _usuarioSesion == null || _usuarioSesion!.esSuperAdmin) {
        return;
      }

      _recargarDatos(
        creditos: true,
        movimientosCaja: true,
      );
    });

    _refrescar();
  }

  void _programarRecargaPresupuesto() {
    _filtrosListasTimer?.cancel();
    _filtrosListasTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || _usuarioSesion == null || _usuarioSesion!.esSuperAdmin) {
        return;
      }

      setState(() {
        _cajaInicioFiltroId = _cajaInicioFiltroIdValida(_filtrarCajasInicio());
      });
      _recargarDatos(presupuesto: true);
    });

    _refrescar();
  }

  void _cargarMasCreditosSiHaceFalta() {
    if (!_hayMasCreditos ||
        _cargandoCreditos ||
        _cargandoMasCreditos ||
        _usuarioSesion == null ||
        _usuarioSesion!.esSuperAdmin) {
      return;
    }

    unawaited(_cargarMasCreditos());
  }

  void _cargarMasMovimientosCajaSiHaceFalta() {
    if (!_hayMasMovimientosCaja ||
        _cargandoMovimientosCaja ||
        _cargandoMasMovimientosCaja ||
        _usuarioSesion == null ||
        _usuarioSesion!.esSuperAdmin) {
      return;
    }

    unawaited(_cargarMasMovimientosCaja());
  }

  Future<void> _cargarMasCreditos() async {
    setState(() => _cargandoMasCreditos = true);
    final String queryKey = _queryCreditos(offset: 0).toString();

    try {
      final PaginaDatos<CreditoRegistro> pagina =
          await _obtenerCreditosPagina(offset: _siguienteOffsetCreditos);
      if (!mounted || _queryCreditos(offset: 0).toString() != queryKey) {
        return;
      }

      setState(() {
        _creditos = _fusionarPorId(_creditos, pagina.items);
        _siguienteOffsetCreditos = pagina.nextOffset ?? _creditos.length;
        _hayMasCreditos = pagina.hasMore;
      });
    } catch (error) {
      if (mounted) {
        _mostrarMensaje(_mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoMasCreditos = false);
      }
    }
  }

  Future<void> _cargarMasMovimientosCaja() async {
    setState(() => _cargandoMasMovimientosCaja = true);
    final String queryKey = _queryMovimientosCaja(offset: 0).toString();

    try {
      final PaginaDatos<MovimientoCaja> pagina =
          await _obtenerMovimientosCajaPagina(
        offset: _siguienteOffsetMovimientosCaja,
      );
      if (!mounted || _queryMovimientosCaja(offset: 0).toString() != queryKey) {
        return;
      }

      setState(() {
        _movimientosCaja = _fusionarPorId(_movimientosCaja, pagina.items);
        _siguienteOffsetMovimientosCaja =
            pagina.nextOffset ?? _movimientosCaja.length;
        _hayMasMovimientosCaja = pagina.hasMore;
      });
    } catch (error) {
      if (mounted) {
        _mostrarMensaje(_mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoMasMovimientosCaja = false);
      }
    }
  }

  List<T> _fusionarPorId<T>(
    List<T> actuales,
    List<T> nuevos,
  ) {
    final Set<String> vistos = <String>{};
    final List<T> resultado = <T>[];

    for (final T item in <T>[...actuales, ...nuevos]) {
      final String id = switch (item) {
        CreditoRegistro credito => credito.id,
        MovimientoCaja movimiento => movimiento.id,
        _ => item.hashCode.toString(),
      };

      if (vistos.add(id)) {
        resultado.add(item);
      }
    }

    return resultado;
  }

  void _refrescar() {
    if (mounted) {
      setState(() {});
    }
  }

  void _mostrarMensaje(String message) {
    if (!mounted) {
      return;
    }

    _mensajeTimer?.cancel();
    _mensajeOverlay?.remove();
    _mensajeOverlay = null;

    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) {
        return AvisoFlotante(
          message: message,
          tipo: calcularTipoMensaje(message),
          onDismissed: () {
            _mensajeTimer?.cancel();
            if (_mensajeOverlay == entry) {
              _mensajeOverlay?.remove();
              _mensajeOverlay = null;
            }
          },
        );
      },
    );

    _mensajeOverlay = entry;
    overlay.insert(entry);
    _mensajeTimer = Timer(const Duration(milliseconds: 4200), () {
      if (_mensajeOverlay == entry) {
        _mensajeOverlay?.remove();
        _mensajeOverlay = null;
      }
    });
  }

  String _mensajeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    if (error is TimeoutException) {
      return 'La API no respondio a tiempo. Verifica el backend y la conexion del celular.';
    }
    final String detalle = error.toString().toLowerCase();
    if (detalle.contains('connection refused') ||
        detalle.contains('failed to fetch') ||
        detalle.contains('xmlhttprequest error') ||
        detalle.contains('socketexception')) {
      return 'No se pudo conectar con la API. Verifica que el backend este encendido y que API_BASE_URL apunte al puerto correcto.';
    }
    return 'No se pudo completar la acción';
  }
}

class _BotonNavegacionInferior extends StatelessWidget {
  const _BotonNavegacionInferior({
    required this.destino,
    required this.seleccionado,
    required this.onTap,
  });

  final _DestinoMenu destino;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Color color = seleccionado
        ? CobroAppTheme.primary
        : clay.subtleText.withValues(alpha: 0.9);

    return Semantics(
      button: true,
      selected: seleccionado,
      label: destino.etiqueta,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
              decoration: BoxDecoration(
                color: seleccionado ? clay.surfaceHigh : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: seleccionado ? clay.border : Colors.transparent,
                ),
                boxShadow:
                    seleccionado ? clay.raisedShadow : const <BoxShadow>[],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedScale(
                    scale: seleccionado ? 1.1 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      seleccionado ? destino.iconoSeleccionado : destino.icono,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: double.infinity,
                    height: 15,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight:
                              seleccionado ? FontWeight.w900 : FontWeight.w600,
                          letterSpacing: 0,
                        ),
                        child: Text(destino.etiqueta),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinoMenu {
  const _DestinoMenu({
    required this.icono,
    required this.iconoSeleccionado,
    required this.etiqueta,
  });

  final IconData icono;
  final IconData iconoSeleccionado;
  final String etiqueta;
}

enum _AccionSesion {
  recargar,
  cambiarTema,
  sincronizarPendientes,
  gestionEmpleados,
  cerrarSesion,
}
