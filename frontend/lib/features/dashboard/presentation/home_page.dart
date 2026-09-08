import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapcn_flutter/mapcn_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../app/session_cache.dart';
import '../../../core/map/map_tiles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/offline_mutation.dart';
import '../../../core/platform/export_download.dart';
import '../../../core/ui/clay.dart';
import '../../../core/ui/cobro_dropdown.dart';
import '../../routes/data/api_road_router.dart';
import '../../routes/data/device_location_service.dart';
import '../../routes/presentation/desktop_collection_route.dart';

part 'dashboard_charts.dart';

const String _permisoVerEmpleados = 'VER_EMPLEADOS';
const String _permisoCrearCajaMenor = 'CREAR_CAJA_MENOR';
const String _permisoRegistrarFlujoCaja = 'REGISTRAR_FLUJO_CAJA';
const String _permisoCrearCreditos = 'CREAR_CREDITOS';
const String _permisoRefinanciarCreditos = 'REFINANCIAR_CREDITOS';
const String _permisoModificarCreditos = 'MODIFICAR_CREDITOS';
const String _permisoEliminarCreditos = 'ELIMINAR_CREDITOS';
const String _permisoAgregarCuota = 'AGREGAR_CUOTA';
const String _permisoModificarMovimientos = 'MODIFICAR_MOVIMIENTOS';
const String _permisoEliminarMovimientos = 'ELIMINAR_MOVIMIENTOS';

const String _direccionCasaHint = 'Ej: cr14 #28-26';
const String _mensajeDireccionCasa =
    'Escribe la direccion de la casa asociada a esta ubicacion';
const String _mensajeUbicacionCasa =
    'Ubicacion marcada. Escribe la direccion de la casa, ej: cr14 #28-26';

const List<_PermisoEmpleadoDef> _permisosEmpleado = <_PermisoEmpleadoDef>[
  _PermisoEmpleadoDef(
    codigo: _permisoVerEmpleados,
    nombre: 'Ver empleados',
  ),
  _PermisoEmpleadoDef(
    codigo: _permisoCrearCajaMenor,
    nombre: 'Crear caja menor',
  ),
  _PermisoEmpleadoDef(
    codigo: _permisoRegistrarFlujoCaja,
    nombre: 'Registrar flujo en caja menor',
  ),
  _PermisoEmpleadoDef(
    codigo: _permisoCrearCreditos,
    nombre: 'Crear creditos',
  ),
  _PermisoEmpleadoDef(
    codigo: _permisoRefinanciarCreditos,
    nombre: 'Refinanciar creditos',
  ),
  _PermisoEmpleadoDef(
    codigo: _permisoModificarCreditos,
    nombre: 'Modificar creditos',
  ),
  _PermisoEmpleadoDef(
    codigo: _permisoEliminarCreditos,
    nombre: 'Eliminar creditos',
  ),
  _PermisoEmpleadoDef(
    codigo: _permisoAgregarCuota,
    nombre: 'Agregar cuota',
  ),
  _PermisoEmpleadoDef(
    codigo: _permisoModificarMovimientos,
    nombre: 'Modificar movimientos',
  ),
  _PermisoEmpleadoDef(
    codigo: _permisoEliminarMovimientos,
    nombre: 'Eliminar movimientos',
  ),
];

const List<String> _permisosEmpleadoCodigos = <String>[
  _permisoVerEmpleados,
  _permisoCrearCajaMenor,
  _permisoRegistrarFlujoCaja,
  _permisoCrearCreditos,
  _permisoRefinanciarCreditos,
  _permisoModificarCreditos,
  _permisoEliminarCreditos,
  _permisoAgregarCuota,
  _permisoModificarMovimientos,
  _permisoEliminarMovimientos,
];

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
  static const double _desktopRouteMapBreakpoint = 1050;
  static const int _pageSize = 40;
  static const String _interesCreditoPredeterminado = '20';
  static const String _plazoCreditoPredeterminado = '30';
  static const String _todasLasCajasFiltro = '__todas_las_cajas__';
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
  final TextEditingController _valorCreditoController = TextEditingController();
  final TextEditingController _interesController = TextEditingController(
    text: _interesCreditoPredeterminado,
  );
  final TextEditingController _plazoController = TextEditingController(
    text: _plazoCreditoPredeterminado,
  );
  final TextEditingController _observacionCreditoController =
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
  _ConteoCreditosInicio _conteoCreditosInicio =
      const _ConteoCreditosInicio.vacio();
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
  bool _mostrarContrasenaLogin = false;
  bool _menuLateralExpandido = true;
  _FiltroEstadoRuta _filtroEstadoRuta = _FiltroEstadoRuta.todos;
  _FiltroEstadoCredito _filtroCredito = _FiltroEstadoCredito.todos;
  _FiltroMovimientoCaja _filtroMovimientoCaja = _FiltroMovimientoCaja.todos;
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
  String? _clienteCreditoId;
  final Set<String> _clientesCreditoIds = <String>{};
  final Map<String, TextEditingController> _valorCreditoPorClienteControllers =
      <String, TextEditingController>{};
  String? _rutaCreditoId;
  String? _monedaCreditoCodigo;
  int? _frecuenciaPagoId;
  String? _cajaMenorCreditoId;
  DateTime _fechaInicioCredito = DateTime.now();
  bool _omitirDomingos = true;

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
    _offlineSyncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sincronizarAccionesOffline(),
    );
  }

  List<_DestinoMenu> get _destinosMenuActual {
    return <_DestinoMenu>[
      ..._destinosMenuBase,
      if (_puedeVerEmpleados) _destinoGestionEmpleados,
    ];
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
    _valorCreditoController.dispose();
    for (final TextEditingController controller
        in _valorCreditoPorClienteControllers.values) {
      controller.dispose();
    }
    _interesController.dispose();
    _plazoController.dispose();
    _observacionCreditoController.dispose();
    _loginUsuarioController.dispose();
    _loginContrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SesionUsuario? usuarioSesion = _usuarioSesion;
    final bool esMovil = MediaQuery.sizeOf(context).width < _mobileBreakpoint;

    if (usuarioSesion == null) {
      return _construirLogin(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const _MarcaAplicacion(),
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
                  if (usuarioSesion.puede(_permisoVerEmpleados))
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
                  if (_accionesPendientesOffline > 0)
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
                child: _cargando && _catalogos == null
                    ? const Center(child: CircularProgressIndicator())
                    : usuarioSesion.esSuperAdmin
                        ? _construirSuperAdmin(context)
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

  Widget _construirLogin(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.clay.background),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ClaySurface(
                  radius: 18,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor:
                                CobroAppTheme.primary.withValues(alpha: 0.12),
                            foregroundColor: CobroAppTheme.primary,
                            child: const Icon(Icons.lock_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Iniciar sesion',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
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
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _loginUsuarioController,
                        enabled: !_guardando,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _loginContrasenaController,
                        enabled: !_guardando,
                        obscureText: !_mostrarContrasenaLogin,
                        onSubmitted: (_) => _iniciarSesion(),
                        decoration: InputDecoration(
                          labelText: 'Contrasena',
                          prefixIcon: const Icon(Icons.key_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _mostrarContrasenaLogin =
                                    !_mostrarContrasenaLogin,
                              );
                            },
                            icon: Icon(
                              _mostrarContrasenaLogin
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: CobroAppTheme.danger,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _guardando ? null : _iniciarSesion,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login_rounded),
                        label: const Text('Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
      case 2:
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
    if (index == _indiceCredito) {
      if (_seccionActual != index) {
        setState(() => _seccionActual = index);
      }
      if (_puedeCrearCreditos) {
        _abrirCrearCreditoModal();
      } else {
        _mostrarMensaje('No tienes permiso para crear creditos');
      }
      return;
    }

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
            child: _EstadoVacio(
              icono: Icons.lock_outline_rounded,
              titulo: 'Acceso restringido',
              mensaje: 'No tienes permiso para ver empleados.',
            ),
          ),
        ),
      );
    }

    return _GestionEmpleadosPage(
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

  bool get _puedeVerEmpleados {
    return _usuarioSesion?.puede(_permisoVerEmpleados) ?? false;
  }

  bool get _puedeCrearCajaMenor {
    return _usuarioSesion?.puede(_permisoCrearCajaMenor) ?? false;
  }

  bool get _puedeRegistrarFlujoCaja {
    return _usuarioSesion?.puede(_permisoRegistrarFlujoCaja) ?? false;
  }

  bool get _puedeCrearCreditos {
    return _usuarioSesion?.puede(_permisoCrearCreditos) ?? false;
  }

  bool get _puedeRefinanciarCreditos {
    return _usuarioSesion?.puede(_permisoRefinanciarCreditos) ?? false;
  }

  bool get _puedeModificarCreditos {
    return _usuarioSesion?.puede(_permisoModificarCreditos) ?? false;
  }

  bool get _puedeEliminarCreditos {
    return _usuarioSesion?.puede(_permisoEliminarCreditos) ?? false;
  }

  bool get _puedeAgregarCuota {
    return _usuarioSesion?.puede(_permisoAgregarCuota) ?? false;
  }

  bool get _puedeModificarMovimientos {
    return _usuarioSesion?.puede(_permisoModificarMovimientos) ?? false;
  }

  bool get _puedeEliminarMovimientos {
    return _usuarioSesion?.puede(_permisoEliminarMovimientos) ?? false;
  }

  Widget _construirPresupuesto(BuildContext context) {
    final List<CajaMenorCatalogo> cajasInicio = _filtrarCajasInicio();
    final String? cajaInicioSeleccionada = _cajaInicioFiltroIdValida(
      cajasInicio,
    );
    final List<PresupuestoItem> itemsInicio = cajasInicio.isEmpty
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

    return _PaginaInicioPresupuesto(
      totales: totales,
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
      onVerCreditos: () => _mostrarCreditosInicio(_FiltroEstadoCredito.todos),
      onVerActivos: () => _mostrarCreditosInicio(_FiltroEstadoCredito.activos),
      onVerInactivos: () =>
          _mostrarCreditosInicio(_FiltroEstadoCredito.inactivos),
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
    final bool mostrarMapaDesktop =
        MediaQuery.sizeOf(context).width >= _desktopRouteMapBreakpoint;
    final List<CobroRuta> cobrosBase = _filtrarCobros(incluirEstado: false);
    final List<CobroRuta> cobros = _filtrarCobros();
    final int atrasados = cobrosBase
        .where((CobroRuta cobro) => cobro.estadoCobro == EstadoCobro.atrasado)
        .length;
    final int pendientes = cobrosBase
        .where((CobroRuta cobro) => cobro.estadoCobro == EstadoCobro.pendiente)
        .length;
    final int alDia = cobrosBase
        .where((CobroRuta cobro) => cobro.estadoCobro == EstadoCobro.alDia)
        .length;
    final int pagados = cobrosBase
        .where((CobroRuta cobro) => cobro.estadoCobro == EstadoCobro.pagado)
        .length;

    final Widget filtros = _FiltrosRuta(
      buscarController: _buscarRutaController,
      rutas: _catalogos?.rutas ?? const <RutaCatalogo>[],
      rutaSeleccionadaId: _rutaFiltroId,
      exportando: _exportando,
      vistaMapaDesktop: mostrarMapaDesktop,
      mostrarLimpiarFiltros: _hayFiltrosRuta,
      onRutaChanged: (String? rutaId) {
        setState(() => _rutaFiltroId = rutaId);
      },
      onExportar: _exportarCobrosRuta,
      onLimpiarFiltros: _limpiarFiltrosRuta,
    );
    final Widget resumen = _ResumenEstados(
      alDia: alDia,
      pendientes: pendientes,
      atrasados: atrasados,
      pagados: pagados,
      filtro: _filtroEstadoRuta,
      onFiltroChanged: (_FiltroEstadoRuta filtro) {
        setState(() {
          _filtroEstadoRuta =
              _filtroEstadoRuta == filtro ? _FiltroEstadoRuta.todos : filtro;
        });
      },
    );

    if (mostrarMapaDesktop) {
      final List<CollectionMapCustomer> mapCustomers =
          cobros.map(_mapCustomerFromCobro).toList(growable: false);
      final Map<String, CobroRuta> cobroById = <String, CobroRuta>{
        for (final CobroRuta cobro in cobros) cobro.id: cobro,
      };

      return DesktopCollectionRoute(
        header: const _Encabezado(
          titulo: 'Ruta activa',
          subtitulo: 'Cobros geolocalizados y recorrido más rápido',
          acciones: <Widget>[],
        ),
        filters: filtros,
        summary: resumen,
        customers: mapCustomers,
        roadRouter: _roadRouter,
        onRefresh: _cargar,
        error: _error == null ? null : _ErrorBanner(message: _error!),
        onCollect: (CollectionMapCustomer customer) {
          final CobroRuta? cobro = cobroById[customer.creditId];
          if (cobro != null && _puedeRegistrarPagoRuta(cobro)) {
            _abrirRegistrarPago(cobro);
          }
        },
        cardBuilder: (
          BuildContext context,
          CollectionMapCustomer customer,
          bool selected,
          VoidCallback onSelected,
        ) {
          final CobroRuta cobro = cobroById[customer.creditId]!;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelected,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.all(selected ? 2 : 0),
                decoration: BoxDecoration(
                  color: selected
                      ? CobroAppTheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected
                        ? CobroAppTheme.primary.withValues(alpha: 0.6)
                        : Colors.transparent,
                  ),
                ),
                child: _TarjetaCobroRuta(
                  cobro: cobro,
                  pagoEnProceso: cobro.proximaCuotaId != null &&
                      _cuotasEnPago.contains(cobro.proximaCuotaId),
                  pagoAplicadoInstantaneo:
                      _cobrosConPagoInstantaneo.contains(cobro.id),
                  onGuardarUbicacion:
                      _guardando ? null : () => _guardarUbicacionCliente(cobro),
                  onRegistrarPago: _puedeRegistrarPagoRuta(cobro)
                      ? () => _abrirRegistrarPago(cobro)
                      : null,
                ),
              ),
            ),
          );
        },
      );
    }

    return _Pagina(
      titulo: 'Ruta activa',
      subtitulo: 'Cuotas pendientes desde créditos reales',
      error: _error,
      onRefresh: _cargar,
      children: <Widget>[
        filtros,
        const SizedBox(height: 14),
        resumen,
        const SizedBox(height: 16),
        if (cobros.isEmpty)
          _EstadoVacio(
            icono: Icons.route_outlined,
            titulo: 'Sin cuotas por cobrar',
            mensaje: 'No hay créditos activos con saldo para el filtro actual.',
            accion: FilledButton.icon(
              onPressed: _guardando || !_puedeCrearCreditos
                  ? null
                  : _abrirCrearCreditoModal,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Crear credito'),
            ),
          )
        else
          ...cobros.map(
            (CobroRuta cobro) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TarjetaCobroRuta(
                cobro: cobro,
                pagoEnProceso: cobro.proximaCuotaId != null &&
                    _cuotasEnPago.contains(cobro.proximaCuotaId),
                pagoAplicadoInstantaneo:
                    _cobrosConPagoInstantaneo.contains(cobro.id),
                onGuardarUbicacion:
                    _guardando ? null : () => _guardarUbicacionCliente(cobro),
                onRegistrarPago: _guardando ||
                        cobro.proximaCuotaId == null ||
                        _cuotasEnPago.contains(cobro.proximaCuotaId) ||
                        _cobrosConPagoInstantaneo.contains(cobro.id) ||
                        !_puedeAgregarCuota
                    ? null
                    : () => _abrirRegistrarPago(cobro),
              ),
            ),
          ),
      ],
    );
  }

  Widget _construirNuevoCredito(BuildContext context) {
    final Catalogos? catalogos = _catalogos;
    final List<CreditoRegistro> creditos = _filtrarCreditos();
    final bool mostrandoCargaInicialCreditos =
        _cargandoCreditos && creditos.isEmpty;
    final bool hayCreditoActivo =
        _creditos.any((CreditoRegistro credito) => credito.activo);
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
    final String mensajeDatosBase = _mensajeDatosBaseCredito(catalogos);

    return _Pagina(
      titulo: 'Credito',
      subtitulo: 'Creacion, refinanciacion e historial',
      error: _error,
      onRefresh: _cargar,
      onNearEnd: _cargarMasCreditosSiHaceFalta,
      acciones: <Widget>[
        OutlinedButton.icon(
          onPressed:
              _guardando || !hayCreditoActivo || !_puedeRefinanciarCreditos
                  ? null
                  : _abrirSeleccionRefinanciacion,
          icon: const Icon(Icons.currency_exchange_rounded),
          label: const Text('Refinanciar'),
        ),
        FilledButton.icon(
          onPressed: _guardando || !_puedeCrearCreditos
              ? null
              : _abrirCrearCreditoModal,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Crear credito'),
        ),
      ],
      children: <Widget>[
        if (!mostrandoCargaInicialCreditos && !listo && _creditos.isEmpty)
          _EstadoVacio(
            icono: Icons.add_business_outlined,
            titulo: 'Faltan datos base',
            mensaje: faltanClientes && puedeCrearClienteConCredito
                ? 'Crea un cliente y registra su credito en el mismo formulario.'
                : mensajeDatosBase,
            accion: FilledButton.icon(
              onPressed: _guardando || !_puedeCrearCreditos
                  ? null
                  : _abrirCrearCreditoModal,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Añadir crédito'),
            ),
          ),
        TextField(
          controller: _buscarCreditoController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Buscar credito, cliente o ruta',
          ),
        ),
        const SizedBox(height: 12),
        _construirFiltrosCredito(context),
        const SizedBox(height: 16),
        if (mostrandoCargaInicialCreditos)
          const _SkeletonListaCreditos()
        else if (creditos.isEmpty)
          _EstadoVacio(
            icono: Icons.request_quote_outlined,
            titulo: 'No hay nada',
            mensaje: 'No hay creditos para mostrar con el filtro actual.',
            accion: FilledButton.icon(
              onPressed: _guardando || !_puedeCrearCreditos
                  ? null
                  : _abrirCrearCreditoModal,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Crear credito'),
            ),
          )
        else
          ...creditos.map(
            (CreditoRegistro credito) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TarjetaCreditoRegistro(
                credito: credito,
                puedeModificar: _puedeModificarCreditos,
                puedeEliminar: _puedeEliminarCreditos,
                onModificar: () => _abrirModificarCredito(credito),
                onEliminar: () => _confirmarEliminarCredito(credito),
                onRefinanciar:
                    credito.activo && !_guardando && _puedeRefinanciarCreditos
                        ? () => _abrirRefinanciarCredito(credito)
                        : null,
              ),
            ),
          ),
        if (_cargandoMasCreditos)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  String _mensajeDatosBaseCredito(Catalogos? catalogos) {
    if (catalogos == null) {
      return 'No se pudieron cargar los catalogos.';
    }

    final List<String> faltantes = <String>[
      if (_clientes.isEmpty) 'clientes',
      if (catalogos.monedas.isEmpty) 'monedas',
      if (catalogos.frecuenciasPago.isEmpty) 'frecuencias',
      if (catalogos.cajasMenoresActivas.isEmpty) 'caja menor activa',
    ];

    if (faltantes.isEmpty) {
      return 'Los datos base estan listos.';
    }

    return 'Faltan: ${faltantes.join(', ')}.';
  }

  Widget _construirFiltrosCredito(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SegmentedButton<_FiltroEstadoCredito>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<_FiltroEstadoCredito>>[
            ButtonSegment<_FiltroEstadoCredito>(
              value: _FiltroEstadoCredito.todos,
              icon: Icon(Icons.receipt_long_rounded),
              label: Text('Todos'),
            ),
            ButtonSegment<_FiltroEstadoCredito>(
              value: _FiltroEstadoCredito.activos,
              icon: Icon(Icons.check_circle_outline_rounded),
              label: Text('Activos'),
            ),
            ButtonSegment<_FiltroEstadoCredito>(
              value: _FiltroEstadoCredito.inactivos,
              icon: Icon(Icons.pause_circle_outline_rounded),
              label: Text('Inactivos'),
            ),
          ],
          selected: <_FiltroEstadoCredito>{_filtroCredito},
          onSelectionChanged: (Set<_FiltroEstadoCredito> value) {
            setState(() => _filtroCredito = value.first);
            _recargarDatos(creditos: true);
          },
        ),
        OutlinedButton.icon(
          onPressed: () => _seleccionarFechaCredito(esDesde: true),
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(
            _fechaCreditoDesde == null
                ? 'Desde'
                : 'Desde ${_fechaEtiqueta(_fechaCreditoDesde)}',
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _seleccionarFechaCredito(esDesde: false),
          icon: const Icon(Icons.event_available_rounded),
          label: Text(
            _fechaCreditoHasta == null
                ? 'Hasta'
                : 'Hasta ${_fechaEtiqueta(_fechaCreditoHasta)}',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _exportando ? null : _exportarCreditos,
          icon: _exportando
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined),
          label: Text(_exportando ? 'Exportando' : 'Exportar'),
        ),
        if (_hayFiltrosCredito)
          Tooltip(
            message: 'Limpiar filtros',
            child: IconButton.outlined(
              onPressed: _limpiarFiltrosCredito,
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
          ),
      ],
    );
  }

  Widget _construirCajaMenor(BuildContext context) {
    final List<MovimientoCaja> movimientos = _filtrarMovimientosCaja();
    final bool hayCajaMenor =
        _catalogos?.cajasMenoresActivas.isNotEmpty ?? false;
    final bool mostrandoCargaMovimientosCaja = _cargandoMovimientosCaja;
    return _Pagina(
      titulo: 'Caja menor',
      subtitulo: 'Movimientos y pagos registrados  ',
      error: _error,
      onRefresh: _cargar,
      onNearEnd: _cargarMasMovimientosCajaSiHaceFalta,
      acciones: <Widget>[
        if (hayCajaMenor && _puedeCrearCajaMenor)
          OutlinedButton.icon(
            onPressed: _guardando ? null : _confirmarCerrarCajaMenorSeleccionada,
            icon: const Icon(Icons.lock_clock_rounded),
            label: const Text('Cerrar caja'),
          ),
        if (hayCajaMenor &&
            _puedeCrearCajaMenor &&
            (_usuarioSesion?.esAdministrador ?? false))
          OutlinedButton.icon(
            onPressed: _guardando ? null : _abrirCrearCajaMenor,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Nueva caja menor'),
          ),
        if (hayCajaMenor ? _puedeRegistrarFlujoCaja : _puedeCrearCajaMenor)
          FilledButton.icon(
            onPressed: _guardando
                ? null
                : hayCajaMenor
                    ? _abrirMovimientoCaja
                    : _abrirCrearCajaMenor,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              hayCajaMenor ? 'Registrar movimiento' : 'Crear caja menor',
            ),
          ),
      ],
      children: <Widget>[
        TextField(
          controller: _buscarCajaController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Buscar movimiento o pago',
          ),
        ),
        const SizedBox(height: 12),
        _construirFiltrosCaja(context),
        const SizedBox(height: 16),
        if (mostrandoCargaMovimientosCaja)
          const _SkeletonListaMovimientosCaja()
        else if (movimientos.isEmpty)
          _EstadoVacio(
            icono: Icons.savings_outlined,
            titulo: hayCajaMenor ? 'Sin movimientos' : 'Sin caja menor',
            mensaje: hayCajaMenor
                ? 'No hay movimientos ni pagos para mostrar.'
                : _puedeCrearCajaMenor
                    ? 'Crea una caja menor para comenzar a registrar movimientos.'
                    : 'No tienes una caja menor asignada. Contacta al administrador para que cree tu caja.',
            accion: (hayCajaMenor
                    ? _puedeRegistrarFlujoCaja
                    : _puedeCrearCajaMenor)
                ? FilledButton.icon(
                    onPressed: _guardando
                        ? null
                        : hayCajaMenor
                            ? _abrirMovimientoCaja
                            : _abrirCrearCajaMenor,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      hayCajaMenor
                          ? 'Registrar movimiento'
                          : 'Crear caja menor',
                    ),
                  )
                : null,
          )
        else
          ...movimientos.map(
            (MovimientoCaja movimiento) {
              final bool esDesembolsoCredito =
                  movimiento.referenciaTabla == 'credito_desembolso';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MovimientoCajaItem(
                  movimiento: movimiento,
                  puedeModificar: _puedeModificarMovimientos &&
                      (!esDesembolsoCredito || _puedeModificarCreditos),
                  puedeEliminar: _puedeEliminarMovimientos &&
                      (!esDesembolsoCredito || _puedeEliminarCreditos),
                  onModificar: () => _abrirEditarMovimientoCaja(movimiento),
                  onEliminar: () =>
                      _confirmarEliminarMovimientoCaja(movimiento),
                ),
              );
            },
          ),
        if (_cargandoMasMovimientosCaja)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _construirFiltrosCaja(BuildContext context) {
    final List<CajaMenorCatalogo> cajas =
        _catalogos?.cajasMenores ?? const <CajaMenorCatalogo>[];
    final bool filtroCajaValido = cajas.any(
      (CajaMenorCatalogo caja) => caja.id == _cajaMenorFiltroId,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (cajas.isNotEmpty)
          SizedBox(
            width: 260,
            child: CobroDropdownField<String>(
              key: ValueKey<String>(
                'filtro-caja-${_cajaMenorFiltroId ?? _todasLasCajasFiltro}',
              ),
              labelText: 'Caja',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              value:
                  filtroCajaValido ? _cajaMenorFiltroId : _todasLasCajasFiltro,
              menuWidth: 260,
              items: <CobroDropdownItem<String>>[
                const CobroDropdownItem<String>(
                  value: _todasLasCajasFiltro,
                  label: 'Todas las cajas',
                  subtitle: 'Ver movimientos globales',
                  icon: Icons.all_inbox_rounded,
                  iconColor: Color(0xFF6366F1),
                ),
                ...cajas.map(
                  (CajaMenorCatalogo caja) {
                    final String estadoTexto =
                        caja.estaAbierta ? 'Abierta' : 'Cerrada';
                    final String resp = caja.responsable != null &&
                            caja.responsable!.nombreCompleto.trim().isNotEmpty
                        ? '${caja.responsable!.nombreCompleto.trim()} • '
                        : '';
                    return CobroDropdownItem<String>(
                      value: caja.id,
                      label: caja.nombre,
                      subtitle: '$estadoTexto • $resp${caja.monedaCodigo}',
                      icon: caja.estaAbierta
                          ? Icons.savings_rounded
                          : Icons.lock_outline_rounded,
                      iconColor: caja.estaAbierta
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF6B7280),
                    );
                  },
                ),
              ],
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _cajaMenorFiltroId =
                      value == _todasLasCajasFiltro ? null : value;
                });
                _recargarDatos(movimientosCaja: true);
              },
            ),
          ),
        SegmentedButton<_FiltroMovimientoCaja>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<_FiltroMovimientoCaja>>[
            ButtonSegment<_FiltroMovimientoCaja>(
              value: _FiltroMovimientoCaja.todos,
              icon: Icon(Icons.receipt_long_rounded),
              label: Text('Todos'),
            ),
            ButtonSegment<_FiltroMovimientoCaja>(
              value: _FiltroMovimientoCaja.entradas,
              icon: Icon(Icons.arrow_upward_rounded),
              label: Text('Entradas'),
            ),
            ButtonSegment<_FiltroMovimientoCaja>(
              value: _FiltroMovimientoCaja.salidas,
              icon: Icon(Icons.arrow_downward_rounded),
              label: Text('Salidas'),
            ),
          ],
          selected: <_FiltroMovimientoCaja>{_filtroMovimientoCaja},
          onSelectionChanged: (Set<_FiltroMovimientoCaja> value) {
            setState(() => _filtroMovimientoCaja = value.first);
            _recargarDatos(movimientosCaja: true);
          },
        ),
        OutlinedButton.icon(
          onPressed: () => _seleccionarFechaCaja(esDesde: true),
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(
            _fechaCajaDesde == null
                ? 'Desde'
                : 'Desde ${_fechaEtiqueta(_fechaCajaDesde)}',
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _seleccionarFechaCaja(esDesde: false),
          icon: const Icon(Icons.event_available_rounded),
          label: Text(
            _fechaCajaHasta == null
                ? 'Hasta'
                : 'Hasta ${_fechaEtiqueta(_fechaCajaHasta)}',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _exportando ? null : _exportarMovimientosCaja,
          icon: _exportando
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined),
          label: Text(_exportando ? 'Exportando' : 'Exportar'),
        ),
        if (_hayFiltrosCaja)
          Tooltip(
            message: 'Limpiar filtros',
            child: IconButton.outlined(
              onPressed: _limpiarFiltrosCaja,
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
          ),
      ],
    );
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
    return CollectionMapCustomer(
      id: cobro.id,
      customerId: cobro.clienteId,
      creditId: cobro.id,
      name: cobro.cliente,
      identification: cobro.cedula,
      business: cobro.negocio,
      address: cobro.direccion,
      routeName: cobro.ruta,
      amountLabel: _dinero(cobro.proximoSaldoCuota),
      installmentLabel: _dinero(cobro.valorCuota),
      balanceLabel: _dinero(cobro.saldo),
      dueDateLabel: _fechaEtiqueta(cobro.proximaFechaPago),
      statusLabel: cobro.estadoCobro.etiqueta,
      statusColor: cobro.estadoCobro.color,
      canCollect: _puedeRegistrarPagoRuta(cobro),
      canRoute: _cobroActivoParaRuta(cobro),
      isDueNow: cobro.estadoCobro == EstadoCobro.atrasado ||
          cobro.estadoCobro == EstadoCobro.pendiente,
      latitude: cobro.latitude,
      longitude: cobro.longitude,
    );
  }

  void _aplicarFechaInicioHoy() {
    final DateTime hoy = _soloFecha(_fechaHoraColombia());
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
    final DateTime hoy = _soloFecha(_fechaHoraColombia());
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

  Future<DateTime?> _seleccionarFechaHora({
    required BuildContext context,
    required DateTime initialDateTime,
  }) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) {
      return null;
    }

    if (!context.mounted) {
      return null;
    }

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );

    if (selectedTime == null) {
      return null;
    }

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  void _limpiarFiltrosCaja() {
    setState(() {
      _cajaMenorFiltroId = null;
      _filtroMovimientoCaja = _FiltroMovimientoCaja.todos;
      _fechaCajaDesde = null;
      _fechaCajaHasta = null;
    });
    _recargarDatos(movimientosCaja: true);
  }

  bool get _hayFiltrosCaja =>
      _cajaMenorFiltroId != null ||
      _filtroMovimientoCaja != _FiltroMovimientoCaja.todos ||
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
      _filtroCredito = _FiltroEstadoCredito.todos;
      _fechaCreditoDesde = null;
      _fechaCreditoHasta = null;
    });
    _recargarDatos(creditos: true);
  }

  bool get _hayFiltrosCredito =>
      _filtroCredito != _FiltroEstadoCredito.todos ||
      _fechaCreditoDesde != null ||
      _fechaCreditoHasta != null;

  void _mostrarCreditosInicio(_FiltroEstadoCredito filtro) {
    if (_buscarCreditoController.text.isNotEmpty) {
      _buscarCreditoController.clear();
    }

    setState(() {
      _seccionActual = 2;
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
      _filtroEstadoRuta = _FiltroEstadoRuta.todos;
    });
  }

  bool get _hayFiltrosRuta =>
      _buscarRutaController.text.trim().isNotEmpty ||
      _rutaFiltroId != null ||
      _filtroEstadoRuta != _FiltroEstadoRuta.todos;

  void _mostrarAtrasadosInicio() {
    if (_buscarRutaController.text.isNotEmpty) {
      _buscarRutaController.clear();
    }

    setState(() {
      _seccionActual = 1;
      _rutaFiltroId = null;
      _filtroEstadoRuta = _FiltroEstadoRuta.atrasado;
    });
  }

  Widget _construirClientes(BuildContext context) {
    final List<Cliente> clientes = _filtrarClientes();
    final bool esAdministrador = _usuarioSesion?.esAdministrador ?? false;

    return _Pagina(
      titulo: 'Clientes',
      subtitulo: 'Datos maestros y contactos del esquema cobros',
      error: _error,
      onRefresh: _cargar,
      acciones: <Widget>[
        FilledButton.icon(
          onPressed: _guardando ? null : _abrirCrearClienteConCredito,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Cliente'),
        ),
      ],
      children: <Widget>[
        if (_clientes.isEmpty)
          const _EstadoVacio(
            icono: Icons.groups_outlined,
            titulo: 'Sin clientes',
            mensaje: 'No hay clientes registrados.',
          )
        else ...<Widget>[
          TextField(
            controller: _buscarClienteController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Buscar cliente, cedula o negocio',
            ),
          ),
          const SizedBox(height: 14),
          if (clientes.isEmpty)
            const _EstadoVacio(
              icono: Icons.person_search_rounded,
              titulo: 'Sin resultados',
              mensaje: 'No hay clientes para el filtro actual.',
            )
          else
            ...clientes.map(
              (Cliente cliente) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ClienteItem(
                  cliente: cliente,
                  esAdministrador: esAdministrador,
                  onModificar: () => _abrirModificarCliente(cliente),
                  onEliminar: () => _confirmarEliminarCliente(cliente),
                ),
              ),
            ),
        ],
      ],
    );
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
    if (!(_usuarioSesion?.esAdministrador ?? false)) {
      _mostrarMensaje('Solo el administrador puede crear usuarios');
      return false;
    }

    final bool? creado = await _pedirDatosUsuario(
      titulo: 'Crear empleado',
      accion: 'Crear empleado',
    );

    if (creado ?? false) {
      _mostrarMensaje('Empleado creado');
    }

    return creado ?? false;
  }

  Future<EmpleadoGestion?> _modificarEmpleadoGestion(
    EmpleadoGestion empleado,
  ) async {
    if (!(_usuarioSesion?.esAdministrador ?? false)) {
      _mostrarMensaje('Solo el administrador puede modificar empleados');
      return null;
    }

    final Map<String, String>? datos = await _pedirDatosEmpleado(
      titulo: 'Modificar empleado',
      accion: 'Guardar',
      empleado: empleado,
    );

    if (datos == null) {
      return null;
    }

    final Map<String, dynamic> respuesta = await _apiClient.patchObject(
      '/usuarios/${empleado.id}',
      <String, dynamic>{...datos},
    );
    return EmpleadoGestion.fromJson(respuesta);
  }

  Future<bool?> _pedirDatosUsuario({
    required String titulo,
    required String accion,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController nombreController = TextEditingController();
        final TextEditingController usuarioController = TextEditingController();
        final TextEditingController contrasenaController =
            TextEditingController();
        final TextEditingController correoController = TextEditingController();
        bool mostrarContrasena = false;
        bool guardandoDialog = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) =>
              AlertDialog(
            title: Text(titulo),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nombreController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
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
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: guardandoDialog
                    ? null
                    : () async {
                        final String nombre = nombreController.text.trim();
                        final String nombreUsuario =
                            usuarioController.text.trim().toLowerCase();
                        final String correo = correoController.text.trim();
                        final String contrasena = contrasenaController.text;

                        if (nombre.length < 3) {
                          _mostrarMensaje(
                            'El nombre debe tener minimo 3 caracteres',
                          );
                          return;
                        }
                        if (nombreUsuario.length < 3) {
                          _mostrarMensaje(
                            'El usuario debe tener minimo 3 caracteres',
                          );
                          return;
                        }
                        if (!correo.contains('@')) {
                          _mostrarMensaje('Ingresa un correo valido');
                          return;
                        }
                        if (contrasena.length < 12) {
                          _mostrarMensaje(
                            'La contrasena debe tener minimo 12 caracteres',
                          );
                          return;
                        }

                        setDialogState(() => guardandoDialog = true);
                        if (mounted) {
                          setState(() => _guardando = true);
                        }

                        try {
                          await _apiClient.postObject(
                            '/usuarios',
                            <String, dynamic>{
                              'nombreCompleto': nombre,
                              'usuario': nombreUsuario,
                              'correo': correo,
                              'contrasena': contrasena,
                            },
                            queueOffline: true,
                          );
                          await _cargar();

                          if (!dialogContext.mounted) {
                            return;
                          }

                          Navigator.of(dialogContext).pop(true);
                        } catch (error) {
                          if (dialogContext.mounted) {
                            _mostrarMensaje(_mensajeError(error));
                            setDialogState(() => guardandoDialog = false);
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _guardando = false);
                          }
                        }
                      },
                icon: guardandoDialog
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(accion),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, String>?> _pedirDatosEmpleado({
    required String titulo,
    required String accion,
    required EmpleadoGestion empleado,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController nombreController =
            TextEditingController(text: empleado.nombreCompleto);
        final TextEditingController usuarioController =
            TextEditingController(text: empleado.usuario);
        final TextEditingController correoController =
            TextEditingController(text: empleado.correo);
        final TextEditingController contrasenaController =
            TextEditingController();
        bool mostrarContrasena = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) =>
              AlertDialog(
            title: Text(titulo),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nombreController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
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
                      controller: contrasenaController,
                      obscureText: !mostrarContrasena,
                      decoration: InputDecoration(
                        labelText: 'Nueva contrasena',
                        helperText: 'Dejala vacia para conservar la actual',
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  final String nombre = nombreController.text.trim();
                  final String nombreUsuario =
                      usuarioController.text.trim().toLowerCase();
                  final String correo = correoController.text.trim();
                  final String contrasena = contrasenaController.text;

                  if (nombre.length < 3) {
                    _mostrarMensaje('El nombre debe tener minimo 3 caracteres');
                    return;
                  }
                  if (nombreUsuario.length < 3) {
                    _mostrarMensaje(
                      'El usuario debe tener minimo 3 caracteres',
                    );
                    return;
                  }
                  if (!correo.contains('@')) {
                    _mostrarMensaje('Ingresa un correo valido');
                    return;
                  }
                  if (contrasena.isNotEmpty && contrasena.length < 12) {
                    _mostrarMensaje(
                      'La nueva contrasena debe tener minimo 12 caracteres',
                    );
                    return;
                  }

                  Navigator.of(dialogContext).pop(<String, String>{
                    'nombreCompleto': nombre,
                    'usuario': nombreUsuario,
                    'correo': correo,
                    if (contrasena.isNotEmpty) 'contrasena': contrasena,
                  });
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(accion),
              ),
            ],
          ),
        );
      },
    );
  }

  void _cerrarSesion() {
    _apiClient.setAuthToken(null);
    unawaited(clearCachedSessionPayload());
    _loginContrasenaController.clear();

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
    final int pendientes = await _apiClient.pendingOfflineActions();
    if (!mounted) {
      return;
    }

    setState(() => _accionesPendientesOffline = pendientes);
  }

  Future<void> _sincronizarAccionesOffline() async {
    if (_usuarioSesion == null || _sincronizandoOffline) {
      return;
    }

    setState(() => _sincronizandoOffline = true);

    try {
      final OfflineSyncResult resultado = await _apiClient.syncOfflineActions();
      if (!mounted) {
        return;
      }

      setState(() {
        _accionesPendientesOffline = resultado.pending;
      });

      if (resultado.synced > 0) {
        _mostrarMensaje(
          resultado.pending == 0
              ? 'Acciones pendientes sincronizadas'
              : '${resultado.synced} acciones sincronizadas. '
                  '${resultado.pending} pendientes.',
        );
        unawaited(
          _recargarDatos(
            catalogos: true,
            presupuesto: true,
            clientes: true,
            cobrosRuta: true,
            creditos: true,
            movimientosCaja: true,
          ),
        );
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
        final _PaginaDatos<CreditoRegistro> creditos =
            resultados[4] as _PaginaDatos<CreditoRegistro>;
        final _PaginaDatos<MovimientoCaja> movimientosCaja =
            resultados[5] as _PaginaDatos<MovimientoCaja>;
        _creditos = creditos.items;
        _siguienteOffsetCreditos = creditos.nextOffset ?? _creditos.length;
        _hayMasCreditos = creditos.hasMore;
        _movimientosCaja = movimientosCaja.items;
        _siguienteOffsetMovimientosCaja =
            movimientosCaja.nextOffset ?? _movimientosCaja.length;
        _hayMasMovimientosCaja = movimientosCaja.hasMore;
        _conteoCreditosInicio = resultados[6] as _ConteoCreditosInicio;
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
    final Map<String, dynamic>? datos = await _pedirDatosOrganizacionAdmin();

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
    final Map<String, dynamic>? datos =
        await _pedirDatosOrganizacionAdmin(organizacion: organizacion);

    if (datos == null) {
      return;
    }

    await _actualizarOrganizacionAdmin(
      organizacion,
      datos,
      'Institucion actualizada',
    );
  }

  Future<Map<String, dynamic>?> _pedirDatosOrganizacionAdmin({
    OrganizacionAdmin? organizacion,
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
      text: _numero(organizacion?.montoPlan ?? 0),
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
                            accesoController.text = _fechaValor(selected);
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
                  final double? monto = _parseNumero(montoController.text);

                  if (nombre.length < 3) {
                    _mostrarMensaje('El nombre debe tener minimo 3 caracteres');
                    return;
                  }

                  if (correo.isNotEmpty &&
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) {
                    _mostrarMensaje('Ingresa un email valido');
                    return;
                  }

                  if (monto == null || monto < 0) {
                    _mostrarMensaje('Ingresa un monto valido');
                    return;
                  }

                  Navigator.of(dialogContext).pop(<String, dynamic>{
                    'nombre': nombre,
                    'telefono': telefono.isEmpty ? null : telefono,
                    'correo': correo.isEmpty ? null : correo,
                    'montoPlan': monto,
                    'monedaPlan': moneda,
                    'accesoHasta':
                        accesoHasta == null ? null : _fechaValor(accesoHasta!),
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

  Future<void> _crearAdministradorAdmin() async {
    if (_organizacionesAdmin.isEmpty) {
      _mostrarMensaje('Crea una institucion antes de agregar administradores');
      return;
    }

    final Map<String, dynamic>? creado = await _pedirDatosAdministradorAdmin();

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

  Future<Map<String, dynamic>?> _pedirDatosAdministradorAdmin() async {
    final OrganizacionAdmin organizacionInicial = _organizacionesAdmin.first;
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
                    _OrganizacionAdminPicker(
                      organizaciones: _organizacionesAdmin,
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
                          _mostrarMensaje('Selecciona una institucion');
                          return;
                        }

                        if (nombre.length < 3) {
                          _mostrarMensaje(
                            'El nombre debe tener minimo 3 caracteres',
                          );
                          return;
                        }

                        if (usuario.length < 3 ||
                            !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(usuario)) {
                          _mostrarMensaje(
                            'El usuario debe tener minimo 3 caracteres validos',
                          );
                          return;
                        }

                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(correo)) {
                          _mostrarMensaje('Ingresa un email valido');
                          return;
                        }

                        if (contrasena.length < 12) {
                          _mostrarMensaje(
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
                        if (mounted) {
                          setState(() => _guardando = true);
                        }

                        try {
                          final Map<String, dynamic> creado =
                              await _apiClient.postObject(
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
                            _mostrarMensaje(_mensajeError(error));
                            setDialogState(() => guardandoDialog = false);
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _guardando = false);
                          }
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

  Widget _construirSuperAdmin(BuildContext context) {
    final int suspendidas = _organizacionesAdmin
        .where((OrganizacionAdmin organizacion) => organizacion.suspendida)
        .length;
    final int activas = _organizacionesAdmin.length - suspendidas;

    return _Pagina(
      titulo: 'Instituciones',
      subtitulo: 'Administracion global de accesos y pagos',
      error: _error,
      onRefresh: _cargar,
      acciones: <Widget>[
        FilledButton.icon(
          onPressed: _guardando ? null : _crearOrganizacionAdmin,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Institucion'),
        ),
        FilledButton.tonalIcon(
          onPressed: _guardando ? null : _crearAdministradorAdmin,
          icon: const Icon(Icons.admin_panel_settings_rounded),
          label: const Text('Administrador'),
        ),
        IconButton.filledTonal(
          onPressed: _cargando ? null : _cargar,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recargar',
        ),
      ],
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _EmpleadoGestionMetrica(
              icono: Icons.apartment_rounded,
              etiqueta: 'Instituciones',
              valor: _organizacionesAdmin.length.toString(),
            ),
            _EmpleadoGestionMetrica(
              icono: Icons.check_circle_rounded,
              etiqueta: 'Activas',
              valor: activas.toString(),
              color: CobroAppTheme.success,
            ),
            _EmpleadoGestionMetrica(
              icono: Icons.pause_circle_rounded,
              etiqueta: 'Suspendidas',
              valor: suspendidas.toString(),
              color: CobroAppTheme.danger,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_organizacionesAdmin.isEmpty)
          const _EstadoVacio(
            icono: Icons.apartment_outlined,
            titulo: 'Sin instituciones',
            mensaje: 'No hay instituciones registradas.',
          )
        else
          ..._organizacionesAdmin.map(
            (OrganizacionAdmin organizacion) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OrganizacionAdminItem(
                organizacion: organizacion,
                guardando: _guardando,
                onEditar: () => _editarOrganizacionAdmin(organizacion),
                onActivoChanged: (bool activo) => _actualizarOrganizacionAdmin(
                  organizacion,
                  <String, dynamic>{
                    'activo': activo,
                    if (!activo)
                      'motivoSuspension': 'Suspendido por falta de pagos',
                  },
                  activo ? 'Institucion reactivada' : 'Institucion suspendida',
                ),
              ),
            ),
          ),
      ],
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

  Future<_PaginaDatos<CreditoRegistro>> _obtenerCreditosPagina({
    int offset = 0,
  }) async {
    final Map<String, dynamic> response = await _apiClient.getObject(
      '/creditos',
      query: _queryCreditos(offset: offset),
    );
    return _PaginaDatos.fromJson(
      response,
      CreditoRegistro.fromJson,
    );
  }

  Future<_ConteoCreditosInicio> _obtenerConteoCreditosInicio() async {
    return _ConteoCreditosInicio.fromJson(
      await _apiClient.getObject(
        '/creditos/resumen',
        query: <String, String?>{
          'fechaDesde': _fechaInicioDesde == null
              ? null
              : _fechaValor(_fechaInicioDesde!),
          'fechaHasta': _fechaInicioHasta == null
              ? null
              : _fechaValor(_fechaInicioHasta!),
        },
      ),
    );
  }

  Future<_PaginaDatos<MovimientoCaja>> _obtenerMovimientosCajaPagina({
    int offset = 0,
  }) async {
    final Map<String, dynamic> response = await _apiClient.getObject(
      '/caja-menor/movimientos',
      query: _queryMovimientosCaja(offset: offset),
    );
    return _PaginaDatos.fromJson(
      response,
      MovimientoCaja.fromJson,
    );
  }

  Map<String, String?> _queryCreditos({required int offset}) {
    final String search = _buscarCreditoController.text.trim();
    return <String, String?>{
      'limit': _pageSize.toString(),
      'offset': offset.toString(),
      'search': search.isEmpty ? null : search,
      'estado': switch (_filtroCredito) {
        _FiltroEstadoCredito.todos => 'todos',
        _FiltroEstadoCredito.activos => 'activos',
        _FiltroEstadoCredito.inactivos => 'inactivos',
      },
      'fechaDesde':
          _fechaCreditoDesde == null ? null : _fechaValor(_fechaCreditoDesde!),
      'fechaHasta':
          _fechaCreditoHasta == null ? null : _fechaValor(_fechaCreditoHasta!),
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
      'fechaDesde':
          _fechaInicioDesde == null ? null : _fechaValor(_fechaInicioDesde!),
      'fechaHasta':
          _fechaInicioHasta == null ? null : _fechaValor(_fechaInicioHasta!),
    };
  }

  Map<String, String?> _queryMovimientosCaja({required int offset}) {
    final String search = _buscarCajaController.text.trim();
    return <String, String?>{
      'limit': _pageSize.toString(),
      'offset': offset.toString(),
      'cajaMenorId': _cajaMenorFiltroId,
      'search': search.isEmpty ? null : search,
      'tipo': switch (_filtroMovimientoCaja) {
        _FiltroMovimientoCaja.todos => 'todos',
        _FiltroMovimientoCaja.entradas => 'entradas',
        _FiltroMovimientoCaja.salidas => 'salidas',
      },
      'fechaDesde':
          _fechaCajaDesde == null ? null : _fechaValor(_fechaCajaDesde!),
      'fechaHasta':
          _fechaCajaHasta == null ? null : _fechaValor(_fechaCajaHasta!),
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
    if (_usuarioSesion == null) {
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
          final _PaginaDatos<CreditoRegistro> pagina =
              resultados[creditosIndex!] as _PaginaDatos<CreditoRegistro>;
          _creditos = pagina.items;
          _siguienteOffsetCreditos = pagina.nextOffset ?? _creditos.length;
          _hayMasCreditos = pagina.hasMore;
        }
        if (conteoCreditosIndex != null) {
          _conteoCreditosInicio =
              resultados[conteoCreditosIndex!] as _ConteoCreditosInicio;
        }
        if (movimientosCajaIndex != null) {
          final _PaginaDatos<MovimientoCaja> pagina =
              resultados[movimientosCajaIndex!] as _PaginaDatos<MovimientoCaja>;
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
    if (!mounted) {
      return;
    }

    if (error is ApiException && error.statusCode == 401) {
      _apiClient.setAuthToken(null);
      unawaited(clearCachedSessionPayload());
      setState(() {
        _usuarioSesion = null;
        _error = 'La sesion expiro';
      });
      return;
    }

    setState(() {
      _error = _mensajeError(error);
    });
  }

  void _ajustarSelecciones() {
    final Catalogos? catalogos = _catalogos;
    if (catalogos == null) {
      return;
    }

    _clienteCreditoId = _mantenerSeleccion(
      _clienteCreditoId,
      _clientes.map((Cliente cliente) => cliente.id),
    );
    _mantenerClientesCreditoSeleccionados();
    _rutaCreditoId = _mantenerSeleccion(
      _rutaCreditoId,
      catalogos.rutasAbiertas.map((RutaCatalogo ruta) => ruta.id),
      permitirNulo: true,
    );
    _rutaFiltroId = _mantenerSeleccion(
      _rutaFiltroId,
      catalogos.rutas.map((RutaCatalogo ruta) => ruta.id),
      permitirNulo: true,
    );
    _monedaCreditoCodigo = _mantenerSeleccion(
      _monedaCreditoCodigo,
      catalogos.monedas.map((Moneda moneda) => moneda.codigo),
    );
    _frecuenciaPagoId = _mantenerSeleccionInt(
      _frecuenciaPagoId,
      catalogos.frecuenciasPago
          .map((FrecuenciaPago frecuencia) => frecuencia.id),
    );
    _cajaMenorCreditoId = _mantenerSeleccion(
      _cajaMenorCreditoId,
      catalogos.cajasMenoresActivas.map((CajaMenorCatalogo caja) => caja.id),
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

  void _mantenerClientesCreditoSeleccionados() {
    final Set<String> disponibles =
        _clientes.map((Cliente cliente) => cliente.id).toSet();
    final List<String> removidos = _clientesCreditoIds
        .where((String clienteId) => !disponibles.contains(clienteId))
        .toList(growable: false);

    for (final String clienteId in removidos) {
      _clientesCreditoIds.remove(clienteId);
      _valorCreditoPorClienteControllers.remove(clienteId)?.dispose();
    }

    if (_clientesCreditoIds.isEmpty && _clienteCreditoId != null) {
      _clientesCreditoIds.add(_clienteCreditoId!);
      _valorCreditoControllerParaCliente(_clienteCreditoId!);
    }
  }

  void _actualizarClientesCreditoSeleccionados(Set<String> clienteIds) {
    final Set<String> disponibles =
        _clientes.map((Cliente cliente) => cliente.id).toSet();
    final Set<String> normalizados = clienteIds
        .where((String clienteId) => disponibles.contains(clienteId))
        .toSet();
    final List<String> removidos = _clientesCreditoIds
        .where((String clienteId) => !normalizados.contains(clienteId))
        .toList(growable: false);

    for (final String clienteId in removidos) {
      _valorCreditoPorClienteControllers.remove(clienteId)?.dispose();
    }

    for (final String clienteId in normalizados) {
      _valorCreditoControllerParaCliente(clienteId);
    }

    _clientesCreditoIds
      ..clear()
      ..addAll(normalizados);
    _clienteCreditoId =
        _clientesCreditoIds.isEmpty ? null : _clientesCreditoIds.first;
  }

  TextEditingController _valorCreditoControllerParaCliente(String clienteId) {
    return _valorCreditoPorClienteControllers.putIfAbsent(
      clienteId,
      () => TextEditingController(text: _valorCreditoController.text),
    );
  }

  void _limpiarMontosCreditoPorCliente() {
    for (final TextEditingController controller
        in _valorCreditoPorClienteControllers.values) {
      controller.clear();
    }
    _valorCreditoController.clear();
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

  int? _mantenerSeleccionInt(int? actual, Iterable<int> valores) {
    final List<int> disponibles = valores.toList(growable: false);
    if (actual != null && disponibles.contains(actual)) {
      return actual;
    }
    return disponibles.isEmpty ? null : disponibles.first;
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
      _clienteCreditoId ??= cliente.id;
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
      if (_clienteCreditoId == clienteId) {
        _clienteCreditoId = null;
      }
      _clientesCreditoIds.remove(clienteId);
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
      _cajaMenorCreditoId ??= caja.id;
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

  CreditoRegistro _creditoOptimistaModificado({
    required CreditoRegistro credito,
    required Catalogos catalogos,
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
    final Cliente cliente = _clientes.firstWhere(
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
        _fechaValor(fechaInicio) != _fechaValor(credito.fechaInicio) ||
        valorPrincipal != credito.valorPrincipal ||
        porcentajeInteres != credito.porcentajeInteres ||
        plazoDias != credito.plazoDias ||
        omitirDomingos != credito.omitirDomingos;
    final _CalculoCredito calculo = _CalculoCredito.desdeFormulario(
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
      actualizadoEn: DateTime.now(),
    );
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

      if (_filtroCredito == _FiltroEstadoCredito.activos && !credito.activo) {
        return false;
      }

      if (_filtroCredito == _FiltroEstadoCredito.inactivos &&
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

        if (_filtroMovimientoCaja == _FiltroMovimientoCaja.entradas &&
            naturaleza != 'E') {
          return false;
        }

        if (_filtroMovimientoCaja == _FiltroMovimientoCaja.salidas &&
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

  TipoMovimientoCaja? _tipoMovimientoCajaPorCodigo(String codigo) {
    final List<TipoMovimientoCaja> tipos =
        _catalogos?.tiposMovimientoCaja ?? const <TipoMovimientoCaja>[];

    for (final TipoMovimientoCaja tipo in tipos) {
      if (tipo.codigo == codigo) {
        return tipo;
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

  Future<bool> _crearCredito({VoidCallback? cerrarFormulario}) async {
    if (_guardando) {
      return false;
    }

    if (!_puedeCrearCreditos) {
      _mostrarMensaje('No tienes permiso para crear creditos');
      return false;
    }

    final List<String> clienteIds = _clientesCreditoIds.isNotEmpty
        ? _clientesCreditoIds.toList(growable: false)
        : <String>[if (_clienteCreditoId != null) _clienteCreditoId!];
    final String? rutaId = _rutaCreditoId;
    final String? monedaCodigo = _monedaCreditoCodigo;
    final int? frecuenciaPagoId = _frecuenciaPagoId;
    final String? cajaMenorId = _cajaMenorCreditoId;

    if (clienteIds.isEmpty ||
        monedaCodigo == null ||
        frecuenciaPagoId == null) {
      _mostrarMensaje('Faltan datos reales para crear el crédito');
      return false;
    }

    if (cajaMenorId == null) {
      _mostrarMensaje('No se puede hacer credito sin caja menor');
      return false;
    }

    final double porcentajeInteres;
    final int plazoDias;
    final Map<String, double> valoresPorCliente = <String, double>{};

    try {
      for (final String clienteId in clienteIds) {
        final TextEditingController controller =
            _valorCreditoControllerParaCliente(clienteId);
        valoresPorCliente[clienteId] = _leerMonto(controller.text);
      }
      porcentajeInteres = _leerPorcentaje(_interesController.text);
      plazoDias = _leerEnteroPositivo(_plazoController.text);
    } catch (error) {
      _mostrarMensaje(_mensajeError(error));
      return false;
    }

    final double valorPrincipalTotal = valoresPorCliente.values.fold<double>(
      0,
      (double total, double valor) => total + valor,
    );

    if (!_validarPresupuestoCaja(cajaMenorId, valorPrincipalTotal)) {
      return false;
    }

    cerrarFormulario?.call();
    _mostrarMensaje(
      clienteIds.length == 1 ? 'Creando credito...' : 'Creando creditos...',
    );

    return _ejecutarAccion(() async {
      int creados = 0;
      int pendientes = 0;
      for (final String clienteId in clienteIds) {
        try {
          final CreditoRegistro credito = CreditoRegistro.fromJson(
            await _apiClient.postObject(
              '/creditos',
              <String, dynamic>{
                'clienteId': clienteId,
                if (rutaId != null) 'rutaId': rutaId,
                'monedaCodigo': monedaCodigo,
                'frecuenciaPagoId': frecuenciaPagoId,
                'fechaInicio': _fechaValor(_fechaInicioCredito),
                'valorPrincipal': valoresPorCliente[clienteId],
                'porcentajeInteres': porcentajeInteres,
                'plazoDias': plazoDias,
                'omitirDomingos': _omitirDomingos,
                'cajaMenorId': cajaMenorId,
                if (_observacionCreditoController.text.trim().isNotEmpty)
                  'observacion': _observacionCreditoController.text.trim(),
              },
              queueOffline: true,
            ),
          );
          _guardarCreditoLocal(credito);
          creados++;
        } on OfflineMutationQueuedException catch (error) {
          pendientes++;
          await _marcarAccionOfflinePendiente(error);
        }
      }
      _limpiarMontosCreditoPorCliente();
      _interesController.text = _interesCreditoPredeterminado;
      _plazoController.text = _plazoCreditoPredeterminado;
      _observacionCreditoController.clear();
      if (creados > 0) {
        _mostrarCuotasRegistradas();
      }
      _mostrarMensaje(
        pendientes > 0
            ? '$pendientes creditos guardados para sincronizar'
            : clienteIds.length == 1
                ? 'Credito creado con sus cuotas'
                : '${clienteIds.length} creditos creados con sus cuotas',
      );
      _recargarEnSegundoPlano(
        catalogos: rutaId == null,
        presupuesto: true,
        cobrosRuta: true,
        movimientosCaja: true,
      );
    });
  }

  Future<void> _abrirCrearCreditoModal() async {
    if (!_puedeCrearCreditos) {
      _mostrarMensaje('No tienes permiso para crear creditos');
      return;
    }

    final Catalogos? catalogos = _catalogos;
    final bool listo = catalogos != null &&
        _clientes.isNotEmpty &&
        catalogos.frecuenciasPago.isNotEmpty &&
        catalogos.monedas.isNotEmpty &&
        catalogos.cajasMenoresActivas.isNotEmpty;

    if (!listo) {
      final bool puedeCrearClienteConCredito = catalogos != null &&
          _clientes.isEmpty &&
          catalogos.frecuenciasPago.isNotEmpty &&
          catalogos.monedas.isNotEmpty &&
          catalogos.cajasMenoresActivas.isNotEmpty;

      if (puedeCrearClienteConCredito) {
        await _abrirCrearClienteConCredito();
        return;
      }

      _mostrarMensaje(_mensajeDatosBaseCredito(catalogos));
      return;
    }

    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        bool guardandoDialogo = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            void actualizarFormulario(VoidCallback action) {
              setState(action);
              setDialogState(() {});
            }

            return AlertDialog(
              title: const Text('Nuevo credito'),
              content: _DialogContent(
                maxWidth: 760,
                child: _FormularioCredito(
                  clientes: _clientes,
                  rutas: catalogos.rutasAbiertas,
                  monedas: catalogos.monedas,
                  frecuencias: catalogos.frecuenciasPago,
                  cajasMenores: catalogos.cajasMenoresActivas,
                  clienteId: _clienteCreditoId,
                  rutaId: _rutaCreditoId,
                  monedaCodigo: _monedaCreditoCodigo,
                  frecuenciaPagoId: _frecuenciaPagoId,
                  cajaMenorId: _cajaMenorCreditoId,
                  fechaInicio: _fechaInicioCredito,
                  omitirDomingos: _omitirDomingos,
                  valorController: _valorCreditoController,
                  clientesSeleccionadosIds: _clientesCreditoIds,
                  valorClienteController: _valorCreditoControllerParaCliente,
                  interesController: _interesController,
                  plazoController: _plazoController,
                  observacionController: _observacionCreditoController,
                  guardando: guardandoDialogo,
                  onClienteChanged: (String? value) {
                    actualizarFormulario(() => _clienteCreditoId = value);
                  },
                  onClientesSeleccionadosChanged: (Set<String> value) {
                    actualizarFormulario(
                      () => _actualizarClientesCreditoSeleccionados(value),
                    );
                  },
                  onRutaChanged: (String? value) {
                    actualizarFormulario(() => _rutaCreditoId = value);
                  },
                  onMonedaChanged: (String? value) {
                    actualizarFormulario(
                      () => _monedaCreditoCodigo = value,
                    );
                  },
                  onFrecuenciaChanged: (int? value) {
                    actualizarFormulario(() => _frecuenciaPagoId = value);
                  },
                  onCajaMenorChanged: (String? value) {
                    actualizarFormulario(() => _cajaMenorCreditoId = value);
                  },
                  onFechaChanged: (DateTime value) {
                    actualizarFormulario(() => _fechaInicioCredito = value);
                  },
                  onOmitirDomingosChanged: (bool value) {
                    actualizarFormulario(() => _omitirDomingos = value);
                  },
                  onCrear: () async {
                    if (guardandoDialogo || _guardando) {
                      return;
                    }

                    setDialogState(() => guardandoDialogo = true);
                    final bool creado = await _crearCredito(
                      cerrarFormulario: () {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      },
                    );

                    if (!dialogContext.mounted) {
                      return;
                    }

                    if (creado) {
                      return;
                    }

                    setDialogState(() => guardandoDialogo = false);
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
  }

  Future<void> _abrirSeleccionRefinanciacion() async {
    if (!_puedeRefinanciarCreditos) {
      _mostrarMensaje('No tienes permiso para refinanciar creditos');
      return;
    }

    final List<CreditoRegistro> activos = _filtrarCreditos()
        .where((CreditoRegistro credito) => credito.activo)
        .toList(growable: false);
    final List<CreditoRegistro> opciones = activos.isNotEmpty
        ? activos
        : _creditos
            .where((CreditoRegistro credito) => credito.activo)
            .toList(growable: false);

    if (opciones.isEmpty) {
      _mostrarMensaje('No hay creditos activos para refinanciar');
      return;
    }

    final CreditoRegistro? seleccionado = await showDialog<CreditoRegistro>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Refinanciar credito'),
          content: _DialogContent(
            maxWidth: 520,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (BuildContext context, int index) {
                  final CreditoRegistro credito = opciones[index];
                  return ListTile(
                    leading: const Icon(Icons.currency_exchange_rounded),
                    title: Text(
                      credito.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_dinero(credito.valorPrincipal)} - ${credito.ruta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(dialogContext).pop(credito),
                  );
                },
                separatorBuilder: (BuildContext context, int index) =>
                    const Divider(height: 1),
                itemCount: opciones.length,
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
      await _abrirRefinanciarCredito(seleccionado);
    }
  }

  Future<void> _abrirRefinanciarCredito(CreditoRegistro credito) async {
    if (!_puedeRefinanciarCreditos) {
      _mostrarMensaje('No tienes permiso para refinanciar creditos');
      return;
    }

    if (!credito.activo) {
      _mostrarMensaje('Solo se pueden refinanciar creditos activos');
      return;
    }

    final Catalogos? catalogos = _catalogos;
    if (catalogos == null ||
        catalogos.frecuenciasPago.isEmpty ||
        catalogos.cajasMenoresActivas.isEmpty) {
      _mostrarMensaje('Necesitas catalogos y caja menor activa');
      return;
    }

    final List<CajaMenorCatalogo> cajasCompatibles =
        catalogos.cajasMenoresActivas
            .where(
              (CajaMenorCatalogo caja) =>
                  caja.monedaCodigo == credito.monedaCodigo,
            )
            .toList(growable: false);
    if (cajasCompatibles.isEmpty) {
      _mostrarMensaje('No hay caja menor activa para esa moneda');
      return;
    }

    final TextEditingController valorController = TextEditingController(
      text: _numero(credito.valorPrincipal),
    );
    final TextEditingController interesController = TextEditingController(
      text: _numero(credito.porcentajeInteres),
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
        _clientes.any((Cliente cliente) => cliente.id == credito.clienteId)
            ? _clientes
            : <Cliente>[
                Cliente(
                  id: credito.clienteId,
                  nombreCompleto: credito.cliente,
                  cedula: credito.cedula,
                  direccion: credito.direccion,
                  nombreComercial: credito.negocio,
                  estadoNombre: 'Activo',
                ),
                ..._clientes,
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
                content: _DialogContent(
                  maxWidth: 600,
                  child: _FormularioCredito(
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
                      if (guardandoDialogo || _guardando) {
                        return;
                      }

                      final String? cajaId = cajaMenorId;
                      final int? frecuenciaId = frecuenciaPagoId;
                      if (cajaId == null || frecuenciaId == null) {
                        _mostrarMensaje('Faltan datos para refinanciar');
                        return;
                      }

                      final double valorNuevo;
                      final double porcentajeInteres;
                      final int plazoDias;
                      try {
                        valorNuevo = _leerMonto(valorController.text);
                        porcentajeInteres =
                            _leerPorcentaje(interesController.text);
                        plazoDias = _leerEnteroPositivo(plazoController.text);
                      } catch (error) {
                        _mostrarMensaje(_mensajeError(error));
                        return;
                      }

                      if (valorNuevo <= credito.valorPrincipal) {
                        _mostrarMensaje(
                          'El nuevo valor debe superar el valor actual',
                        );
                        return;
                      }

                      final double incremento =
                          valorNuevo - credito.valorPrincipal;
                      if (!_validarPresupuestoCaja(cajaId, incremento)) {
                        return;
                      }

                      setDialogState(() => guardandoDialogo = true);
                      final bool refinanciado = await _ejecutarAccion(
                        () async {
                          final CreditoRegistro actualizado =
                              CreditoRegistro.fromJson(
                            await _apiClient.patchObject(
                              '/creditos/${credito.id}/refinanciar',
                              <String, dynamic>{
                                if (rutaId != null) 'rutaId': rutaId,
                                'monedaCodigo': credito.monedaCodigo,
                                'frecuenciaPagoId': frecuenciaId,
                                'fechaInicio': _fechaValor(fechaInicio),
                                'valorPrincipal': valorNuevo,
                                'porcentajeInteres': porcentajeInteres,
                                'plazoDias': plazoDias,
                                'omitirDomingos': omitirDomingos,
                                'cajaMenorId': cajaId,
                                if (observacionController.text
                                    .trim()
                                    .isNotEmpty)
                                  'observacion':
                                      observacionController.text.trim(),
                              },
                              queueOffline: true,
                            ),
                          );
                          _guardarCreditoLocal(actualizado);
                          _recargarEnSegundoPlano(
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
                        _mostrarMensaje('Credito refinanciado');
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

  Future<void> _abrirModificarCredito(CreditoRegistro credito) async {
    if (!_puedeModificarCreditos) {
      _mostrarMensaje('No tienes permiso para modificar creditos');
      return;
    }

    final Catalogos? catalogos = _catalogos;
    if (catalogos == null ||
        catalogos.frecuenciasPago.isEmpty ||
        catalogos.cajasMenoresActivas.isEmpty) {
      _mostrarMensaje('Necesitas catalogos y caja menor activa');
      return;
    }

    final List<CajaMenorCatalogo> cajasCompatibles =
        catalogos.cajasMenoresActivas
            .where(
              (CajaMenorCatalogo caja) =>
                  caja.monedaCodigo == credito.monedaCodigo,
            )
            .toList(growable: false);
    if (cajasCompatibles.isEmpty) {
      _mostrarMensaje('No hay caja menor activa para esa moneda');
      return;
    }

    final TextEditingController valorController = TextEditingController(
      text: _numero(credito.valorPrincipal),
    );
    final TextEditingController interesController = TextEditingController(
      text: _numero(credito.porcentajeInteres),
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
        _clientes.any((Cliente cliente) => cliente.id == credito.clienteId)
            ? _clientes
            : <Cliente>[
                Cliente(
                  id: credito.clienteId,
                  nombreCompleto: credito.cliente,
                  cedula: credito.cedula,
                  direccion: credito.direccion,
                  nombreComercial: credito.negocio,
                  estadoNombre: 'Activo',
                ),
                ..._clientes,
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
                content: _DialogContent(
                  maxWidth: 600,
                  child: _FormularioCredito(
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
                      if (guardandoDialogo || _guardando) {
                        return;
                      }

                      final String? clienteSeleccionado = clienteId;
                      final String? cajaId = cajaMenorId;
                      final int? frecuenciaId = frecuenciaPagoId;
                      if (clienteSeleccionado == null ||
                          cajaId == null ||
                          frecuenciaId == null) {
                        _mostrarMensaje('Faltan datos para modificar');
                        return;
                      }

                      final double valorPrincipal;
                      final double porcentajeInteres;
                      final int plazoDias;
                      try {
                        valorPrincipal = _leerMonto(valorController.text);
                        porcentajeInteres =
                            _leerPorcentaje(interesController.text);
                        plazoDias = _leerEnteroPositivo(plazoController.text);
                      } catch (error) {
                        _mostrarMensaje(_mensajeError(error));
                        return;
                      }

                      final bool cambiaCondicionesFinancieras =
                          frecuenciaId != credito.frecuenciaPago.id ||
                              _fechaValor(fechaInicio) !=
                                  _fechaValor(credito.fechaInicio) ||
                              valorPrincipal != credito.valorPrincipal ||
                              porcentajeInteres != credito.porcentajeInteres ||
                              plazoDias != credito.plazoDias ||
                              omitirDomingos != credito.omitirDomingos;
                      if (credito.totalAbonado > 0.009 &&
                          cambiaCondicionesFinancieras) {
                        _mostrarMensaje(
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
                        'fechaInicio': _fechaValor(fechaInicio),
                        'valorPrincipal': valorPrincipal,
                        'porcentajeInteres': porcentajeInteres,
                        'plazoDias': plazoDias,
                        'omitirDomingos': omitirDomingos,
                        'cajaMenorId': cajaId,
                        if (observacion.isNotEmpty) 'observacion': observacion,
                      };
                      final CreditoRegistro optimista =
                          _creditoOptimistaModificado(
                        credito: credito,
                        catalogos: catalogos,
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
                      _guardarCreditoLocal(optimista);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                        _mostrarMensaje('Credito modificado');
                      }

                      unawaited(() async {
                        try {
                          final CreditoRegistro respuesta =
                              CreditoRegistro.fromJson(
                            await _apiClient.patchObject(
                              '/creditos/${credito.id}',
                              payload,
                              queueOffline: true,
                            ),
                          );
                          _guardarCreditoLocal(respuesta);
                          _recargarEnSegundoPlano(
                            catalogos: rutaId == null,
                            presupuesto: true,
                            cobrosRuta: true,
                            creditos: true,
                            movimientosCaja: true,
                          );
                        } on OfflineMutationQueuedException catch (error) {
                          await _marcarAccionOfflinePendiente(error);
                        } catch (error) {
                          if (mounted) {
                            setState(() {
                              _error = _mensajeError(error);
                            });
                            _guardarCreditoLocal(credito);
                            _mostrarMensaje(_mensajeError(error));
                          }
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

  Future<void> _confirmarEliminarCredito(CreditoRegistro credito) async {
    if (!_puedeEliminarCreditos) {
      _mostrarMensaje('No tienes permiso para eliminar creditos');
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

    final List<CreditoRegistro> creditosAntes = _creditos;
    final bool eliminado = await _ejecutarAccion(() async {
      if (!mounted) {
        return;
      }
      setState(() {
        _creditos = _creditos
            .where((CreditoRegistro item) => item.id != credito.id)
            .toList(growable: false);
      });
      try {
        await _apiClient.deleteObject(
          '/creditos/${credito.id}',
          queueOffline: true,
        );
      } on OfflineMutationQueuedException catch (error) {
        await _marcarAccionOfflinePendiente(error);
      } catch (_) {
        if (mounted) {
          setState(() => _creditos = creditosAntes);
        }
        rethrow;
      }
      _recargarEnSegundoPlano(
        catalogos: false,
        presupuesto: true,
        cobrosRuta: true,
        creditos: true,
        movimientosCaja: true,
      );
    });

    if (eliminado) {
      _mostrarMensaje('Credito eliminado');
    }
  }

  Future<void> _abrirRegistrarPago(CobroRuta cobro) async {
    if (!_puedeAgregarCuota) {
      _mostrarMensaje('No tienes permiso para agregar cuota');
      return;
    }

    await _abrirRegistrarPagoMultiple(cobro);
  }

  // ignore: unused_element
  Future<void> _abrirRegistrarPagoAnterior(CobroRuta cobro) async {
    final List<MedioPago> mediosPago =
        _catalogos?.mediosPago ?? const <MedioPago>[];
    if (mediosPago.isEmpty) {
      _mostrarMensaje('No hay medios de pago registrados');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController montoController =
            TextEditingController(text: _numero(cobro.proximoSaldoCuota));
        final TextEditingController observacionController =
            TextEditingController();
        String medioPagoCodigo = mediosPago.first.codigo;
        bool guardandoPago = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Registrar pago'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _DatoResumen(label: 'Cliente', value: cobro.cliente),
                    _DatoResumen(
                      label: 'Cuota',
                      value:
                          '${cobro.proximaNumeroCuota ?? '-'} · ${_fechaEtiqueta(cobro.proximaFechaPago)}',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: montoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto pagado',
                        prefixIcon: Icon(Icons.payments_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SelectorMedioPagoBuscable(
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
                        labelText: 'Observación',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
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
                  onPressed: () async {
                    if (guardandoPago) {
                      return;
                    }

                    final String? cuotaId = cobro.proximaCuotaId;
                    if (cuotaId == null || _cuotasEnPago.contains(cuotaId)) {
                      _mostrarMensaje('Este pago ya se esta procesando');
                      return;
                    }

                    final double monto;
                    try {
                      monto = _leerMonto(montoController.text);
                    } catch (error) {
                      _mostrarMensaje(_mensajeError(error));
                      return;
                    }

                    if (monto > cobro.saldo) {
                      _mostrarMensaje('El pago supera el saldo del credito');
                      return;
                    }

                    final String? observacion =
                        observacionController.text.trim().isEmpty
                            ? null
                            : observacionController.text.trim();
                    setDialogState(() => guardandoPago = true);

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }

                    unawaited(
                      _registrarPagoRuta(
                        cuotaId: cuotaId,
                        monto: monto,
                        medioPagoCodigo: medioPagoCodigo,
                        observacion: observacion,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(guardandoPago ? 'Procesando' : 'Registrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _abrirRegistrarPagoMultiple(CobroRuta cobro) async {
    if (!_puedeAgregarCuota) {
      _mostrarMensaje('No tienes permiso para agregar cuota');
      return;
    }

    final List<MedioPago> mediosPago =
        _catalogos?.mediosPago ?? const <MedioPago>[];
    if (mediosPago.isEmpty) {
      _mostrarMensaje('No hay medios de pago registrados');
      return;
    }

    final List<CobroRuta> cobrosDisponibles = _cobrosRuta
        .where(
          (CobroRuta item) =>
              item.proximaCuotaId != null &&
              item.saldo > 0.009 &&
              (_rutaFiltroId == null || item.rutaId == _rutaFiltroId),
        )
        .toList(growable: false);
    final TextEditingController observacionController = TextEditingController();
    final List<_PagoRutaSeleccion> seleccionados = <_PagoRutaSeleccion>[
      _PagoRutaSeleccion(cobro),
    ];

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        String medioPagoCodigo = mediosPago.first.codigo;
        bool guardandoPago = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final Set<String> cuotasSeleccionadas = seleccionados
                .map((_PagoRutaSeleccion item) => item.cuotaId)
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
                      _SelectorCobroRutaBuscable(
                        cobros: cobrosDisponibles,
                        cuotasSeleccionadas: cuotasSeleccionadas,
                        enabled: !guardandoPago,
                        onSelected: (CobroRuta item) {
                          if (cuotasSeleccionadas
                              .contains(item.proximaCuotaId)) {
                            return;
                          }
                          seleccionados.add(_PagoRutaSeleccion(item));
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 14),
                      ...seleccionados.map(
                        (_PagoRutaSeleccion item) => Padding(
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
                                            [
                                              if ((item.cobro.cedula ?? '')
                                                  .isNotEmpty)
                                                'CC ${item.cobro.cedula!}',
                                              'Cuota ${item.cobro.proximaNumeroCuota ?? '-'}',
                                              _fechaEtiqueta(
                                                item.cobro.proximaFechaPago,
                                              ),
                                            ].join(' - '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      context.clay.subtleText,
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
                      _SelectorMedioPagoBuscable(
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
                      _mostrarMensaje('Agrega al menos un cliente');
                      return;
                    }

                    final String? observacion =
                        observacionController.text.trim().isEmpty
                            ? null
                            : observacionController.text.trim();
                    final List<_PagoRutaSolicitud> pagos =
                        <_PagoRutaSolicitud>[];

                    for (final _PagoRutaSeleccion item in seleccionados) {
                      final String? cuotaId = item.cuotaId;
                      if (cuotaId == null || _cuotasEnPago.contains(cuotaId)) {
                        _mostrarMensaje('Este pago ya se esta procesando');
                        return;
                      }

                      final double monto;
                      try {
                        monto = _leerMonto(item.montoController.text);
                      } catch (error) {
                        _mostrarMensaje(_mensajeError(error));
                        return;
                      }

                      if (monto > item.cobro.saldo) {
                        _mostrarMensaje(
                          'El pago de ${item.cobro.cliente} supera el saldo',
                        );
                        return;
                      }

                      pagos.add(
                        _PagoRutaSolicitud(
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

                    unawaited(_registrarPagosRuta(pagos));
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

  Future<void> _registrarPagoRuta({
    required String cuotaId,
    required double monto,
    required String medioPagoCodigo,
    String? observacion,
  }) async {
    if (!_puedeAgregarCuota) {
      _mostrarMensaje('No tienes permiso para agregar cuota');
      return;
    }

    if (_cuotasEnPago.contains(cuotaId)) {
      return;
    }

    if (mounted) {
      setState(() {
        _error = null;
        _cuotasEnPago.add(cuotaId);
      });
    }
    final List<CobroRuta> cobrosAntes = _cobrosRuta;
    final List<String> cobrosAplicados =
        _aplicarPagoRutaOptimista(cuotaId, monto);
    _mostrarMensaje('Pago aplicado en pantalla. Confirmando...');

    try {
      await _apiClient.postObject(
        '/pagos',
        <String, dynamic>{
          'creditoCuotaId': cuotaId,
          'montoPagado': monto,
          'medioPagoCodigo': medioPagoCodigo,
          if (observacion != null) 'observacion': observacion,
        },
        queueOffline: true,
      );
      _mostrarMensaje('Pago registrado');
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
      }
    } finally {
      if (mounted) {
        setState(() {
          _cuotasEnPago.remove(cuotaId);
        });
      }
    }
  }

  Future<void> _registrarPagosRuta(List<_PagoRutaSolicitud> pagos) async {
    if (!_puedeAgregarCuota) {
      _mostrarMensaje('No tienes permiso para agregar cuota');
      return;
    }

    final List<_PagoRutaSolicitud> pagosPendientes = pagos
        .where(
          (_PagoRutaSolicitud pago) => !_cuotasEnPago.contains(pago.cuotaId),
        )
        .toList(growable: false);
    if (pagosPendientes.isEmpty) {
      _mostrarMensaje('Este pago ya se esta procesando');
      return;
    }

    final List<String> cuotasIds = pagosPendientes
        .map((_PagoRutaSolicitud pago) => pago.cuotaId)
        .toList(growable: false);
    if (mounted) {
      setState(() {
        _error = null;
        _cuotasEnPago.addAll(cuotasIds);
      });
    }

    final List<CobroRuta> cobrosAntes = _cobrosRuta;
    final List<String> cobrosAplicados = <String>[];
    for (final _PagoRutaSolicitud pago in pagosPendientes) {
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
        pagosPendientes.map((_PagoRutaSolicitud pago) {
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

  void _recargarEnSegundoPlano({
    bool catalogos = false,
    bool presupuesto = true,
    bool clientes = false,
    bool cobrosRuta = true,
    bool creditos = true,
    bool movimientosCaja = true,
  }) {
    unawaited(() async {
      await _recargarDatos(
        catalogos: catalogos,
        presupuesto: presupuesto,
        clientes: clientes,
        cobrosRuta: cobrosRuta,
        creditos: creditos,
        movimientosCaja: movimientosCaja,
      );
    }());
  }

  Future<void> _exportarCobrosRuta() async {
    if (_exportando) {
      return;
    }

    setState(() {
      _exportando = true;
      _error = null;
    });
    _mostrarMensaje('Generando Excel...');

    try {
      final ExportacionExcel exportacion = ExportacionExcel.fromJson(
        await _apiClient.getObject(
          '/exportaciones/cobros-ruta',
          query: <String, String?>{
            'rutaId': _rutaFiltroId,
            'search': _buscarRutaController.text.trim(),
            'estadoCobro': _filtroEstadoRuta.wire,
          },
        ),
      );
      if (mounted) {
        setState(() => _exportando = false);
      }
      await _mostrarExportacionLista(exportacion);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _mensajeError(error));
        _mostrarMensaje(_mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _exportando = false);
      }
    }
  }

  Future<void> _exportarCreditos() async {
    if (_exportando) {
      return;
    }

    setState(() {
      _exportando = true;
      _error = null;
    });
    _mostrarMensaje('Generando Excel...');

    try {
      final ExportacionExcel exportacion = ExportacionExcel.fromJson(
        await _apiClient.getObject(
          '/exportaciones/creditos',
          query: <String, String?>{
            'search': _buscarCreditoController.text.trim(),
            'estado': _filtroCredito == _FiltroEstadoCredito.todos
                ? null
                : _filtroCredito.name,
            'fechaDesde': _fechaCreditoDesde == null
                ? null
                : _fechaValor(_fechaCreditoDesde!),
            'fechaHasta': _fechaCreditoHasta == null
                ? null
                : _fechaValor(_fechaCreditoHasta!),
          },
        ),
      );
      if (mounted) {
        setState(() => _exportando = false);
      }
      await _mostrarExportacionLista(exportacion);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _mensajeError(error));
        _mostrarMensaje(_mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _exportando = false);
      }
    }
  }

  Future<void> _exportarMovimientosCaja() async {
    if (_exportando) {
      return;
    }

    setState(() {
      _exportando = true;
      _error = null;
    });
    _mostrarMensaje('Generando Excel...');

    try {
      final ExportacionExcel exportacion = ExportacionExcel.fromJson(
        await _apiClient.getObject(
          '/exportaciones/caja-menor',
          query: <String, String?>{
            'cajaMenorId': _cajaMenorFiltroId,
            'search': _buscarCajaController.text.trim(),
            'tipo': _filtroMovimientoCaja == _FiltroMovimientoCaja.todos
                ? null
                : _filtroMovimientoCaja.name,
            'fechaDesde':
                _fechaCajaDesde == null ? null : _fechaValor(_fechaCajaDesde!),
            'fechaHasta':
                _fechaCajaHasta == null ? null : _fechaValor(_fechaCajaHasta!),
          },
        ),
      );
      if (mounted) {
        setState(() => _exportando = false);
      }
      await _mostrarExportacionLista(exportacion);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _mensajeError(error));
        _mostrarMensaje(_mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _exportando = false);
      }
    }
  }

  Future<void> _mostrarExportacionLista(ExportacionExcel exportacion) async {
    final String filas =
        exportacion.filas == 1 ? '1 fila' : '${exportacion.filas} filas';
    _mostrarMensaje('Excel exportado en R2: $filas');

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _VisorExportacionExcel(
          exportacion: exportacion,
          onDescargar: () async {
            final bool abierta = await abrirExportacionExcel(exportacion.url);
            if (!abierta && mounted) {
              _mostrarMensaje('No se pudo descargar el archivo exportado');
            }
          },
        );
      },
    );
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

  // ignore: unused_element
  Future<void> _abrirCrearCliente() async {
    final bool? creado = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController nombreController = TextEditingController();
        final TextEditingController cedulaController = TextEditingController();
        final TextEditingController direccionController =
            TextEditingController();
        final TextEditingController correoController = TextEditingController();
        final TextEditingController telefonoController =
            TextEditingController();
        LatLng? ubicacionCliente;

        return AlertDialog(
          title: const Text('Nuevo cliente'),
          content: _DialogContent(
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
                _ClienteUbicacionPicker(
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
                  _mostrarMensaje('El cliente necesita nombre completo');
                  return;
                }

                if (ubicacionCliente != null &&
                    direccionController.text.trim().isEmpty) {
                  _mostrarMensaje(_mensajeDireccionCasa);
                  return;
                }

                await _ejecutarAccion(() async {
                  final Cliente cliente = Cliente.fromJson(
                    await _apiClient.postObject(
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
                  _guardarClienteLocal(cliente);
                  _recargarEnSegundoPlano(
                    presupuesto: false,
                    clientes: true,
                    cobrosRuta: false,
                    movimientosCaja: false,
                  );
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
      _mostrarMensaje('Cliente creado');
    }
  }

  Future<void> _abrirModificarCliente(Cliente cliente) async {
    if (!(_usuarioSesion?.esAdministrador ?? false)) {
      _mostrarMensaje('Solo los administradores pueden modificar clientes');
      return;
    }

    final TextEditingController nombreController = TextEditingController(
      text: cliente.nombreCompleto,
    );
    final TextEditingController cedulaController = TextEditingController(
      text: cliente.cedula ?? '',
    );
    final TextEditingController negocioController = TextEditingController(
      text: cliente.nombreComercial ?? '',
    );
    final TextEditingController direccionController = TextEditingController(
      text: cliente.direccion ?? '',
    );
    final TextEditingController correoController = TextEditingController(
      text: cliente.correo ?? '',
    );
    final TextEditingController telefonoController = TextEditingController(
      text: cliente.telefono ?? '',
    );
    LatLng? ubicacionCliente = cliente.tieneUbicacion
        ? LatLng(cliente.latitude!, cliente.longitude!)
        : null;

    try {
      final bool? modificado = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          bool guardandoDialogo = false;

          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AlertDialog(
                title: const Text('Modificar cliente'),
                content: _DialogContent(
                  maxWidth: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nombreController,
                        enabled: !guardandoDialogo,
                        autofocus: true,
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
                        controller: negocioController,
                        enabled: !guardandoDialogo,
                        decoration: const InputDecoration(
                          labelText: 'Negocio',
                          prefixIcon: Icon(Icons.storefront_rounded),
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
                      _ClienteUbicacionPicker(
                        value: ubicacionCliente,
                        enabled: !guardandoDialogo,
                        onChanged: (LatLng? value) {
                          setDialogState(() => ubicacionCliente = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _DosColumnas(
                        left: TextField(
                          controller: correoController,
                          enabled: !guardandoDialogo,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            prefixIcon: Icon(Icons.mail_rounded),
                          ),
                        ),
                        right: TextField(
                          controller: telefonoController,
                          enabled: !guardandoDialogo,
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
                    onPressed: guardandoDialogo
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: guardandoDialogo
                        ? null
                        : () async {
                            if (nombreController.text.trim().length < 2) {
                              _mostrarMensaje(
                                'El cliente necesita nombre completo',
                              );
                              return;
                            }

                            if (ubicacionCliente != null &&
                                direccionController.text.trim().isEmpty) {
                              _mostrarMensaje(_mensajeDireccionCasa);
                              return;
                            }

                            setDialogState(() => guardandoDialogo = true);
                            final bool guardado =
                                await _ejecutarAccion(() async {
                              final Cliente actualizado = Cliente.fromJson(
                                await _apiClient.patchObject(
                                  '/clientes/${cliente.id}',
                                  <String, dynamic>{
                                    'nombreCompleto':
                                        nombreController.text.trim(),
                                    if (cedulaController.text.trim().isNotEmpty)
                                      'cedula': cedulaController.text.trim(),
                                    if (negocioController.text
                                        .trim()
                                        .isNotEmpty)
                                      'nombreComercial':
                                          negocioController.text.trim(),
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
                                    if (telefonoController.text
                                        .trim()
                                        .isNotEmpty)
                                      'telefono':
                                          telefonoController.text.trim(),
                                  },
                                  queueOffline: true,
                                ),
                              );
                              _guardarClienteLocal(actualizado);
                              _recargarEnSegundoPlano(
                                presupuesto: false,
                                clientes: true,
                                cobrosRuta: true,
                                creditos: true,
                                movimientosCaja: false,
                              );
                            });

                            if (!guardado) {
                              if (dialogContext.mounted) {
                                setDialogState(
                                  () => guardandoDialogo = false,
                                );
                              }
                              return;
                            }

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          },
                    icon: guardandoDialogo
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
            },
          );
        },
      );

      if (modificado == true) {
        _mostrarMensaje('Cliente modificado');
      }
    } finally {
      nombreController.dispose();
      cedulaController.dispose();
      negocioController.dispose();
      direccionController.dispose();
      correoController.dispose();
      telefonoController.dispose();
    }
  }

  Future<void> _confirmarEliminarCliente(Cliente cliente) async {
    if (!(_usuarioSesion?.esAdministrador ?? false)) {
      _mostrarMensaje('Solo los administradores pueden eliminar clientes');
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

    final List<Cliente> clientesAntes = _clientes;
    final String? clienteCreditoAntes = _clienteCreditoId;
    final Set<String> clientesCreditoAntes =
        Set<String>.of(_clientesCreditoIds);
    final bool eliminado = await _ejecutarAccion(() async {
      _eliminarClienteLocal(cliente.id);
      try {
        await _apiClient.deleteObject(
          '/clientes/${cliente.id}',
          queueOffline: true,
        );
      } on OfflineMutationQueuedException catch (error) {
        await _marcarAccionOfflinePendiente(error);
      } catch (_) {
        if (mounted) {
          setState(() {
            _clientes = clientesAntes;
            _clienteCreditoId = clienteCreditoAntes;
            _clientesCreditoIds
              ..clear()
              ..addAll(clientesCreditoAntes);
            _ajustarSelecciones();
          });
        }
        rethrow;
      }
      _recargarEnSegundoPlano(
        presupuesto: false,
        clientes: true,
        cobrosRuta: true,
        creditos: true,
        movimientosCaja: false,
      );
    });

    if (eliminado) {
      _mostrarMensaje('Cliente eliminado');
    }
  }

  Future<void> _abrirCrearClienteConCredito() async {
    final Catalogos? catalogos = _catalogos;
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
        final TextEditingController direccionController =
            TextEditingController();
        final TextEditingController correoController = TextEditingController();
        final TextEditingController telefonoController =
            TextEditingController();
        final TextEditingController valorController = TextEditingController();
        final TextEditingController interesController = TextEditingController(
          text: _interesCreditoPredeterminado,
        );
        final TextEditingController plazoController = TextEditingController(
          text: _plazoCreditoPredeterminado,
        );
        final TextEditingController observacionController =
            TextEditingController();

        final bool creditoDisponible = monedas.isNotEmpty &&
            frecuencias.isNotEmpty &&
            cajasMenores.isNotEmpty;
        bool agregarCredito = creditoDisponible;
        bool guardandoDialogo = false;
        String? clienteCreadoId;
        String? rutaId = _mantenerSeleccion(
          _rutaCreditoId,
          rutas.map((RutaCatalogo ruta) => ruta.id),
          permitirNulo: true,
        );
        String? monedaCodigo = _mantenerSeleccion(
          _monedaCreditoCodigo,
          monedas.map((Moneda moneda) => moneda.codigo),
        );
        int? frecuenciaPagoId = _mantenerSeleccionInt(
          _frecuenciaPagoId,
          frecuencias.map((FrecuenciaPago frecuencia) => frecuencia.id),
        );
        String? cajaMenorId = _mantenerSeleccion(
          _cajaMenorCreditoId,
          cajasMenores.map((CajaMenorCatalogo caja) => caja.id),
        );
        DateTime fechaInicio = DateTime.now();
        bool omitirDomingos = _omitirDomingos;
        LatLng? ubicacionCliente;
        bool obteniendoUbicacion = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo cliente'),
              content: _DialogContent(
                maxWidth: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nombreController,
                      enabled: !guardandoDialogo,
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
                        labelText: 'Cédula',
                        hintText: 'Número de identificación',
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: guardandoDialogo || obteniendoUbicacion
                            ? null
                            : () async {
                                setDialogState(
                                  () => obteniendoUbicacion = true,
                                );
                                try {
                                  final LatLng position =
                                      await const DeviceRouteLocationService()
                                          .currentPosition();
                                  if (dialogContext.mounted) {
                                    setDialogState(
                                      () {
                                        ubicacionCliente = position;
                                      },
                                    );
                                    _mostrarMensaje(_mensajeUbicacionCasa);
                                  }
                                } on RouteLocationException catch (error) {
                                  _mostrarMensaje(error.message);
                                } finally {
                                  if (dialogContext.mounted) {
                                    setDialogState(
                                      () => obteniendoUbicacion = false,
                                    );
                                  }
                                }
                              },
                        icon: obteniendoUbicacion
                            ? const SizedBox.square(
                                dimension: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                ubicacionCliente == null
                                    ? Icons.my_location_rounded
                                    : Icons.check_circle_rounded,
                              ),
                        label: Text(
                          ubicacionCliente == null
                              ? 'Guardar ubicación del cliente'
                              : 'Ubicación lista para el mapa',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ClienteUbicacionPicker(
                      value: ubicacionCliente,
                      enabled: !guardandoDialogo,
                      onChanged: (LatLng? value) {
                        setDialogState(() => ubicacionCliente = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _DosColumnas(
                      left: TextField(
                        controller: correoController,
                        enabled: !guardandoDialogo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo',
                          prefixIcon: Icon(Icons.mail_rounded),
                        ),
                      ),
                      right: TextField(
                        controller: telefonoController,
                        enabled: !guardandoDialogo,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefono',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: agregarCredito,
                      onChanged: !creditoDisponible || guardandoDialogo
                          ? null
                          : (bool value) {
                              setDialogState(() => agregarCredito = value);
                            },
                      title: const Text('Crear credito para este cliente'),
                      subtitle: creditoDisponible
                          ? null
                          : const Text(
                              'Faltan monedas, frecuencias o caja menor.',
                            ),
                      secondary: const Icon(Icons.add_business_rounded),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (agregarCredito) ...<Widget>[
                      const SizedBox(height: 8),
                      Divider(color: Theme.of(context).dividerColor),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Datos del credito',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CamposCreditoSinCliente(
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
                            _mostrarMensaje(
                              'El cliente necesita nombre completo',
                            );
                            return;
                          }

                          if (ubicacionCliente != null &&
                              direccionController.text.trim().isEmpty) {
                            _mostrarMensaje(_mensajeDireccionCasa);
                            return;
                          }

                          double? valorPrincipal;
                          double? porcentajeInteres;
                          int? plazoDias;
                          String? cajaMenorCreditoId;

                          if (agregarCredito) {
                            if (monedaCodigo == null ||
                                frecuenciaPagoId == null) {
                              _mostrarMensaje(
                                'Faltan datos reales para crear el credito',
                              );
                              return;
                            }

                            if (cajaMenorId == null) {
                              _mostrarMensaje(
                                'No se puede hacer credito sin caja menor',
                              );
                              return;
                            }
                            final String cajaMenorValidadaId = cajaMenorId!;

                            try {
                              valorPrincipal = _leerMonto(valorController.text);
                              porcentajeInteres =
                                  _leerPorcentaje(interesController.text);
                              plazoDias =
                                  _leerEnteroPositivo(plazoController.text);
                            } catch (error) {
                              _mostrarMensaje(_mensajeError(error));
                              return;
                            }

                            if (!_validarPresupuestoCaja(
                              cajaMenorValidadaId,
                              valorPrincipal,
                            )) {
                              return;
                            }

                            cajaMenorCreditoId = cajaMenorValidadaId;
                          }

                          setDialogState(() => guardandoDialogo = true);

                          final bool guardado = await _ejecutarAccion(() async {
                            String clienteId = clienteCreadoId ?? '';

                            if (clienteCreadoId == null) {
                              final Cliente cliente = Cliente.fromJson(
                                await _apiClient.postObject(
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
                                    if (telefonoController.text
                                        .trim()
                                        .isNotEmpty)
                                      'telefono':
                                          telefonoController.text.trim(),
                                  },
                                  queueOffline: true,
                                ),
                              );
                              clienteId = cliente.id;
                              clienteCreadoId = clienteId;
                              _guardarClienteLocal(cliente);
                            }

                            if (agregarCredito) {
                              await _apiClient.postObject(
                                '/creditos',
                                <String, dynamic>{
                                  'clienteId': clienteId,
                                  if (rutaId != null) 'rutaId': rutaId,
                                  'monedaCodigo': monedaCodigo,
                                  'frecuenciaPagoId': frecuenciaPagoId,
                                  'fechaInicio': _fechaValor(fechaInicio),
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
                            }

                            if (agregarCredito) {
                              _mostrarCuotasRegistradas();
                            }
                            _recargarEnSegundoPlano(
                              catalogos: agregarCredito && rutaId == null,
                              presupuesto: agregarCredito,
                              clientes: true,
                              cobrosRuta: agregarCredito,
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
      _mostrarMensaje(resultado);
    }
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

  Future<void> _abrirCrearCajaMenor() async {
    if (!_puedeCrearCajaMenor) {
      _mostrarMensaje('No tienes permiso para crear caja menor');
      return;
    }

    if (_catalogos == null) {
      _mostrarMensaje('Los datos todavia estan cargando. Intenta nuevamente.');
      return;
    }

    final bool esAdmin = _usuarioSesion?.esAdministrador ?? false;
    final List<UsuarioCatalogo> usuariosDisponibles =
        _catalogos?.usuarios ?? <UsuarioCatalogo>[];

    final CajaMenorCatalogo? cajaAbiertaPropia =
        _obtenerCajaMenorAbiertaDeUsuario(_usuarioSesion?.id);
    if (!esAdmin && cajaAbiertaPropia != null) {
      final String cierreStr = cajaAbiertaPropia.fechaCierre != null
          ? _fechaHoraEtiqueta(cajaAbiertaPropia.fechaCierre!)
          : 'horario configurado';
      _mostrarMensaje(
        'Ya tienes la caja menor "${cajaAbiertaPropia.nombre}" abierta hasta $cierreStr. Debes cerrarla antes de crear una nueva.',
      );
      return;
    }

    String? usuarioResponsableId = usuariosDisponibles
            .any((UsuarioCatalogo u) => u.id == _usuarioSesion?.id)
        ? _usuarioSesion?.id
        : (usuariosDisponibles.isNotEmpty
            ? usuariosDisponibles.first.id
            : null);

    final bool? creada = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController nombreController = TextEditingController(
          text: _nombreCajaMenorPorDefecto(),
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
                esAdmin ? usuarioResponsableId : _usuarioSesion?.id;
            final CajaMenorCatalogo? cajaAbiertaExistente =
                _obtenerCajaMenorAbiertaDeUsuario(usuarioDestinoId);
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
                          prefixIcon:
                              const Icon(Icons.person_outline_rounded),
                          value: usuarioResponsableId,
                          items: usuariosDisponibles.map((UsuarioCatalogo u) {
                            final CajaMenorCatalogo? cajaDelUsuario =
                                _obtenerCajaMenorAbiertaDeUsuario(u.id);
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
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withOpacity(0.6),
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
                                      'Tiene abierta la caja "${cajaAbiertaExistente.nombre}" hasta ${cajaAbiertaExistente.fechaCierre != null ? _fechaHoraEtiqueta(cajaAbiertaExistente.fechaCierre!) : 'su horario configurado'}. No se le puede abrir otra caja menor hasta que la anterior sea cerrada.',
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
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.savings_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Apertura',
                          prefixIcon: Icon(Icons.lock_clock_rounded),
                        ),
                        child: Text(_fechaHoraEtiqueta(fechaApertura)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final DateTime? selected =
                                await _seleccionarFechaHora(
                              context: context,
                              initialDateTime: fechaCierre,
                            );

                            if (selected != null) {
                              setDialogState(() => fechaCierre = selected);
                            }
                          },
                          icon: const Icon(Icons.event_available_rounded),
                          label: Text(
                            'Cierre ${_fechaHoraEtiqueta(fechaCierre)}',
                          ),
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
                          final String nombre = nombreController.text.trim();
                          if (nombre.length < 2) {
                            _mostrarMensaje(
                              'Escribe un nombre para la caja menor',
                            );
                            return;
                          }
                          final DateTime fechaAperturaActual = DateTime.now();
                          if (!fechaCierre.isAfter(fechaAperturaActual)) {
                            setDialogState(
                              () => fechaApertura = fechaAperturaActual,
                            );
                            _mostrarMensaje(
                              'El cierre debe ser posterior a la apertura',
                            );
                            return;
                          }

                          final bool guardada = await _ejecutarAccion(() async {
                            final CajaMenorCatalogo caja =
                                CajaMenorCatalogo.fromJson(
                              await _apiClient.postObject(
                                '/caja-menor',
                                <String, dynamic>{
                                  'nombre': nombre,
                                  if (esAdmin &&
                                      usuarioResponsableId != null &&
                                      usuarioResponsableId!.isNotEmpty)
                                    'responsableUsuarioId': usuarioResponsableId,
                                  'fechaApertura':
                                      _fechaHoraValor(fechaAperturaActual),
                                  'fechaCierre': _fechaHoraValor(fechaCierre),
                                },
                                queueOffline: true,
                              ),
                            );
                            _guardarCajaMenorLocal(caja);
                            _recargarEnSegundoPlano(
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
      _mostrarMensaje('Caja menor creada');
    }
  }

  Future<void> _confirmarCerrarCajaMenorSeleccionada() async {
    if (!_puedeCrearCajaMenor) {
      _mostrarMensaje('No tienes permiso para cerrar la caja menor');
      return;
    }

    final List<CajaMenorCatalogo> cajasActivas =
        _catalogos?.cajasMenoresActivas ?? <CajaMenorCatalogo>[];
    if (cajasActivas.isEmpty) {
      _mostrarMensaje('No hay ninguna caja menor abierta para cerrar');
      return;
    }

    CajaMenorCatalogo? cajaSeleccionada;
    if (_cajaMenorFiltroId != null) {
      cajaSeleccionada = cajasActivas.cast<CajaMenorCatalogo?>().firstWhere(
        (CajaMenorCatalogo? c) => c?.id == _cajaMenorFiltroId,
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
                            .map(_itemCajaMenor)
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
                          ? 'Estaba programada para cerrar el ${_fechaHoraEtiqueta(cajaActual!.fechaCierre!)}. Al cerrarla ahora, no se podrán registrar más movimientos ni préstamos con ella.'
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

    final bool cerrada = await _ejecutarAccion(() async {
      await _apiClient.postObject(
        '/caja-menor/$idCajaACerrar/cerrar',
        <String, dynamic>{},
      );
      if (_cajaMenorFiltroId == idCajaACerrar) {
        _cajaMenorFiltroId = null;
      }
      await _cargar();
    });

    if (cerrada) {
      _mostrarMensaje('Caja menor cerrada exitosamente');
    }
  }

  CobroDropdownItem<String> _itemCajaMenor(CajaMenorCatalogo caja) {
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

  CobroDropdownItem<String> _itemTipoMovimientoCaja(TipoMovimientoCaja tipo) {
    final bool esEntrada = tipo.naturaleza == 'E';
    final IconData iconData;
    switch (tipo.codigo) {
      case 'APERTURA':
        iconData = Icons.lock_open_rounded;
        break;
      case 'RECAUDO':
        iconData = Icons.payments_rounded;
        break;
      case 'GASTO':
        iconData = Icons.receipt_long_rounded;
        break;
      case 'DESEMBOLSO_CREDITO':
        iconData = Icons.account_balance_wallet_rounded;
        break;
      case 'AJUSTE_ENTRADA':
        iconData = Icons.add_circle_outline_rounded;
        break;
      case 'AJUSTE_SALIDA':
        iconData = Icons.remove_circle_outline_rounded;
        break;
      case 'CIERRE':
        iconData = Icons.lock_rounded;
        break;
      default:
        iconData = esEntrada
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;
    }

    return CobroDropdownItem<String>(
      value: tipo.codigo,
      label: tipo.nombre,
      subtitle: esEntrada ? 'Entrada de dinero' : 'Salida de dinero',
      icon: iconData,
      iconColor: esEntrada ? const Color(0xFF10B981) : const Color(0xFFEF4444),
    );
  }

  Future<void> _abrirMovimientoCaja() async {
    if (!_puedeRegistrarFlujoCaja) {
      _mostrarMensaje('No tienes permiso para registrar flujo en caja menor');
      return;
    }

    final Catalogos? catalogos = _catalogos;
    if (catalogos == null) {
      _mostrarMensaje('Los datos todavía están cargando. Intenta nuevamente.');
      return;
    }
    if (catalogos.cajasMenoresActivas.isEmpty) {
      _mostrarMensaje(
        'No hay ninguna caja menor abierta disponible para registrar movimientos.',
      );
      return;
    }
    if (catalogos.tiposMovimientoCaja.isEmpty) {
      _mostrarMensaje('No hay tipos de movimiento configurados');
      return;
    }

    final bool? creado = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController montoController = TextEditingController();
        final TextEditingController motivoController = TextEditingController();
        String cajaMenorId = catalogos.cajasMenoresActivas.any(
          (CajaMenorCatalogo caja) => caja.id == _cajaMenorFiltroId,
        )
            ? _cajaMenorFiltroId!
            : catalogos.cajasMenoresActivas.first.id;
        String tipoMovimientoCodigo =
            catalogos.tiposMovimientoCaja.first.codigo;
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
                            .map(_itemCajaMenor)
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
                            .map(_itemTipoMovimientoCaja)
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
                        label: Text(_fechaEtiqueta(fechaMovimiento)),
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
                      monto = _leerMonto(montoController.text);
                    } catch (error) {
                      _mostrarMensaje(_mensajeError(error));
                      return;
                    }

                    if (motivoController.text.trim().length < 2) {
                      _mostrarMensaje('El motivo es obligatorio');
                      return;
                    }

                    final TipoMovimientoCaja? tipo =
                        _tipoMovimientoCajaPorCodigo(tipoMovimientoCodigo);
                    final PresupuestoItem? presupuesto =
                        _presupuestoPorCaja(cajaMenorId);
                    if (tipo?.naturaleza.toUpperCase() == 'S' &&
                        presupuesto != null &&
                        monto > presupuesto.presupuesto) {
                      _mostrarMensaje(
                        'Caja menor insuficiente. El movimiento supera el dinero disponible.',
                      );
                      return;
                    }

                    final bool guardado = await _ejecutarAccion(() async {
                      final MovimientoCaja movimiento = MovimientoCaja.fromJson(
                        await _apiClient.postObject(
                          '/caja-menor/movimientos',
                          <String, dynamic>{
                            'cajaMenorId': cajaMenorId,
                            'tipoMovimientoCodigo': tipoMovimientoCodigo,
                            'fechaMovimiento': _fechaHoraValor(fechaMovimiento),
                            'monto': monto,
                            'motivo': motivoController.text.trim(),
                          },
                          queueOffline: true,
                        ),
                      );
                      _guardarMovimientoCajaLocal(movimiento);
                      _recargarEnSegundoPlano(
                        catalogos: false,
                        presupuesto: true,
                        clientes: false,
                        cobrosRuta: false,
                        movimientosCaja: true,
                      );
                    });

                    if (guardado && dialogContext.mounted) {
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

    if (creado == true) {
      _mostrarMensaje('Movimiento registrado');
    }
  }

  Future<void> _abrirEditarMovimientoCaja(MovimientoCaja movimiento) async {
    if (!_puedeModificarMovimientos) {
      _mostrarMensaje('No tienes permiso para modificar movimientos');
      return;
    }
    if (!movimiento.esEditablePorAdmin) {
      _mostrarMensaje('Este movimiento no se puede modificar desde caja menor');
      return;
    }
    if (movimiento.referenciaTabla == 'credito_desembolso' &&
        !_puedeModificarCreditos) {
      _mostrarMensaje('No tienes permiso para modificar creditos');
      return;
    }

    final Catalogos? catalogos = _catalogos;
    if (catalogos == null) {
      _mostrarMensaje(
        'Los datos todavia estan cargando. Intenta nuevamente.',
      );
      return;
    }
    if (!catalogos.cajasMenoresActivas.any(
      (CajaMenorCatalogo caja) => caja.id == movimiento.cajaMenorId,
    )) {
      _mostrarMensaje('La caja menor del movimiento no esta activa');
      return;
    }
    if (!catalogos.tiposMovimientoCaja.any(
      (TipoMovimientoCaja tipo) =>
          tipo.codigo == movimiento.tipoMovimiento.codigo,
    )) {
      _mostrarMensaje('El tipo del movimiento ya no esta disponible');
      return;
    }

    final bool? guardado = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController montoController = TextEditingController(
          text: _numero(movimiento.monto),
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
                            .map(_itemCajaMenor)
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
                            .map(_itemTipoMovimientoCaja)
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
                        label: Text(_fechaEtiqueta(fechaMovimiento)),
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
                      monto = _leerMonto(montoController.text);
                    } catch (error) {
                      _mostrarMensaje(_mensajeError(error));
                      return;
                    }

                    if (motivoController.text.trim().length < 2) {
                      _mostrarMensaje('El motivo es obligatorio');
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
                      'fechaMovimiento': _fechaHoraValor(fechaMovimiento),
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

                    _guardarMovimientoCajaLocal(optimista);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }

                    unawaited(() async {
                      try {
                        final MovimientoCaja respuesta =
                            MovimientoCaja.fromJson(
                          await _apiClient.patchObject(
                            '/caja-menor/movimientos/${movimiento.id}',
                            payload,
                            queueOffline: true,
                          ),
                        );
                        _guardarMovimientoCajaLocal(respuesta);
                        _recargarEnSegundoPlano(
                          catalogos: false,
                          presupuesto: true,
                          clientes: false,
                          cobrosRuta: true,
                          creditos: true,
                          movimientosCaja: true,
                        );
                      } on OfflineMutationQueuedException catch (error) {
                        await _marcarAccionOfflinePendiente(error);
                      } catch (error) {
                        if (mounted) {
                          setState(() {
                            _error = _mensajeError(error);
                          });
                          _guardarMovimientoCajaLocal(movimiento);
                          _mostrarMensaje(_mensajeError(error));
                        }
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
      _mostrarMensaje('Movimiento modificado');
    }
  }

  Future<void> _confirmarEliminarMovimientoCaja(
    MovimientoCaja movimiento,
  ) async {
    if (!_puedeEliminarMovimientos) {
      _mostrarMensaje('No tienes permiso para eliminar movimientos');
      return;
    }
    if (!movimiento.esEditablePorAdmin) {
      _mostrarMensaje('Este movimiento no se puede eliminar desde caja menor');
      return;
    }
    if (movimiento.referenciaTabla == 'credito_desembolso' &&
        !_puedeEliminarCreditos) {
      _mostrarMensaje('No tienes permiso para eliminar creditos');
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

    final List<MovimientoCaja> movimientosAntes = _movimientosCaja;
    final bool eliminado = await _ejecutarAccion(() async {
      if (!mounted) {
        return;
      }
      setState(() {
        _movimientosCaja = _movimientosCaja
            .where((MovimientoCaja item) => item.id != movimiento.id)
            .toList(growable: false);
      });
      try {
        await _apiClient.deleteObject(
          '/caja-menor/movimientos/${movimiento.id}',
          queueOffline: true,
        );
      } on OfflineMutationQueuedException catch (error) {
        await _marcarAccionOfflinePendiente(error);
      } catch (_) {
        if (mounted) {
          setState(() => _movimientosCaja = movimientosAntes);
        }
        rethrow;
      }
      _recargarEnSegundoPlano(
        catalogos: false,
        presupuesto: true,
        clientes: false,
        cobrosRuta: true,
        creditos: true,
        movimientosCaja: true,
      );
    });

    if (eliminado) {
      _mostrarMensaje('Movimiento eliminado');
    }
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
      if (!mounted || _usuarioSesion == null) {
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
      if (!mounted || _usuarioSesion == null) {
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
        _usuarioSesion == null) {
      return;
    }

    unawaited(_cargarMasCreditos());
  }

  void _cargarMasMovimientosCajaSiHaceFalta() {
    if (!_hayMasMovimientosCaja ||
        _cargandoMovimientosCaja ||
        _cargandoMasMovimientosCaja ||
        _usuarioSesion == null) {
      return;
    }

    unawaited(_cargarMasMovimientosCaja());
  }

  Future<void> _cargarMasCreditos() async {
    setState(() => _cargandoMasCreditos = true);
    final String queryKey = _queryCreditos(offset: 0).toString();

    try {
      final _PaginaDatos<CreditoRegistro> pagina =
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
      final _PaginaDatos<MovimientoCaja> pagina =
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
        return _AvisoFlotante(
          message: message,
          tipo: _tipoMensaje(message),
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

enum _TipoMensaje { exito, advertencia, error, info }

_TipoMensaje _tipoMensaje(String message) {
  final String normalizado = message.toLowerCase();

  if (normalizado.contains('error') ||
      normalizado.contains('no se pudo') ||
      normalizado.contains('ya existe') ||
      normalizado.contains('ya esta registrad') ||
      normalizado.contains('ya está registrad') ||
      normalizado.contains('duplicad') ||
      normalizado.contains('no tienes acceso')) {
    return _TipoMensaje.error;
  }

  if (normalizado.contains('no se puede') ||
      normalizado.contains('insuficiente') ||
      normalizado.contains('faltan') ||
      normalizado.contains('necesitas') ||
      normalizado.contains('primero') ||
      normalizado.contains('obligatorio') ||
      normalizado.contains('supera') ||
      normalizado.contains('intenta') ||
      normalizado.contains('no hay')) {
    return _TipoMensaje.advertencia;
  }

  if (normalizado.contains('cread') ||
      normalizado.contains('registrad') ||
      normalizado.contains('aplicad') ||
      normalizado.contains('complet')) {
    return _TipoMensaje.exito;
  }

  return _TipoMensaje.info;
}

class _AvisoFlotante extends StatefulWidget {
  const _AvisoFlotante({
    required this.message,
    required this.tipo,
    required this.onDismissed,
  });

  final String message;
  final _TipoMensaje tipo;
  final VoidCallback onDismissed;

  @override
  State<_AvisoFlotante> createState() => _AvisoFlotanteState();
}

class _AvisoFlotanteState extends State<_AvisoFlotante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _AvisoEstilo estilo = _AvisoEstilo.desde(
      context,
      widget.tipo,
      widget.message,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (BuildContext context, Widget? child) {
                return Opacity(
                  opacity: _animation.value,
                  child: Transform.translate(
                    offset: Offset(0, -14 * (1 - _animation.value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: estilo.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: estilo.borderColor),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: estilo.shadowColor,
                          blurRadius: 28,
                          spreadRadius: -8,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: estilo.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              estilo.icon,
                              color: estilo.accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  estilo.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: estilo.titleColor,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: estilo.messageColor,
                                        fontWeight: FontWeight.w600,
                                        height: 1.22,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Cerrar',
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              onPressed: widget.onDismissed,
                              icon: Icon(
                                Icons.close_rounded,
                                color: estilo.messageColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvisoEstilo {
  const _AvisoEstilo({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.titleColor,
    required this.messageColor,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final Color titleColor;
  final Color messageColor;

  factory _AvisoEstilo.desde(
    BuildContext context,
    _TipoMensaje tipo,
    String message,
  ) {
    final ClayTokens clay = context.clay;
    final String normalizado = message.toLowerCase();
    final Color base = clay.isDark ? clay.surfaceHigh : Colors.white;
    final Color accent = switch (tipo) {
      _TipoMensaje.exito => CobroAppTheme.success,
      _TipoMensaje.advertencia => CobroAppTheme.warning,
      _TipoMensaje.error => CobroAppTheme.danger,
      _TipoMensaje.info => CobroAppTheme.primary,
    };
    final String title = switch (tipo) {
      _TipoMensaje.exito => 'Listo',
      _TipoMensaje.advertencia => normalizado.contains('caja')
          ? 'Revisa la caja menor'
          : 'Revisa la informacion',
      _TipoMensaje.error => 'No se pudo completar',
      _TipoMensaje.info => 'Aviso',
    };
    final IconData icon = switch (tipo) {
      _TipoMensaje.exito => Icons.check_circle_rounded,
      _TipoMensaje.advertencia => Icons.account_balance_wallet_rounded,
      _TipoMensaje.error => Icons.error_rounded,
      _TipoMensaje.info => Icons.info_rounded,
    };

    return _AvisoEstilo(
      title: title,
      icon: icon,
      accentColor: accent,
      backgroundColor: Color.alphaBlend(
        accent.withValues(alpha: clay.isDark ? 0.08 : 0.04),
        base,
      ),
      borderColor: accent.withValues(alpha: clay.isDark ? 0.34 : 0.22),
      shadowColor: clay.shadow.withValues(alpha: clay.isDark ? 0.62 : 0.22),
      titleColor: clay.text,
      messageColor: clay.subtleText,
    );
  }
}

class _MarcaAplicacion extends StatelessWidget {
  const _MarcaAplicacion();

  @override
  Widget build(BuildContext context) {
    final TextStyle? baseStyle = Theme.of(context).textTheme.titleMedium;
    const Widget logo = ClayIcon(
      icon: Icons.monetization_on_rounded,
      size: 42,
      iconSize: 24,
      radius: 13,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }

        if (constraints.maxWidth < 132) {
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: math.min(42, constraints.maxWidth),
              height: 42,
              child: const FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: logo,
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            logo,
            const SizedBox(width: 11),
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: baseStyle?.copyWith(
                    color: context.clay.text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                  children: const <InlineSpan>[
                    TextSpan(text: 'App'),
                    TextSpan(
                      text: 'Créditos',
                      style: TextStyle(color: CobroAppTheme.primary),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
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

class _PaginaDatos<T> {
  const _PaginaDatos({
    required this.items,
    required this.hasMore,
    this.nextOffset,
  });

  factory _PaginaDatos.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemBuilder,
  ) {
    return _PaginaDatos<T>(
      items: _lista(json['items']).map(itemBuilder).toList(growable: false),
      hasMore: json['hasMore'] as bool? ?? false,
      nextOffset: _enteroNullableJson(json['nextOffset']),
    );
  }

  final List<T> items;
  final bool hasMore;
  final int? nextOffset;
}

class _ConteoCreditosInicio {
  const _ConteoCreditosInicio({
    required this.total,
    required this.activos,
    required this.inactivos,
  });

  factory _ConteoCreditosInicio.fromJson(Map<String, dynamic> json) {
    return _ConteoCreditosInicio(
      total: _enteroJson(json['total']),
      activos: _enteroJson(json['activos']),
      inactivos: _enteroJson(json['inactivos']),
    );
  }

  const _ConteoCreditosInicio.vacio()
      : total = 0,
        activos = 0,
        inactivos = 0;

  final int total;
  final int activos;
  final int inactivos;
}

class _PaginaInicioPresupuesto extends StatelessWidget {
  const _PaginaInicioPresupuesto({
    required this.totales,
    required this.clientesActivos,
    required this.cartera,
    required this.conteoCreditos,
    required this.creditosAtrasados,
    required this.fechaInicio,
    required this.fechaFin,
    required this.items,
    required this.cajasMenores,
    required this.buscarCajaController,
    required this.onCajaChanged,
    required this.fechaHoyActiva,
    required this.todosLosDiasActivo,
    required this.onFechaHoy,
    required this.onTodosLosDias,
    required this.onFechaDesde,
    required this.onFechaHasta,
    required this.onLimpiarFiltros,
    required this.onVerCreditos,
    required this.onVerActivos,
    required this.onVerInactivos,
    required this.onVerAtrasados,
    required this.onRefresh,
    required this.hayFiltros,
    this.cajaMenorId,
    this.fechaDesde,
    this.fechaHasta,
    this.error,
  });

  final PresupuestoTotales totales;
  final int clientesActivos;
  final double cartera;
  final _ConteoCreditosInicio conteoCreditos;
  final int creditosAtrasados;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final List<PresupuestoItem> items;
  final List<CajaMenorCatalogo> cajasMenores;
  final String? cajaMenorId;
  final TextEditingController buscarCajaController;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final bool hayFiltros;
  final ValueChanged<String?> onCajaChanged;
  final bool fechaHoyActiva;
  final bool todosLosDiasActivo;
  final VoidCallback onFechaHoy;
  final VoidCallback onTodosLosDias;
  final VoidCallback onFechaDesde;
  final VoidCallback onFechaHasta;
  final VoidCallback onLimpiarFiltros;
  final VoidCallback onVerCreditos;
  final VoidCallback onVerActivos;
  final VoidCallback onVerInactivos;
  final VoidCallback onVerAtrasados;
  final Future<void> Function() onRefresh;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double horizontal = constraints.maxWidth < 520 ? 16 : 28;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: _EntradaAnimada(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _EncabezadoInicioPresupuesto(
                              fechaInicio: fechaInicio,
                              fechaFin: fechaFin,
                            ),
                            if (error != null) ...<Widget>[
                              const SizedBox(height: 16),
                              _ErrorBanner(message: error!),
                            ],
                            const SizedBox(height: 22),
                            const _TituloSeccionPresupuesto(
                              icono: Icons.query_stats_rounded,
                              titulo: 'Panorama financiero',
                              subtitulo:
                                  'Flujo, composicion y distribucion en tiempo real',
                            ),
                            const SizedBox(height: 12),
                            _GraficasInicio(totales: totales),
                            const SizedBox(height: 28),
                            _FiltrosInicioPresupuesto(
                              cajasMenores: cajasMenores,
                              cajaMenorId: cajaMenorId,
                              buscarCajaController: buscarCajaController,
                              fechaDesde: fechaDesde,
                              fechaHasta: fechaHasta,
                              hayFiltros: hayFiltros,
                              onCajaChanged: onCajaChanged,
                              fechaHoyActiva: fechaHoyActiva,
                              todosLosDiasActivo: todosLosDiasActivo,
                              onFechaHoy: onFechaHoy,
                              onTodosLosDias: onTodosLosDias,
                              onFechaDesde: onFechaDesde,
                              onFechaHasta: onFechaHasta,
                              onLimpiarFiltros: onLimpiarFiltros,
                            ),
                            const SizedBox(height: 22),
                            _ResumenCreditosInicio(
                              montoCreditos: totales.creditos,
                              activos: conteoCreditos.activos,
                              inactivos: conteoCreditos.inactivos,
                              atrasados: creditosAtrasados,
                              onVerCreditos: onVerCreditos,
                              onVerActivos: onVerActivos,
                              onVerInactivos: onVerInactivos,
                              onVerAtrasados: onVerAtrasados,
                            ),
                            const SizedBox(height: 28),
                            _TarjetaTotalPresupuesto(
                              total: totales.presupuesto,
                            ),
                            const SizedBox(height: 28),
                            const _TituloSeccionPresupuesto(
                              icono: Icons.donut_large_rounded,
                              titulo: 'Composición del presupuesto',
                              subtitulo: 'Balance actual de ingresos y salidas',
                            ),
                            const SizedBox(height: 12),
                            _ComposicionPresupuesto(totales: totales),
                            const SizedBox(height: 28),
                            const _TituloSeccionPresupuesto(
                              icono: Icons.insights_rounded,
                              titulo: 'Actividad',
                              subtitulo: 'Cartera y clientes vinculados',
                            ),
                            const SizedBox(height: 12),
                            _ActividadPresupuesto(
                              clientesActivos: clientesActivos,
                              cartera: cartera,
                            ),
                            const SizedBox(height: 28),
                            const _TituloSeccionPresupuesto(
                              icono: Icons.account_balance_wallet_rounded,
                              titulo: 'Presupuesto por caja',
                              subtitulo: 'Detalle de la caja seleccionada',
                            ),
                            const SizedBox(height: 12),
                            if (items.isEmpty)
                              const _EstadoVacio(
                                icono: Icons.account_balance_wallet_outlined,
                                titulo: 'Sin datos para la caja',
                                mensaje:
                                    'Ajusta la caja o el rango de fechas para ver presupuesto.',
                              )
                            else
                              ...items.map(
                                (PresupuestoItem item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _PresupuestoItem(item: item),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FiltrosInicioPresupuesto extends StatelessWidget {
  const _FiltrosInicioPresupuesto({
    required this.cajasMenores,
    required this.buscarCajaController,
    required this.hayFiltros,
    required this.onCajaChanged,
    required this.fechaHoyActiva,
    required this.todosLosDiasActivo,
    required this.onFechaHoy,
    required this.onTodosLosDias,
    required this.onFechaDesde,
    required this.onFechaHasta,
    required this.onLimpiarFiltros,
    this.cajaMenorId,
    this.fechaDesde,
    this.fechaHasta,
  });

  final List<CajaMenorCatalogo> cajasMenores;
  final String? cajaMenorId;
  final TextEditingController buscarCajaController;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final bool hayFiltros;
  final ValueChanged<String?> onCajaChanged;
  final bool fechaHoyActiva;
  final bool todosLosDiasActivo;
  final VoidCallback onFechaHoy;
  final VoidCallback onTodosLosDias;
  final VoidCallback onFechaDesde;
  final VoidCallback onFechaHasta;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    final bool cajaSeleccionadaVisible = cajasMenores.any(
      (CajaMenorCatalogo caja) => caja.id == cajaMenorId,
    );
    final String? value = cajaMenorId == _HomePageState._todasLasCajasFiltro
        ? _HomePageState._todasLasCajasFiltro
        : cajaSeleccionadaVisible
            ? cajaMenorId
            : null;

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 250,
            child: TextField(
              controller: buscarCajaController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Buscar caja',
              ),
            ),
          ),
          SizedBox(
            width: 270,
            child: CobroDropdownField<String?>(
              key: ValueKey<String?>('inicio-caja-$value'),
              labelText: 'Caja',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              value: value,
              hintText: 'Selecciona una caja',
              menuWidth: 270,
              items: <CobroDropdownItem<String?>>[
                const CobroDropdownItem<String?>(
                  value: _HomePageState._todasLasCajasFiltro,
                  label: 'Todas las cajas',
                  subtitle: 'Ver movimientos globales',
                  icon: Icons.all_inbox_rounded,
                  iconColor: Color(0xFF6366F1),
                ),
                ...cajasMenores.map(
                  (CajaMenorCatalogo caja) => CobroDropdownItem<String?>(
                    value: caja.id,
                    label: caja.nombre,
                    subtitle: 'Moneda: ${caja.monedaCodigo}',
                    icon: Icons.savings_rounded,
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
              ],
              onChanged: onCajaChanged,
            ),
          ),
          OutlinedButton.icon(
            onPressed: fechaHoyActiva ? null : onFechaHoy,
            icon: const Icon(Icons.today_rounded),
            label: const Text('Hoy'),
          ),
          OutlinedButton.icon(
            onPressed: todosLosDiasActivo ? null : onTodosLosDias,
            icon: const Icon(Icons.all_inclusive_rounded),
            label: const Text('Todos los dias'),
          ),
          OutlinedButton.icon(
            onPressed: onFechaDesde,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(
              fechaDesde == null
                  ? 'Desde'
                  : 'Desde ${_fechaEtiqueta(fechaDesde)}',
            ),
          ),
          OutlinedButton.icon(
            onPressed: onFechaHasta,
            icon: const Icon(Icons.event_available_rounded),
            label: Text(
              fechaHasta == null
                  ? 'Hasta'
                  : 'Hasta ${_fechaEtiqueta(fechaHasta)}',
            ),
          ),
          if (hayFiltros)
            Tooltip(
              message: 'Limpiar filtros',
              child: IconButton.outlined(
                onPressed: onLimpiarFiltros,
                icon: const Icon(Icons.filter_alt_off_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResumenCreditosInicio extends StatelessWidget {
  const _ResumenCreditosInicio({
    required this.montoCreditos,
    required this.activos,
    required this.inactivos,
    required this.atrasados,
    required this.onVerCreditos,
    required this.onVerActivos,
    required this.onVerInactivos,
    required this.onVerAtrasados,
  });

  final double montoCreditos;
  final int activos;
  final int inactivos;
  final int atrasados;
  final VoidCallback onVerCreditos;
  final VoidCallback onVerActivos;
  final VoidCallback onVerInactivos;
  final VoidCallback onVerAtrasados;

  @override
  Widget build(BuildContext context) {
    final List<_AccesoCreditoInicio> accesos = <_AccesoCreditoInicio>[
      _AccesoCreditoInicio(
        icono: Icons.receipt_long_rounded,
        etiqueta: 'Dinero en creditos',
        valor: _dinero(montoCreditos),
        color: CobroAppTheme.primary,
        onTap: onVerCreditos,
      ),
      _AccesoCreditoInicio(
        icono: Icons.check_circle_rounded,
        etiqueta: 'Activos',
        valor: activos.toString(),
        color: CobroAppTheme.success,
        onTap: onVerActivos,
      ),
      _AccesoCreditoInicio(
        icono: Icons.pause_circle_filled_rounded,
        etiqueta: 'Inactivos',
        valor: inactivos.toString(),
        color: const Color(0xFF64748B),
        onTap: onVerInactivos,
      ),
      _AccesoCreditoInicio(
        icono: Icons.warning_amber_rounded,
        etiqueta: 'Atrasados',
        valor: atrasados.toString(),
        color: CobroAppTheme.danger,
        onTap: onVerAtrasados,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _TituloSeccionPresupuesto(
          icono: Icons.fact_check_rounded,
          titulo: 'Creditos',
          subtitulo: 'Estado actual y accesos directos',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columnas = constraints.maxWidth < 620 ? 2 : 4;
            const double separacion = 12;
            final double ancho =
                (constraints.maxWidth - (separacion * (columnas - 1))) /
                    columnas;

            return Wrap(
              spacing: separacion,
              runSpacing: separacion,
              children: accesos
                  .map(
                    (_AccesoCreditoInicio acceso) => SizedBox(
                      width: ancho,
                      child: _TarjetaAccesoCreditoInicio(acceso: acceso),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _AccesoCreditoInicio {
  const _AccesoCreditoInicio({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;
  final VoidCallback onTap;
}

class _TarjetaAccesoCreditoInicio extends StatelessWidget {
  const _TarjetaAccesoCreditoInicio({required this.acceso});

  final _AccesoCreditoInicio acceso;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver ${acceso.etiqueta}',
      child: ClaySurface(
        constraints: const BoxConstraints(minHeight: 126),
        radius: 18,
        padding: EdgeInsets.zero,
        borderColor: acceso.color.withValues(alpha: 0.24),
        color: acceso.color.withValues(alpha: 0.06),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: acceso.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ClayIcon(
                        icon: acceso.icono,
                        color: acceso.color,
                        backgroundColor: acceso.color.withValues(alpha: 0.12),
                        size: 42,
                        iconSize: 21,
                        radius: 13,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: acceso.color,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      acceso.valor,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    acceso.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.clay.subtleText,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
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

class _EntradaAnimada extends StatelessWidget {
  const _EntradaAnimada({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool desactivarAnimaciones = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: desactivarAnimaciones
          ? Duration.zero
          : const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _EncabezadoInicioPresupuesto extends StatelessWidget {
  const _EncabezadoInicioPresupuesto({
    required this.fechaInicio,
    required this.fechaFin,
  });

  final DateTime fechaInicio;
  final DateTime fechaFin;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final TextStyle? breadcrumbStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(
              color: CobroAppTheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Gestión de Presupuesto',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: clay.text,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            Text('Inicio', style: breadcrumbStyle),
            Text('•', style: TextStyle(color: clay.subtleText)),
            Text('Informe', style: breadcrumbStyle),
            Text('•', style: TextStyle(color: clay.subtleText)),
            Text('Presupuesto', style: breadcrumbStyle),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Desde el último movimiento de caja menor',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clay.subtleText,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: <Widget>[
            Text(
              _fechaEtiqueta(fechaInicio).toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: CobroAppTheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: clay.subtleText,
            ),
            Text(
              _fechaEtiqueta(fechaFin).toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: CobroAppTheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaTotalPresupuesto extends StatelessWidget {
  const _TarjetaTotalPresupuesto({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final bool desactivarAnimaciones = MediaQuery.of(context).disableAnimations;
    return ClaySurface(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 194),
      radius: 24,
      padding: const EdgeInsets.all(24),
      borderColor: Colors.white.withValues(alpha: 0.3),
      clipBehavior: Clip.hardEdge,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF45A3FF),
          Color(0xFF1683F3),
          Color(0xFF0565D8),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -8,
            bottom: -36,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 172,
              color: Colors.white.withValues(alpha: 0.075),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'TOTAL PRESUPUESTO',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: total),
                    duration: desactivarAnimaciones
                        ? Duration.zero
                        : const Duration(milliseconds: 850),
                    curve: Curves.easeOutCubic,
                    builder: (
                      BuildContext context,
                      double value,
                      Widget? child,
                    ) {
                      return Text(
                        _dinero(value),
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Caja menor + Recaudado - Créditos - Gastos',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TituloSeccionPresupuesto extends StatelessWidget {
  const _TituloSeccionPresupuesto({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icono, color: CobroAppTheme.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.clay.subtleText,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComposicionPresupuesto extends StatelessWidget {
  const _ComposicionPresupuesto({required this.totales});

  final PresupuestoTotales totales;

  @override
  Widget build(BuildContext context) {
    final List<_DatoPresupuesto> datos = <_DatoPresupuesto>[
      _DatoPresupuesto(
        icono: Icons.savings_rounded,
        etiqueta: 'Caja menor',
        valor: _dinero(totales.cajaMenor),
        color: CobroAppTheme.success,
      ),
      _DatoPresupuesto(
        icono: Icons.payments_rounded,
        etiqueta: 'Recaudado',
        valor: _dinero(totales.recaudado),
        color: CobroAppTheme.violet,
      ),
      _DatoPresupuesto(
        icono: Icons.receipt_long_rounded,
        etiqueta: 'Gastos',
        valor: _dinero(totales.gastos),
        color: CobroAppTheme.warning,
      ),
      _DatoPresupuesto(
        icono: Icons.trending_down_rounded,
        etiqueta: 'Dinero en creditos',
        valor: _dinero(totales.creditos),
        color: CobroAppTheme.danger,
      ),
      _DatoPresupuesto(
        icono: Icons.currency_exchange_rounded,
        etiqueta: 'Refinanciados',
        valor: _dinero(totales.valorRefinanciado),
        detalle: _textoCreditos(totales.creditosRefinanciados),
        color: const Color(0xFF0E7490),
      ),
    ];

    return ClaySurface(
      width: double.infinity,
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 650) {
            return Column(
              children: <Widget>[
                for (int index = 0; index < datos.length; index++) ...<Widget>[
                  _LineaDatoPresupuesto(dato: datos[index]),
                  if (index < datos.length - 1) const Divider(height: 22),
                ],
              ],
            );
          }

          return Column(
            children: <Widget>[
              IntrinsicHeight(
                child: Row(
                  children: <Widget>[
                    Expanded(child: _LineaDatoPresupuesto(dato: datos[0])),
                    const VerticalDivider(width: 32),
                    Expanded(child: _LineaDatoPresupuesto(dato: datos[1])),
                  ],
                ),
              ),
              const Divider(height: 28),
              IntrinsicHeight(
                child: Row(
                  children: <Widget>[
                    Expanded(child: _LineaDatoPresupuesto(dato: datos[2])),
                    const VerticalDivider(width: 32),
                    Expanded(child: _LineaDatoPresupuesto(dato: datos[3])),
                  ],
                ),
              ),
              const Divider(height: 28),
              _LineaDatoPresupuesto(dato: datos[4]),
            ],
          );
        },
      ),
    );
  }
}

class _LineaDatoPresupuesto extends StatelessWidget {
  const _LineaDatoPresupuesto({required this.dato});

  final _DatoPresupuesto dato;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ClayIcon(
          icon: dato.icono,
          color: dato.color,
          backgroundColor: dato.color.withValues(alpha: 0.12),
          size: 46,
          iconSize: 22,
          radius: 14,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                dato.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.clay.subtleText,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  dato.valor,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
              ),
              if (dato.detalle != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  dato.detalle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActividadPresupuesto extends StatelessWidget {
  const _ActividadPresupuesto({
    required this.clientesActivos,
    required this.cartera,
  });

  final int clientesActivos;
  final double cartera;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tarjetas = <Widget>[
      _TarjetaActividadPresupuesto(
        icono: Icons.groups_rounded,
        etiqueta: 'Clientes con credito',
        valor: '$clientesActivos',
        color: const Color(0xFF0E7490),
      ),
      _TarjetaActividadPresupuesto(
        icono: Icons.request_quote_rounded,
        etiqueta: 'Cartera activa',
        valor: _dinero(cartera),
        color: CobroAppTheme.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: <Widget>[
              tarjetas[0],
              const SizedBox(height: 12),
              tarjetas[1],
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: tarjetas[0]),
            const SizedBox(width: 12),
            Expanded(child: tarjetas[1]),
          ],
        );
      },
    );
  }
}

class _TarjetaActividadPresupuesto extends StatelessWidget {
  const _TarjetaActividadPresupuesto({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      constraints: const BoxConstraints(minHeight: 108),
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          ClayIcon(
            icon: icono,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
            size: 48,
            iconSize: 23,
            radius: 15,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    valor,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatoPresupuesto {
  const _DatoPresupuesto({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
    this.detalle,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;
  final String? detalle;
}

class _Pagina extends StatelessWidget {
  const _Pagina({
    required this.titulo,
    required this.subtitulo,
    required this.children,
    required this.onRefresh,
    this.error,
    this.acciones = const <Widget>[],
    this.onNearEnd,
  });

  final String titulo;
  final String subtitulo;
  final List<Widget> children;
  final Future<void> Function() onRefresh;
  final String? error;
  final List<Widget> acciones;
  final VoidCallback? onNearEnd;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double horizontal = constraints.maxWidth < 520 ? 16 : 28;
          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              final ScrollMetrics metrics = notification.metrics;
              if (metrics.axis == Axis.vertical &&
                  metrics.maxScrollExtent - metrics.pixels < 720) {
                onNearEnd?.call();
              }
              return false;
            },
            child: CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 32),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _Encabezado(
                              titulo: titulo,
                              subtitulo: subtitulo,
                              acciones: acciones,
                            ),
                            if (error != null) ...<Widget>[
                              const SizedBox(height: 14),
                              _ErrorBanner(message: error!),
                            ],
                            const SizedBox(height: 20),
                            ...children,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.titulo,
    required this.subtitulo,
    required this.acciones,
  });

  final String titulo;
  final String subtitulo;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final Widget texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: clay.text,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clay.subtleText,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );

    if (acciones.isEmpty) {
      return texto;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compacto = constraints.maxWidth < 560;
        final Widget accionesWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: acciones,
        );

        if (compacto) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              texto,
              const SizedBox(height: 12),
              accionesWrap,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: texto),
            const SizedBox(width: 12),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: accionesWrap,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 12,
      padding: const EdgeInsets.all(14),
      color: context.clay.warningSurface,
      borderColor: context.clay.warningBorder,
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: CobroAppTheme.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _PresupuestoItem extends StatelessWidget {
  const _PresupuestoItem({required this.item});

  final PresupuestoItem item;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.cajaMenorNombre,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            item.monedaCodigo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.clay.subtleText,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          _LineaMonto(label: 'Caja menor', value: item.cajaMenor),
          _LineaMonto(label: 'Recaudado', value: item.recaudado),
          _LineaMonto(label: 'Gastos', value: item.gastos),
          _LineaMonto(label: 'Creditos', value: item.creditos),
          _LineaMonto(
            label:
                'Refinanciado (${_textoCreditos(item.creditosRefinanciados)})',
            value: item.valorRefinanciado,
          ),
          const Divider(height: 20),
          _LineaMonto(
            label: 'Presupuesto',
            value: item.presupuesto,
            destacado: true,
          ),
        ],
      ),
    );
  }
}

class _LineaMonto extends StatelessWidget {
  const _LineaMonto({
    required this.label,
    required this.value,
    this.destacado = false,
  });

  final String label;
  final double value;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = destacado
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(_dinero(value), style: style),
        ],
      ),
    );
  }
}

class _FiltrosRuta extends StatelessWidget {
  const _FiltrosRuta({
    required this.buscarController,
    required this.rutas,
    required this.rutaSeleccionadaId,
    required this.exportando,
    required this.vistaMapaDesktop,
    required this.mostrarLimpiarFiltros,
    required this.onRutaChanged,
    required this.onExportar,
    required this.onLimpiarFiltros,
  });

  final TextEditingController buscarController;
  final List<RutaCatalogo> rutas;
  final String? rutaSeleccionadaId;
  final bool exportando;
  final bool vistaMapaDesktop;
  final bool mostrarLimpiarFiltros;
  final ValueChanged<String?> onRutaChanged;
  final VoidCallback onExportar;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 620;
        final Widget buscar = TextField(
          controller: buscarController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Buscar cliente, cedula o negocio',
          ),
        );
        final Widget selectorRuta = CobroDropdownField<String?>(
          key: ValueKey<String?>(rutaSeleccionadaId),
          labelText: 'Ruta',
          prefixIcon: const Icon(Icons.route_rounded),
          value: rutaSeleccionadaId,
          hintText: 'Todas',
          menuWidth: 260,
          items: <CobroDropdownItem<String?>>[
            const CobroDropdownItem<String?>(
              value: null,
              label: 'Todas',
              subtitle: 'Todas las rutas',
              icon: Icons.all_inclusive_rounded,
              iconColor: Color(0xFF6366F1),
            ),
            ...rutas.map(
              (RutaCatalogo ruta) => CobroDropdownItem<String?>(
                value: ruta.id,
                label: ruta.nombre,
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
          onChanged: onRutaChanged,
        );
        final Widget exportar = SizedBox(
          width: compact ? double.infinity : null,
          height: compact ? 56 : null,
          child: OutlinedButton.icon(
            onPressed: exportando ? null : onExportar,
            icon: exportando
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            label: Text(exportando ? 'Exportando' : 'Exportar'),
          ),
        );
        final Widget limpiar = Tooltip(
          message: 'Limpiar filtros',
          child: IconButton.outlined(
            onPressed: onLimpiarFiltros,
            icon: const Icon(Icons.filter_alt_off_rounded),
          ),
        );

        if (vistaMapaDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              buscar,
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: selectorRuta),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: exportando ? 'Exportando' : 'Exportar ruta',
                    child: SizedBox.square(
                      dimension: 56,
                      child: IconButton.outlined(
                        onPressed: exportando ? null : onExportar,
                        icon: exportando
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.file_download_outlined),
                      ),
                    ),
                  ),
                  if (mostrarLimpiarFiltros) ...<Widget>[
                    const SizedBox(width: 8),
                    SizedBox.square(dimension: 56, child: limpiar),
                  ],
                ],
              ),
            ],
          );
        }

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              buscar,
              const SizedBox(height: 10),
              selectorRuta,
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: exportar),
                  if (mostrarLimpiarFiltros) ...<Widget>[
                    const SizedBox(width: 10),
                    SizedBox.square(
                      dimension: 56,
                      child: limpiar,
                    ),
                  ],
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 2, child: buscar),
            const SizedBox(width: 12),
            Expanded(child: selectorRuta),
            const SizedBox(width: 12),
            exportar,
            if (mostrarLimpiarFiltros) ...<Widget>[
              const SizedBox(width: 8),
              limpiar,
            ],
          ],
        );
      },
    );
  }
}

class _VisorExportacionExcel extends StatelessWidget {
  const _VisorExportacionExcel({
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
                            _EtiquetaExportacion(texto: filas),
                            _EtiquetaExportacion(
                              texto:
                                  'Generado ${_fechaHoraEtiqueta(exportacion.generadoEn)}',
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
                        : _TablaVistaPreviaExcel(vistaPrevia: vistaPrevia),
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

class _EtiquetaExportacion extends StatelessWidget {
  const _EtiquetaExportacion({required this.texto});

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

class _TablaVistaPreviaExcel extends StatelessWidget {
  const _TablaVistaPreviaExcel({required this.vistaPrevia});

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
                                _textoCeldaExportacion(valor),
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

class _ResumenEstados extends StatelessWidget {
  const _ResumenEstados({
    required this.alDia,
    required this.pendientes,
    required this.atrasados,
    required this.pagados,
    required this.filtro,
    required this.onFiltroChanged,
  });

  final int alDia;
  final int pendientes;
  final int atrasados;
  final int pagados;
  final _FiltroEstadoRuta filtro;
  final ValueChanged<_FiltroEstadoRuta> onFiltroChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _EstadoContador(
          label: 'Al día',
          value: alDia,
          color: CobroAppTheme.success,
          selected: filtro == _FiltroEstadoRuta.alDia,
          onTap: () => onFiltroChanged(_FiltroEstadoRuta.alDia),
        ),
        _EstadoContador(
          label: 'Debe hoy',
          value: pendientes,
          color: CobroAppTheme.warning,
          selected: filtro == _FiltroEstadoRuta.pendiente,
          onTap: () => onFiltroChanged(_FiltroEstadoRuta.pendiente),
        ),
        _EstadoContador(
          label: 'Atrasado',
          value: atrasados,
          color: CobroAppTheme.danger,
          selected: filtro == _FiltroEstadoRuta.atrasado,
          onTap: () => onFiltroChanged(_FiltroEstadoRuta.atrasado),
        ),
        _EstadoContador(
          label: 'Pagados',
          value: pagados,
          color: CobroAppTheme.primary,
          selected: filtro == _FiltroEstadoRuta.pagado,
          onTap: () => onFiltroChanged(_FiltroEstadoRuta.pagado),
        ),
      ],
    );
  }
}

class _EstadoContador extends StatelessWidget {
  const _EstadoContador({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filtrar $label',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width < 560 ? 132 : 0,
        ),
        child: ClaySurface(
          radius: 14,
          padding: EdgeInsets.zero,
          color: color.withValues(alpha: selected ? 0.18 : 0.08),
          borderColor: color.withValues(alpha: selected ? 0.48 : 0.22),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.circle,
                      size: selected ? 16 : 10,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$label: $value',
                      style: TextStyle(
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonListaCreditos extends StatefulWidget {
  const _SkeletonListaCreditos();

  @override
  State<_SkeletonListaCreditos> createState() => _SkeletonListaCreditosState();
}

class _SkeletonListaCreditosState extends State<_SkeletonListaCreditos>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: List<Widget>.generate(
            3,
            (int index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SkeletonTarjetaCredito(progreso: _controller.value),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonTarjetaCredito extends StatelessWidget {
  const _SkeletonTarjetaCredito({required this.progreso});

  final double progreso;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SkeletonCreditoBloque(
                      progreso: progreso,
                      width: 210,
                      height: 18,
                    ),
                    const SizedBox(height: 8),
                    _SkeletonCreditoBloque(
                      progreso: progreso,
                      width: 280,
                      height: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SkeletonCreditoBloque(
                progreso: progreso,
                width: 78,
                height: 28,
                radius: 999,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SkeletonCreditoBloque(
            progreso: progreso,
            width: double.infinity,
            height: 9,
            radius: 999,
          ),
          const SizedBox(height: 8),
          _SkeletonCreditoBloque(
            progreso: progreso,
            width: 230,
            height: 12,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: List<Widget>.generate(
              6,
              (int index) => _SkeletonDatoCredito(progreso: progreso),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonDatoCredito extends StatelessWidget {
  const _SkeletonDatoCredito({required this.progreso});

  final double progreso;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SkeletonCreditoBloque(
            progreso: progreso,
            width: 58,
            height: 10,
          ),
          const SizedBox(height: 6),
          _SkeletonCreditoBloque(
            progreso: progreso,
            width: 94,
            height: 15,
          ),
        ],
      ),
    );
  }
}

class _SkeletonCreditoBloque extends StatelessWidget {
  const _SkeletonCreditoBloque({
    required this.progreso,
    required this.width,
    required this.height,
    this.radius = 7,
  });

  final double progreso;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bool oscuro = Theme.of(context).brightness == Brightness.dark;
    final Color base = context.clay.border.withValues(
      alpha: oscuro ? 0.38 : 0.5,
    );
    final Color brillo = Colors.white.withValues(alpha: oscuro ? 0.14 : 0.58);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: base),
            FractionalTranslation(
              translation: Offset((progreso * 2.4) - 1.2, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      brillo,
                      Colors.transparent,
                    ],
                    stops: const <double>[0.24, 0.5, 0.76],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonListaMovimientosCaja extends StatefulWidget {
  const _SkeletonListaMovimientosCaja();

  @override
  State<_SkeletonListaMovimientosCaja> createState() =>
      _SkeletonListaMovimientosCajaState();
}

class _SkeletonListaMovimientosCajaState
    extends State<_SkeletonListaMovimientosCaja>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: List<Widget>.generate(
            4,
            (int index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SkeletonTarjetaMovimientoCaja(
                progreso: _controller.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonTarjetaMovimientoCaja extends StatelessWidget {
  const _SkeletonTarjetaMovimientoCaja({required this.progreso});

  final double progreso;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 380;
        final Widget detalle = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SkeletonCreditoBloque(
              progreso: progreso,
              width: compact ? 150 : 220,
              height: 16,
            ),
            const SizedBox(height: 8),
            _SkeletonCreditoBloque(
              progreso: progreso,
              width: double.infinity,
              height: 12,
            ),
            if (compact) ...<Widget>[
              const SizedBox(height: 10),
              _SkeletonCreditoBloque(
                progreso: progreso,
                width: 88,
                height: 18,
              ),
            ],
          ],
        );

        return ClaySurface(
          radius: 14,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              _SkeletonCreditoBloque(
                progreso: progreso,
                width: 42,
                height: 42,
                radius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(child: detalle),
              if (!compact) ...<Widget>[
                const SizedBox(width: 12),
                _SkeletonCreditoBloque(
                  progreso: progreso,
                  width: 88,
                  height: 18,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TarjetaCreditoRegistro extends StatelessWidget {
  const _TarjetaCreditoRegistro({
    required this.credito,
    required this.puedeModificar,
    required this.puedeEliminar,
    required this.onModificar,
    required this.onEliminar,
    required this.onRefinanciar,
  });

  final CreditoRegistro credito;
  final bool puedeModificar;
  final bool puedeEliminar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;
  final VoidCallback? onRefinanciar;

  @override
  Widget build(BuildContext context) {
    final CreditoRefinanciacion? refinanciacion = credito.refinanciacion;
    final DateTime? fechaModificacion = credito.fechaModificacionVisible;
    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      credito.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if ((credito.cedula ?? '').isNotEmpty)
                          'CC ${credito.cedula!}',
                        if ((credito.negocio ?? '').isNotEmpty)
                          credito.negocio!,
                        credito.ruta,
                      ].join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.clay.subtleText,
                          ),
                    ),
                  ],
                ),
              ),
              _EstadoCreditoChip(credito: credito),
              if (puedeModificar || puedeEliminar) ...<Widget>[
                const SizedBox(width: 4),
                PopupMenuButton<_AccionCredito>(
                  tooltip: 'Acciones',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (_AccionCredito accion) {
                    switch (accion) {
                      case _AccionCredito.modificar:
                        onModificar();
                      case _AccionCredito.eliminar:
                        onEliminar();
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<_AccionCredito>>[
                      if (puedeModificar)
                        const PopupMenuItem<_AccionCredito>(
                          value: _AccionCredito.modificar,
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 12),
                              Text('Modificar'),
                            ],
                          ),
                        ),
                      if (puedeEliminar)
                        const PopupMenuItem<_AccionCredito>(
                          value: _AccionCredito.eliminar,
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.delete_outline_rounded),
                              SizedBox(width: 12),
                              Text('Eliminar'),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ],
          ),
          if (refinanciacion != null) ...<Widget>[
            const SizedBox(height: 10),
            _EtiquetaRefinanciacion(refinanciacion: refinanciacion),
          ],
          if (fechaModificacion != null) ...<Widget>[
            const SizedBox(height: 10),
            _EtiquetaCreditoModificado(fecha: fechaModificacion),
          ],
          const SizedBox(height: 14),
          _BarraSaldo(
            abonado: credito.totalAbonado,
            total: credito.valorTotal,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              _DatoResumen(
                label: 'Principal',
                value: _dinero(credito.valorPrincipal),
              ),
              _DatoResumen(label: 'Saldo', value: _dinero(credito.saldo)),
              _DatoResumen(label: 'Cuota', value: _dinero(credito.valorCuota)),
              _DatoResumen(
                label: 'Cuotas',
                value: '${credito.cuotasRestantes} / ${credito.numeroCuotas}',
              ),
              _DatoResumen(
                label: 'Inicio',
                value: _fechaEtiqueta(credito.fechaInicio),
              ),
              _DatoResumen(
                label: 'Maxima',
                value: _fechaEtiqueta(credito.fechaMaxima),
              ),
            ],
          ),
          if ((credito.cajaMenor ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Caja menor: ${credito.cajaMenor}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.clay.subtleText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          if (onRefinanciar != null) ...<Widget>[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onRefinanciar,
                icon: const Icon(Icons.currency_exchange_rounded),
                label: const Text('Refinanciar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EstadoCreditoChip extends StatelessWidget {
  const _EstadoCreditoChip({required this.credito});

  final CreditoRegistro credito;

  @override
  Widget build(BuildContext context) {
    final Color color =
        credito.activo ? CobroAppTheme.success : context.clay.subtleText;
    return ClaySurface(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: color.withValues(alpha: 0.1),
      borderColor: color.withValues(alpha: 0.25),
      elevated: false,
      child: Text(
        credito.estado.nombre,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EtiquetaRefinanciacion extends StatelessWidget {
  const _EtiquetaRefinanciacion({required this.refinanciacion});

  final CreditoRefinanciacion refinanciacion;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CobroAppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CobroAppTheme.warning.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          'Refinanciado ${_dinero(refinanciacion.valorAnterior)} a '
          '${_dinero(refinanciacion.valorNuevo)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: CobroAppTheme.warning,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _EtiquetaCreditoModificado extends StatelessWidget {
  const _EtiquetaCreditoModificado({required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CobroAppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CobroAppTheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          'Modificado ${_fechaHoraEtiqueta(fecha)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: CobroAppTheme.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _TarjetaCobroRuta extends StatelessWidget {
  const _TarjetaCobroRuta({
    required this.cobro,
    required this.pagoEnProceso,
    required this.pagoAplicadoInstantaneo,
    required this.onRegistrarPago,
    this.onGuardarUbicacion,
  });

  final CobroRuta cobro;
  final bool pagoEnProceso;
  final bool pagoAplicadoInstantaneo;
  final VoidCallback? onRegistrarPago;
  final VoidCallback? onGuardarUbicacion;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cobro.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if ((cobro.cedula ?? '').isNotEmpty)
                          'CC ${cobro.cedula!}',
                        if ((cobro.negocio ?? '').isNotEmpty) cobro.negocio!,
                        cobro.ruta,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.clay.subtleText,
                          ),
                    ),
                    if ((cobro.direccion ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: context.clay.subtleText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cobro.direccion!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: context.clay.subtleText),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _EstadoChip(estado: cobro.estadoCobro),
            ],
          ),
          const SizedBox(height: 14),
          _BarraSaldo(
            abonado: cobro.totalAbonado,
            total: cobro.valorTotal,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              _DatoResumen(label: 'Saldo', value: _dinero(cobro.saldo)),
              _DatoResumen(label: 'Cuota', value: _dinero(cobro.valorCuota)),
              _DatoResumen(
                label: 'Restantes',
                value: '${cobro.cuotasRestantes} / ${cobro.numeroCuotas}',
              ),
              _DatoResumen(
                label: 'Próxima',
                value: _fechaEtiqueta(cobro.proximaFechaPago),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  key: ValueKey<String>('save-location-${cobro.id}'),
                  onPressed: onGuardarUbicacion,
                  icon: Icon(
                    cobro.latitude == null || cobro.longitude == null
                        ? Icons.add_location_alt_rounded
                        : Icons.edit_location_alt_rounded,
                    size: 18,
                  ),
                  label: Text(
                    cobro.latitude == null || cobro.longitude == null
                        ? 'Ubicar'
                        : 'Actualizar punto',
                  ),
                ),
                FilledButton.icon(
                  key: ValueKey<String>('register-payment-${cobro.id}'),
                  onPressed: onRegistrarPago,
                  icon: pagoEnProceso
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : pagoAplicadoInstantaneo
                          ? const Icon(Icons.check_circle_rounded)
                          : const Icon(Icons.payments_rounded),
                  label: Text(
                    pagoEnProceso
                        ? 'Aplicando'
                        : pagoAplicadoInstantaneo
                            ? 'Aplicado'
                            : cobro.saldo <= 0.009
                                ? 'Pagado'
                                : 'Registrar pago',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraSaldo extends StatelessWidget {
  const _BarraSaldo({required this.abonado, required this.total});

  final double abonado;
  final double total;

  @override
  Widget build(BuildContext context) {
    final double progreso =
        total <= 0 ? 0 : (abonado / total).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: progreso,
            backgroundColor: context.clay.progressBackground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_dinero(abonado)} abonado de ${_dinero(total)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.clay.subtleText,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});

  final EstadoCobro estado;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: estado.color.withValues(alpha: 0.1),
      borderColor: estado.color.withValues(alpha: 0.25),
      elevated: false,
      child: Text(
        estado.etiqueta,
        style: TextStyle(
          color: estado.color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DatoResumen extends StatelessWidget {
  const _DatoResumen({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.clay.subtleText,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _ResumenCreditoAnimado extends StatefulWidget {
  const _ResumenCreditoAnimado({
    required this.valorController,
    required this.interesController,
    required this.plazoController,
    required this.frecuencias,
    required this.frecuenciaPagoId,
    required this.fechaInicio,
    required this.omitirDomingos,
  });

  final TextEditingController valorController;
  final TextEditingController interesController;
  final TextEditingController plazoController;
  final List<FrecuenciaPago> frecuencias;
  final int? frecuenciaPagoId;
  final DateTime fechaInicio;
  final bool omitirDomingos;

  @override
  State<_ResumenCreditoAnimado> createState() => _ResumenCreditoAnimadoState();
}

class _ResumenCreditoAnimadoState extends State<_ResumenCreditoAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacionBilletes;

  @override
  void initState() {
    super.initState();
    _animacionBilletes = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _agregarListeners(widget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reducirMovimiento =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducirMovimiento) {
      _animacionBilletes.stop();
      _animacionBilletes.value = 0.58;
    } else if (!_animacionBilletes.isAnimating) {
      _animacionBilletes.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ResumenCreditoAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valorController != widget.valorController ||
        oldWidget.interesController != widget.interesController ||
        oldWidget.plazoController != widget.plazoController) {
      _quitarListeners(oldWidget);
      _agregarListeners(widget);
    }
  }

  void _agregarListeners(_ResumenCreditoAnimado resumen) {
    resumen.valorController.addListener(_actualizarCalculo);
    resumen.interesController.addListener(_actualizarCalculo);
    resumen.plazoController.addListener(_actualizarCalculo);
  }

  void _quitarListeners(_ResumenCreditoAnimado resumen) {
    resumen.valorController.removeListener(_actualizarCalculo);
    resumen.interesController.removeListener(_actualizarCalculo);
    resumen.plazoController.removeListener(_actualizarCalculo);
  }

  void _actualizarCalculo() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _quitarListeners(widget);
    _animacionBilletes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FrecuenciaPago? frecuencia = _frecuenciaSeleccionada();
    final _CalculoCredito calculo = _CalculoCredito.desdeFormulario(
      valor: widget.valorController.text,
      interes: widget.interesController.text,
      plazo: widget.plazoController.text,
      fechaInicio: widget.fechaInicio,
      diasIntervalo: frecuencia?.diasIntervalo ?? 1,
      omitirDomingos: widget.omitirDomingos,
    );
    final ThemeData theme = Theme.of(context);
    final Color acento = CobroAppTheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: acento.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: CobroAppTheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Así se calcula el crédito',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Los valores cambian mientras completas el formulario.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.auto_graph_rounded,
                color: CobroAppTheme.success,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FlujoBilletes(
            animacion: _animacionBilletes,
            capital: calculo.valorPrincipal,
            porcentajeInteres: calculo.porcentajeInteres,
            interes: calculo.valorInteres,
            total: calculo.valorTotal,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: context.clay.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.clay.border),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.event_repeat_rounded,
                  color: CobroAppTheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${_dineroCredito(calculo.valorTotal)} ÷ '
                        '${calculo.numeroCuotas} cuotas = '
                        '${_dineroCredito(calculo.valorCuota)} por cuota',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${calculo.numeroCuotas} cuotas '
                        '${_etiquetaFrecuencia(frecuencia)} · '
                        'fecha máxima ${_fechaEtiqueta(calculo.fechaMaxima)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.clay.subtleText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    _dineroCredito(calculo.valorCuota),
                    key: ValueKey<String>(
                      '${calculo.valorCuota}-${calculo.numeroCuotas}',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: CobroAppTheme.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.clay.text,
                height: 1.45,
              ),
              children: <InlineSpan>[
                const TextSpan(text: 'El cliente recibe '),
                _resaltado(_dineroCredito(calculo.valorPrincipal), acento),
                const TextSpan(text: '. El interés del '),
                _resaltado(
                  '${_numero(calculo.porcentajeInteres)}%',
                  CobroAppTheme.warning,
                ),
                const TextSpan(text: ' suma '),
                _resaltado(
                  _dineroCredito(calculo.valorInteres),
                  CobroAppTheme.warning,
                ),
                const TextSpan(text: ', para un total de '),
                _resaltado(
                  _dineroCredito(calculo.valorTotal),
                  CobroAppTheme.success,
                ),
                TextSpan(
                  text: ' en ${calculo.numeroCuotas} cuotas '
                      '${_etiquetaFrecuencia(frecuencia)} de '
                      '${_dineroCredito(calculo.valorCuota)}. ',
                ),
                TextSpan(
                  text: widget.omitirDomingos &&
                          (frecuencia?.diasIntervalo ?? 1) == 1
                      ? 'Se omiten ${calculo.domingosOmitidos} domingos.'
                      : 'No se omiten días del calendario.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  FrecuenciaPago? _frecuenciaSeleccionada() {
    for (final FrecuenciaPago frecuencia in widget.frecuencias) {
      if (frecuencia.id == widget.frecuenciaPagoId) {
        return frecuencia;
      }
    }
    return widget.frecuencias.isEmpty ? null : widget.frecuencias.first;
  }

  TextSpan _resaltado(String texto, Color color) {
    return TextSpan(
      text: texto,
      style: TextStyle(color: color, fontWeight: FontWeight.w900),
    );
  }
}

class _FlujoBilletes extends StatelessWidget {
  const _FlujoBilletes({
    required this.animacion,
    required this.capital,
    required this.porcentajeInteres,
    required this.interes,
    required this.total,
  });

  final Animation<double> animacion;
  final double capital;
  final double porcentajeInteres;
  final double interes;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Animación del dinero desde el capital hasta el total del crédito',
      child: SizedBox(
        height: 150,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  top: 3,
                  left: 5,
                  right: 5,
                  height: 38,
                  child: AnimatedBuilder(
                    animation: animacion,
                    builder: (BuildContext context, Widget? child) {
                      return Stack(
                        children: List<Widget>.generate(3, (int index) {
                          final double fase =
                              (animacion.value + (index * 0.31)) % 1;
                          final double recorrido =
                              math.max(0, constraints.maxWidth - 58);
                          return Positioned(
                            left: recorrido * fase,
                            top: 5 + math.sin(fase * math.pi * 2) * 3,
                            child: Opacity(
                              opacity: 0.48 +
                                  (math.sin(fase * math.pi).abs() * 0.52),
                              child: Transform.rotate(
                                angle: math.sin(fase * math.pi * 2) * 0.08,
                                child: const _Billete(),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 46,
                  left: 0,
                  right: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: _PasoCalculo(
                          icono: Icons.payments_rounded,
                          etiqueta: 'Capital',
                          valor: _dineroCredito(capital),
                          color: CobroAppTheme.primary,
                        ),
                      ),
                      const _FlechaFlujo(simbolo: '+'),
                      Expanded(
                        child: _PasoCalculo(
                          icono: Icons.percent_rounded,
                          etiqueta: '${_numero(porcentajeInteres)}% interés',
                          valor: _dineroCredito(interes),
                          color: CobroAppTheme.warning,
                        ),
                      ),
                      const _FlechaFlujo(simbolo: '='),
                      Expanded(
                        child: _PasoCalculo(
                          icono: Icons.account_balance_wallet_rounded,
                          etiqueta: 'Total',
                          valor: _dineroCredito(total),
                          color: CobroAppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Billete extends StatelessWidget {
  const _Billete();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 27,
      decoration: BoxDecoration(
        color: CobroAppTheme.success,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CobroAppTheme.success.withValues(alpha: 0.24),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.attach_money_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class _FlechaFlujo extends StatelessWidget {
  const _FlechaFlujo({required this.simbolo});

  final String simbolo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Text(
        simbolo,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.clay.subtleText,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _PasoCalculo extends StatelessWidget {
  const _PasoCalculo({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: context.clay.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.clay.subtleText,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculoCredito {
  const _CalculoCredito({
    required this.valorPrincipal,
    required this.porcentajeInteres,
    required this.valorInteres,
    required this.valorTotal,
    required this.numeroCuotas,
    required this.valorCuota,
    required this.fechaMaxima,
    required this.domingosOmitidos,
  });

  factory _CalculoCredito.desdeFormulario({
    required String valor,
    required String interes,
    required String plazo,
    required DateTime fechaInicio,
    required int diasIntervalo,
    required bool omitirDomingos,
  }) {
    final double valorPrincipal = math.max(0.0, _parseNumero(valor) ?? 0);
    final double porcentajeInteres = math.max(
      0.0,
      _parseNumero(interes) ?? 0,
    );
    final int plazoDias = math.max(1, (_parseNumero(plazo) ?? 1).round());
    final int intervalo = math.max(1, diasIntervalo);
    final int numeroCuotas = math.max(1, (plazoDias / intervalo).ceil());
    final double valorTotal =
        valorPrincipal + valorPrincipal * (porcentajeInteres / 100);
    final double valorInteres = valorTotal - valorPrincipal;
    final double valorCuota = valorTotal / numeroCuotas;
    DateTime cursor = DateTime(
      fechaInicio.year,
      fechaInicio.month,
      fechaInicio.day,
    );
    int domingosOmitidos = 0;

    for (int cuota = 0; cuota < numeroCuotas; cuota++) {
      if (intervalo == 1 && omitirDomingos) {
        do {
          cursor = cursor.add(const Duration(days: 1));
          if (cursor.weekday == DateTime.sunday) {
            domingosOmitidos++;
          }
        } while (cursor.weekday == DateTime.sunday);
      } else {
        cursor = cursor.add(Duration(days: intervalo));
      }
    }

    return _CalculoCredito(
      valorPrincipal: valorPrincipal,
      porcentajeInteres: porcentajeInteres,
      valorInteres: valorInteres,
      valorTotal: valorTotal,
      numeroCuotas: numeroCuotas,
      valorCuota: valorCuota,
      fechaMaxima: cursor,
      domingosOmitidos: domingosOmitidos,
    );
  }

  final double valorPrincipal;
  final double porcentajeInteres;
  final double valorInteres;
  final double valorTotal;
  final int numeroCuotas;
  final double valorCuota;
  final DateTime fechaMaxima;
  final int domingosOmitidos;
}

class _SelectorClienteCredito extends StatefulWidget {
  const _SelectorClienteCredito({
    required this.clientes,
    required this.clienteId,
    required this.enabled,
    required this.onChanged,
  });

  final List<Cliente> clientes;
  final String? clienteId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  State<_SelectorClienteCredito> createState() =>
      _SelectorClienteCreditoState();
}

class _SelectorClienteCreditoState extends State<_SelectorClienteCredito> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textoSeleccionado());
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SelectorClienteCredito oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clienteId == oldWidget.clienteId) {
      return;
    }

    if (widget.clienteId == null && _focusNode.hasFocus) {
      return;
    }

    _controller.text = _textoSeleccionado();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Cliente? clienteSeleccionado = _clientePorId(widget.clienteId);

    return RawAutocomplete<Cliente>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: _etiquetaCliente,
      optionsBuilder: (TextEditingValue value) {
        final String texto = value.text.trim();
        final String consulta = texto.toLowerCase();
        if (consulta.isEmpty ||
            (clienteSeleccionado != null &&
                texto == _etiquetaCliente(clienteSeleccionado))) {
          return widget.clientes;
        }

        return widget.clientes.where((Cliente cliente) {
          final String nombre = cliente.nombreCompleto.toLowerCase();
          final String cedula = (cliente.cedula ?? '').toLowerCase();
          final String negocio = (cliente.nombreComercial ?? '').toLowerCase();
          return nombre.contains(consulta) ||
              cedula.contains(consulta) ||
              negocio.contains(consulta);
        });
      },
      onSelected: (Cliente cliente) => widget.onChanged(cliente.id),
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController controller,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Cliente',
            hintText: 'Buscar por nombre o cedula',
            prefixIcon: const Icon(Icons.person_search_rounded),
            suffixIcon: widget.enabled
                ? const Icon(Icons.arrow_drop_down_rounded)
                : const Icon(Icons.lock_rounded),
          ),
          onTap: () {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          },
          onChanged: (String value) {
            final String texto = value.trim();
            final bool mantieneSeleccion = clienteSeleccionado != null &&
                texto == _etiquetaCliente(clienteSeleccionado);
            if (widget.clienteId != null &&
                (texto.isEmpty || !mantieneSeleccion)) {
              widget.onChanged(null);
            }
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<Cliente> onSelected,
        Iterable<Cliente> options,
      ) {
        final List<Cliente> opciones = options.toList(growable: false);
        final double ancho = math.min(
          520,
          math.max(0, MediaQuery.sizeOf(context).width - 32),
        );

        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: ancho,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: opciones.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No hay clientes con ese nombre o cedula',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: opciones.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final Cliente cliente = opciones[index];
                          return InkWell(
                            onTap: () => onSelected(cliente),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: _ClienteOpcionCredito(cliente: cliente),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Cliente? _clientePorId(String? id) {
    if (id == null) {
      return null;
    }

    for (final Cliente cliente in widget.clientes) {
      if (cliente.id == id) {
        return cliente;
      }
    }

    return null;
  }

  String _textoSeleccionado() {
    final Cliente? cliente = _clientePorId(widget.clienteId);
    return cliente == null ? '' : _etiquetaCliente(cliente);
  }
}

class _ClienteOpcionCredito extends StatelessWidget {
  const _ClienteOpcionCredito({required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final List<String> detalles = <String>[
      if ((cliente.cedula ?? '').isNotEmpty) 'CC ${cliente.cedula!}',
      if ((cliente.nombreComercial ?? '').isNotEmpty) cliente.nombreComercial!,
      if ((cliente.telefono ?? '').isNotEmpty) cliente.telefono!,
    ];

    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundColor: CobroAppTheme.primary.withValues(alpha: 0.12),
          foregroundColor: CobroAppTheme.primary,
          child: Text(
            cliente.nombreCompleto.isEmpty
                ? '?'
                : cliente.nombreCompleto.substring(0, 1).toUpperCase(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                cliente.nombreCompleto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (detalles.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  detalles.join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _etiquetaCliente(Cliente cliente) {
  final String cedula = cliente.cedula?.trim() ?? '';
  if (cedula.isEmpty) {
    return cliente.nombreCompleto;
  }

  return '${cliente.nombreCompleto} - CC $cedula';
}

class _SelectorClientesCreditoMultiple extends StatefulWidget {
  const _SelectorClientesCreditoMultiple({
    required this.clientes,
    required this.clientesSeleccionadosIds,
    required this.enabled,
    required this.onChanged,
  });

  final List<Cliente> clientes;
  final Set<String> clientesSeleccionadosIds;
  final bool enabled;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_SelectorClientesCreditoMultiple> createState() =>
      _SelectorClientesCreditoMultipleState();
}

class _SelectorClientesCreditoMultipleState
    extends State<_SelectorClientesCreditoMultiple> {
  late final TextEditingController _buscarController;

  @override
  void initState() {
    super.initState();
    _buscarController = TextEditingController();
    _buscarController.addListener(_refrescar);
  }

  @override
  void dispose() {
    _buscarController.removeListener(_refrescar);
    _buscarController.dispose();
    super.dispose();
  }

  void _refrescar() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Cliente> clientesFiltrados = _clientesFiltrados();
    final int seleccionados = widget.clientesSeleccionadosIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: _buscarController,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Clientes',
            hintText: 'Buscar por nombre o cedula',
            prefixIcon: const Icon(Icons.person_search_rounded),
            suffixIcon: seleccionados == 0
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Chip(
                      label: Text('$seleccionados'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 44),
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: clientesFiltrados.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No hay clientes con ese nombre o cedula',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: clientesFiltrados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final Cliente cliente = clientesFiltrados[index];
                      final bool seleccionado =
                          widget.clientesSeleccionadosIds.contains(cliente.id);
                      return InkWell(
                        onTap: widget.enabled
                            ? () => _alternarCliente(cliente.id)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: <Widget>[
                              Checkbox(
                                value: seleccionado,
                                onChanged: widget.enabled
                                    ? (_) => _alternarCliente(cliente.id)
                                    : null,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _ClienteOpcionCredito(cliente: cliente),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  List<Cliente> _clientesFiltrados() {
    final String consulta = _buscarController.text.trim().toLowerCase();
    if (consulta.isEmpty) {
      return widget.clientes;
    }

    return widget.clientes.where((Cliente cliente) {
      final String nombre = cliente.nombreCompleto.toLowerCase();
      final String cedula = (cliente.cedula ?? '').toLowerCase();
      final String negocio = (cliente.nombreComercial ?? '').toLowerCase();
      return nombre.contains(consulta) ||
          cedula.contains(consulta) ||
          negocio.contains(consulta);
    }).toList(growable: false);
  }

  void _alternarCliente(String clienteId) {
    final Set<String> actualizados =
        Set<String>.of(widget.clientesSeleccionadosIds);
    if (!actualizados.add(clienteId)) {
      actualizados.remove(clienteId);
    }
    widget.onChanged(actualizados);
  }
}

class _MontosClientesCredito extends StatelessWidget {
  const _MontosClientesCredito({
    required this.clientes,
    required this.clientesSeleccionadosIds,
    required this.enabled,
    required this.controllerForCliente,
  });

  final List<Cliente> clientes;
  final Set<String> clientesSeleccionadosIds;
  final bool enabled;
  final TextEditingController Function(String clienteId) controllerForCliente;

  @override
  Widget build(BuildContext context) {
    final List<Cliente> seleccionados = clientes
        .where(
          (Cliente cliente) => clientesSeleccionadosIds.contains(cliente.id),
        )
        .toList(growable: false);

    if (seleccionados.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.request_quote_rounded),
          labelText: 'Monto por cliente',
        ),
        child: Text(
          'Selecciona al menos un cliente',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.clay.subtleText,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Monto por cliente',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        ...seleccionados.map(
          (Cliente cliente) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MontoClienteCreditoItem(
              cliente: cliente,
              controller: controllerForCliente(cliente.id),
              enabled: enabled,
            ),
          ),
        ),
      ],
    );
  }
}

class _MontoClienteCreditoItem extends StatelessWidget {
  const _MontoClienteCreditoItem({
    required this.cliente,
    required this.controller,
    required this.enabled,
  });

  final Cliente cliente;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget clienteInfo = _ClienteOpcionCredito(cliente: cliente);
        final Widget monto = TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto',
            prefixIcon: Icon(Icons.request_quote_rounded),
          ),
        );

        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              clienteInfo,
              const SizedBox(height: 8),
              monto,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: clienteInfo),
            const SizedBox(width: 12),
            SizedBox(width: 220, child: monto),
          ],
        );
      },
    );
  }
}

class _FormularioCredito extends StatelessWidget {
  const _FormularioCredito({
    required this.clientes,
    required this.rutas,
    required this.monedas,
    required this.frecuencias,
    required this.cajasMenores,
    required this.clienteId,
    required this.rutaId,
    required this.monedaCodigo,
    required this.frecuenciaPagoId,
    required this.cajaMenorId,
    required this.fechaInicio,
    required this.omitirDomingos,
    required this.valorController,
    required this.interesController,
    required this.plazoController,
    required this.observacionController,
    required this.guardando,
    required this.onClienteChanged,
    required this.onRutaChanged,
    required this.onMonedaChanged,
    required this.onFrecuenciaChanged,
    required this.onCajaMenorChanged,
    required this.onFechaChanged,
    required this.onOmitirDomingosChanged,
    required this.onCrear,
    this.usarSuperficie = true,
    this.accionLabel = 'Crear credito',
    this.clienteBloqueado = false,
    this.monedaBloqueada = false,
    this.clientesSeleccionadosIds = const <String>{},
    this.valorClienteController,
    this.onClientesSeleccionadosChanged,
  });

  final List<Cliente> clientes;
  final List<RutaCatalogo> rutas;
  final List<Moneda> monedas;
  final List<FrecuenciaPago> frecuencias;
  final List<CajaMenorCatalogo> cajasMenores;
  final String? clienteId;
  final String? rutaId;
  final String? monedaCodigo;
  final int? frecuenciaPagoId;
  final String? cajaMenorId;
  final DateTime fechaInicio;
  final bool omitirDomingos;
  final TextEditingController valorController;
  final Set<String> clientesSeleccionadosIds;
  final TextEditingController Function(String clienteId)?
      valorClienteController;
  final TextEditingController interesController;
  final TextEditingController plazoController;
  final TextEditingController observacionController;
  final bool guardando;
  final ValueChanged<String?> onClienteChanged;
  final ValueChanged<Set<String>>? onClientesSeleccionadosChanged;
  final ValueChanged<String?> onRutaChanged;
  final ValueChanged<String?> onMonedaChanged;
  final ValueChanged<int?> onFrecuenciaChanged;
  final ValueChanged<String?> onCajaMenorChanged;
  final ValueChanged<DateTime> onFechaChanged;
  final ValueChanged<bool> onOmitirDomingosChanged;
  final VoidCallback onCrear;
  final bool usarSuperficie;
  final String accionLabel;
  final bool clienteBloqueado;
  final bool monedaBloqueada;

  @override
  Widget build(BuildContext context) {
    final bool seleccionarVariosClientes =
        onClientesSeleccionadosChanged != null && !clienteBloqueado;
    final Widget contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (seleccionarVariosClientes)
          _SelectorClientesCreditoMultiple(
            clientes: clientes,
            clientesSeleccionadosIds: clientesSeleccionadosIds,
            enabled: !guardando,
            onChanged: onClientesSeleccionadosChanged!,
          )
        else
          _SelectorClienteCredito(
            clientes: clientes,
            clienteId: clienteId,
            enabled: !guardando && !clienteBloqueado,
            onChanged: onClienteChanged,
          ),
        const SizedBox(height: 12),
        CobroDropdownField<String?>(
          key: ValueKey<String?>('ruta-$rutaId'),
          labelText: 'Ruta',
          prefixIcon: const Icon(Icons.route_rounded),
          value: rutaId,
          hintText: 'Automatica',
          enabled: !guardando,
          items: <CobroDropdownItem<String?>>[
            const CobroDropdownItem<String?>(
              value: null,
              label: 'Automatica',
              subtitle: 'Asignacion automatica segun cliente',
              icon: Icons.auto_mode_rounded,
              iconColor: Color(0xFF6366F1),
            ),
            ...rutas.map(
              (RutaCatalogo ruta) => CobroDropdownItem<String?>(
                value: ruta.id,
                label: ruta.nombre,
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
          onChanged: guardando ? null : onRutaChanged,
        ),
        const SizedBox(height: 12),
        _DosColumnas(
          left: CobroDropdownField<String>(
            key: ValueKey<String?>('moneda-$monedaCodigo'),
            labelText: 'Moneda',
            prefixIcon: const Icon(Icons.attach_money_rounded),
            value: monedaCodigo,
            enabled: !guardando && !monedaBloqueada,
            menuWidth: 280,
            items: monedas
                .map(
                  (Moneda moneda) => CobroDropdownItem<String>(
                    value: moneda.codigo,
                    label: moneda.codigo,
                    subtitle:
                        moneda.nombre != moneda.codigo ? moneda.nombre : null,
                    icon: Icons.monetization_on_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando || monedaBloqueada ? null : onMonedaChanged,
          ),
          right: CobroDropdownField<int>(
            key: ValueKey<String>('frecuencia-$frecuenciaPagoId'),
            labelText: 'Frecuencia',
            prefixIcon: const Icon(Icons.event_repeat_rounded),
            value: frecuenciaPagoId,
            enabled: !guardando,
            menuWidth: 280,
            items: frecuencias
                .map(
                  (FrecuenciaPago frecuencia) => CobroDropdownItem<int>(
                    value: frecuencia.id,
                    label: frecuencia.nombre,
                    subtitle: frecuencia.diasIntervalo > 1
                        ? 'Cada ${frecuencia.diasIntervalo} dias'
                        : 'Cobro diario',
                    icon: Icons.update_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando ? null : onFrecuenciaChanged,
          ),
        ),
        const SizedBox(height: 12),
        CobroDropdownField<String?>(
          key: ValueKey<String?>('caja-$cajaMenorId'),
          labelText: 'Caja menor',
          prefixIcon: const Icon(Icons.savings_rounded),
          value: cajaMenorId,
          enabled: !guardando,
          items: cajasMenores
              .map(
                (CajaMenorCatalogo caja) => CobroDropdownItem<String?>(
                  value: caja.id,
                  label: caja.nombre,
                  subtitle: 'Moneda: ${caja.monedaCodigo}',
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFF2563EB),
                ),
              )
              .toList(growable: false),
          onChanged: guardando ? null : onCajaMenorChanged,
        ),
        const SizedBox(height: 12),
        if (seleccionarVariosClientes) ...<Widget>[
          _MontosClientesCredito(
            clientes: clientes,
            clientesSeleccionadosIds: clientesSeleccionadosIds,
            enabled: !guardando,
            controllerForCliente: valorClienteController!,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: interesController,
            enabled: !guardando,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(
              labelText: 'Interes %',
              prefixIcon: Icon(Icons.percent_rounded),
            ),
          ),
        ] else
          _DosColumnas(
            left: TextField(
              controller: valorController,
              enabled: !guardando,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor principal',
                prefixIcon: Icon(Icons.request_quote_rounded),
              ),
            ),
            right: TextField(
              controller: interesController,
              enabled: !guardando,
              readOnly: true,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                labelText: 'Interés %',
                prefixIcon: Icon(Icons.percent_rounded),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _DosColumnas(
          left: TextField(
            controller: plazoController,
            enabled: !guardando,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Plazo días',
              prefixIcon: Icon(Icons.date_range_rounded),
            ),
          ),
          right: OutlinedButton.icon(
            onPressed: guardando
                ? null
                : () async {
                    final DateTime? selected = await showDatePicker(
                      context: context,
                      initialDate: fechaInicio,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selected != null) {
                      onFechaChanged(selected);
                    }
                  },
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(_fechaEtiqueta(fechaInicio)),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: omitirDomingos,
          onChanged: guardando ? null : onOmitirDomingosChanged,
          title: const Text('Omitir domingos'),
          secondary: const Icon(Icons.weekend_rounded),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        if (!seleccionarVariosClientes) ...<Widget>[
          _ResumenCreditoAnimado(
            valorController: valorController,
            interesController: interesController,
            plazoController: plazoController,
            frecuencias: frecuencias,
            frecuenciaPagoId: frecuenciaPagoId,
            fechaInicio: fechaInicio,
            omitirDomingos: omitirDomingos,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: observacionController,
          enabled: !guardando,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observación',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: guardando ? null : onCrear,
            icon: guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(accionLabel),
          ),
        ),
      ],
    );

    if (!usarSuperficie) {
      return contenido;
    }

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: contenido,
    );
  }
}

class _CamposCreditoSinCliente extends StatelessWidget {
  const _CamposCreditoSinCliente({
    required this.rutas,
    required this.monedas,
    required this.frecuencias,
    required this.cajasMenores,
    required this.rutaId,
    required this.monedaCodigo,
    required this.frecuenciaPagoId,
    required this.cajaMenorId,
    required this.fechaInicio,
    required this.omitirDomingos,
    required this.valorController,
    required this.interesController,
    required this.plazoController,
    required this.observacionController,
    required this.guardando,
    required this.onRutaChanged,
    required this.onMonedaChanged,
    required this.onFrecuenciaChanged,
    required this.onCajaMenorChanged,
    required this.onFechaChanged,
    required this.onOmitirDomingosChanged,
  });

  final List<RutaCatalogo> rutas;
  final List<Moneda> monedas;
  final List<FrecuenciaPago> frecuencias;
  final List<CajaMenorCatalogo> cajasMenores;
  final String? rutaId;
  final String? monedaCodigo;
  final int? frecuenciaPagoId;
  final String? cajaMenorId;
  final DateTime fechaInicio;
  final bool omitirDomingos;
  final TextEditingController valorController;
  final TextEditingController interesController;
  final TextEditingController plazoController;
  final TextEditingController observacionController;
  final bool guardando;
  final ValueChanged<String?> onRutaChanged;
  final ValueChanged<String?> onMonedaChanged;
  final ValueChanged<int?> onFrecuenciaChanged;
  final ValueChanged<String?> onCajaMenorChanged;
  final ValueChanged<DateTime> onFechaChanged;
  final ValueChanged<bool> onOmitirDomingosChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CobroDropdownField<String?>(
          key: ValueKey<String?>('nuevo-cliente-modal-ruta-$rutaId'),
          labelText: 'Ruta',
          prefixIcon: const Icon(Icons.route_rounded),
          value: rutaId,
          hintText: 'Automatica',
          enabled: !guardando,
          items: <CobroDropdownItem<String?>>[
            const CobroDropdownItem<String?>(
              value: null,
              label: 'Automatica',
              subtitle: 'Asignacion automatica segun cliente',
              icon: Icons.auto_mode_rounded,
              iconColor: Color(0xFF6366F1),
            ),
            ...rutas.map(
              (RutaCatalogo ruta) => CobroDropdownItem<String?>(
                value: ruta.id,
                label: ruta.nombre,
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
          onChanged: guardando ? null : onRutaChanged,
        ),
        const SizedBox(height: 12),
        _DosColumnas(
          left: CobroDropdownField<String>(
            key: ValueKey<String?>('nuevo-cliente-modal-moneda-$monedaCodigo'),
            labelText: 'Moneda',
            prefixIcon: const Icon(Icons.attach_money_rounded),
            value: monedaCodigo,
            enabled: !guardando,
            menuWidth: 280,
            items: monedas
                .map(
                  (Moneda moneda) => CobroDropdownItem<String>(
                    value: moneda.codigo,
                    label: moneda.codigo,
                    subtitle:
                        moneda.nombre != moneda.codigo ? moneda.nombre : null,
                    icon: Icons.monetization_on_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando ? null : onMonedaChanged,
          ),
          right: CobroDropdownField<int>(
            key: ValueKey<String>(
              'nuevo-cliente-modal-frecuencia-$frecuenciaPagoId',
            ),
            labelText: 'Frecuencia',
            prefixIcon: const Icon(Icons.event_repeat_rounded),
            value: frecuenciaPagoId,
            enabled: !guardando,
            menuWidth: 280,
            items: frecuencias
                .map(
                  (FrecuenciaPago frecuencia) => CobroDropdownItem<int>(
                    value: frecuencia.id,
                    label: frecuencia.nombre,
                    subtitle: frecuencia.diasIntervalo > 1
                        ? 'Cada ${frecuencia.diasIntervalo} dias'
                        : 'Cobro diario',
                    icon: Icons.update_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando ? null : onFrecuenciaChanged,
          ),
        ),
        const SizedBox(height: 12),
        CobroDropdownField<String?>(
          key: ValueKey<String?>('nuevo-cliente-modal-caja-$cajaMenorId'),
          labelText: 'Caja menor',
          prefixIcon: const Icon(Icons.savings_rounded),
          value: cajaMenorId,
          enabled: !guardando,
          items: cajasMenores
              .map(
                (CajaMenorCatalogo caja) => CobroDropdownItem<String?>(
                  value: caja.id,
                  label: caja.nombre,
                  subtitle: 'Moneda: ${caja.monedaCodigo}',
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFF2563EB),
                ),
              )
              .toList(growable: false),
          onChanged: guardando ? null : onCajaMenorChanged,
        ),
        const SizedBox(height: 12),
        _DosColumnas(
          left: TextField(
            controller: valorController,
            enabled: !guardando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor principal',
              prefixIcon: Icon(Icons.request_quote_rounded),
            ),
          ),
          right: TextField(
            controller: interesController,
            enabled: !guardando,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(
              labelText: 'Interes %',
              prefixIcon: Icon(Icons.percent_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DosColumnas(
          left: TextField(
            controller: plazoController,
            enabled: !guardando,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Plazo dias',
              prefixIcon: Icon(Icons.date_range_rounded),
            ),
          ),
          right: OutlinedButton.icon(
            onPressed: guardando
                ? null
                : () async {
                    final DateTime? selected = await showDatePicker(
                      context: context,
                      initialDate: fechaInicio,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selected != null) {
                      onFechaChanged(selected);
                    }
                  },
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(_fechaEtiqueta(fechaInicio)),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: omitirDomingos,
          onChanged: guardando ? null : onOmitirDomingosChanged,
          title: const Text('Omitir domingos'),
          secondary: const Icon(Icons.weekend_rounded),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        _ResumenCreditoAnimado(
          valorController: valorController,
          interesController: interesController,
          plazoController: plazoController,
          frecuencias: frecuencias,
          frecuenciaPagoId: frecuenciaPagoId,
          fechaInicio: fechaInicio,
          omitirDomingos: omitirDomingos,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: observacionController,
          enabled: !guardando,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observacion',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
      ],
    );
  }
}

class _ClienteUbicacionPicker extends StatefulWidget {
  const _ClienteUbicacionPicker({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final LatLng? value;
  final ValueChanged<LatLng?> onChanged;
  final bool enabled;

  @override
  State<_ClienteUbicacionPicker> createState() =>
      _ClienteUbicacionPickerState();
}

class _ClienteUbicacionPickerState extends State<_ClienteUbicacionPicker>
    with SingleTickerProviderStateMixin {
  static const LatLng _riohacha = LatLng(11.5449, -72.9072);

  late final MapcnController _controller;
  LatLng? _value;
  bool _mapReady = false;
  bool _locating = false;
  bool _usingDeviceLocation = false;

  @override
  void initState() {
    super.initState();
    _controller = MapcnController(vsync: this);
    _value = widget.value;
  }

  @override
  void didUpdateWidget(_ClienteUbicacionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final LatLng? value = widget.value;
    if (value == null && oldWidget.value != null) {
      _value = null;
      _usingDeviceLocation = false;
      return;
    }
    if (value != null &&
        (oldWidget.value == null ||
            oldWidget.value!.latitude != value.latitude ||
            oldWidget.value!.longitude != value.longitude)) {
      _controller.flyTo(
        value,
        zoom: 16,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
      _value = value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (!widget.enabled || _locating) {
      return;
    }

    setState(() => _locating = true);
    try {
      final LatLng position =
          await const DeviceRouteLocationService().currentPosition();
      _setValue(position, fromDevice: true);
      _controller.flyTo(
        position,
        zoom: 17,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(_mensajeUbicacionCasa),
          ),
        );
      }
    } on RouteLocationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _markCenter(LatLng center, bool hasGesture) {
    if (!hasGesture || !widget.enabled) {
      return;
    }
    _setValue(center);
  }

  void _setValue(LatLng? value, {bool fromDevice = false}) {
    setState(() {
      _value = value;
      _usingDeviceLocation = value != null && fromDevice;
    });
    widget.onChanged(value);
  }

  String _statusText() {
    final LatLng? value = _value;
    if (value == null) {
      return 'Opcional: usa el localizador o mueve el mapa bajo el pin.';
    }

    final String coordinates =
        '${value.latitude.toStringAsFixed(6)}, ${value.longitude.toStringAsFixed(6)}';
    return _usingDeviceLocation
        ? 'Ubicación actual marcada: $coordinates'
        : coordinates;
  }

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final LatLng center = _value ?? _riohacha;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: clay.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: clay.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Ubicacion en mapa',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                Tooltip(
                  message: _statusText(),
                  child: OutlinedButton.icon(
                    onPressed: widget.enabled && !_locating
                        ? _useCurrentLocation
                        : null,
                    icon: _locating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(_locating ? 'Ubicando' : 'Localizador'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).width < 520 ? 220 : 260,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    AbsorbPointer(
                      absorbing: !widget.enabled,
                      child: Mapcn(
                        controller: _controller,
                        initialCenter: center,
                        initialZoom: _value == null ? 13.5 : 16,
                        style: MapcnStyle.dark,
                        tileUrlTemplate: CobroMapTiles.routeLightUrlTemplate,
                        attributionText: CobroMapTiles.attribution,
                        points: _value == null
                            ? const <LatLng>[]
                            : <LatLng>[_value!],
                        markerConfig: MarkerConfig.minimal,
                        showTooltip: false,
                        showAttribution: true,
                        minZoom: 3,
                        maxZoom: 18,
                        enableTileCaching: true,
                        maxTileCache: 80,
                        onCameraMove: (camera, hasGesture) {
                          _markCenter(camera.center, hasGesture);
                        },
                        onMapReady: () {
                          if (mounted) {
                            setState(() => _mapReady = true);
                          }
                        },
                      ),
                    ),
                    Center(
                      child: Transform.translate(
                        offset: const Offset(0, -18),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: CobroAppTheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!_mapReady)
                      ColoredBox(
                        color: clay.surface.withValues(alpha: 0.72),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _value == null
                        ? 'Opcional: usa el localizador o mueve el mapa bajo el pin.'
                        : _usingDeviceLocation
                            ? 'Ubicación actual marcada: ${_value!.latitude.toStringAsFixed(6)}, ${_value!.longitude.toStringAsFixed(6)}'
                            : '${_value!.latitude.toStringAsFixed(6)}, ${_value!.longitude.toStringAsFixed(6)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: clay.subtleText),
                  ),
                ),
                if (_value != null)
                  TextButton.icon(
                    onPressed: widget.enabled ? () => _setValue(null) : null,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Quitar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogContent extends StatelessWidget {
  const _DialogContent({
    required this.child,
    this.maxWidth = 560,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double horizontalInset = screenSize.width < 360 ? 48 : 80;
    final double width = math.min(
      maxWidth,
      math.max(0, screenSize.width - horizontalInset),
    );
    final double maxHeight = math.max(160, screenSize.height * 0.72);

    return SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _DosColumnas extends StatelessWidget {
  const _DosColumnas({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: <Widget>[
              left,
              const SizedBox(height: 12),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _MovimientoCajaItem extends StatelessWidget {
  const _MovimientoCajaItem({
    required this.movimiento,
    required this.puedeModificar,
    required this.puedeEliminar,
    required this.onModificar,
    required this.onEliminar,
  });

  final MovimientoCaja movimiento;
  final bool puedeModificar;
  final bool puedeEliminar;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final bool salida = movimiento.tipoMovimiento.naturaleza == 'S';
    final bool auditoria = movimiento.esAuditoria;
    final Color color = auditoria
        ? context.clay.subtleText
        : salida
            ? CobroAppTheme.danger
            : CobroAppTheme.success;
    final String? cliente = movimiento.cliente?.trim().isEmpty ?? true
        ? null
        : movimiento.cliente!.trim();
    final String? identificacion =
        movimiento.clienteIdentificacion?.trim().isEmpty ?? true
            ? null
            : movimiento.clienteIdentificacion!.trim();
    final String detalle = <String>[
      if (cliente != null) 'Cliente: $cliente',
      if (identificacion != null) 'Identificacion: $identificacion',
      movimiento.cajaMenor,
      movimiento.tipoMovimiento.nombre,
      _fechaEtiqueta(movimiento.fechaMovimiento),
      if (movimiento.usuario != null) movimiento.usuario!.nombreCompleto,
    ].join(' - ');

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          ClayIcon(
            icon: auditoria
                ? Icons.history_rounded
                : movimiento.esPago
                    ? Icons.payments_rounded
                    : salida
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  movimiento.motivoVisible,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  detalle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.clay.subtleText,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _dinero(movimiento.montoConNaturaleza),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          if ((puedeModificar || puedeEliminar) &&
              movimiento.esEditablePorAdmin) ...<Widget>[
            const SizedBox(width: 4),
            PopupMenuButton<_AccionMovimientoCaja>(
              tooltip: 'Acciones',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (_AccionMovimientoCaja accion) {
                switch (accion) {
                  case _AccionMovimientoCaja.modificar:
                    onModificar();
                  case _AccionMovimientoCaja.eliminar:
                    onEliminar();
                }
              },
              itemBuilder: (BuildContext context) {
                return <PopupMenuEntry<_AccionMovimientoCaja>>[
                  if (puedeModificar)
                    const PopupMenuItem<_AccionMovimientoCaja>(
                      value: _AccionMovimientoCaja.modificar,
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 12),
                          Text('Modificar'),
                        ],
                      ),
                    ),
                  if (puedeEliminar)
                    const PopupMenuItem<_AccionMovimientoCaja>(
                      value: _AccionMovimientoCaja.eliminar,
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.delete_outline_rounded),
                          SizedBox(width: 12),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                ];
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _OrganizacionAdminPicker extends StatelessWidget {
  const _OrganizacionAdminPicker({
    required this.organizaciones,
    required this.controller,
    required this.focusNode,
    required this.seleccionada,
    required this.onChanged,
  });

  final List<OrganizacionAdmin> organizaciones;
  final TextEditingController controller;
  final FocusNode focusNode;
  final OrganizacionAdmin? seleccionada;
  final ValueChanged<OrganizacionAdmin?> onChanged;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<OrganizacionAdmin>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (OrganizacionAdmin option) => option.nombre,
      optionsBuilder: (TextEditingValue value) {
        final String texto = value.text.trim();
        final String consulta = texto.toLowerCase();
        if (consulta.isEmpty ||
            (seleccionada != null && texto == seleccionada!.nombre)) {
          return organizaciones;
        }

        return organizaciones.where((OrganizacionAdmin organizacion) {
          final String nombre = organizacion.nombre.toLowerCase();
          final String correo = (organizacion.correo ?? '').toLowerCase();
          final String administradores =
              organizacion.administradores.join(' ').toLowerCase();
          return nombre.contains(consulta) ||
              correo.contains(consulta) ||
              administradores.contains(consulta);
        });
      },
      onSelected: onChanged,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController controller,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Institucion',
            hintText: 'Buscar por nombre, correo o admin',
            prefixIcon: Icon(Icons.apartment_rounded),
            suffixIcon: Icon(Icons.arrow_drop_down_rounded),
          ),
          onTap: () {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          },
          onChanged: (String value) {
            final String texto = value.trim();
            final bool mantieneSeleccion =
                seleccionada != null && texto == seleccionada!.nombre;
            if (seleccionada != null && !mantieneSeleccion) {
              onChanged(null);
            }
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<OrganizacionAdmin> onSelected,
        Iterable<OrganizacionAdmin> options,
      ) {
        final List<OrganizacionAdmin> opciones =
            options.toList(growable: false);
        final double ancho = math.min(
          460,
          math.max(0, MediaQuery.sizeOf(context).width - 32),
        );

        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: ancho,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: opciones.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No hay instituciones con ese filtro',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: opciones.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final OrganizacionAdmin organizacion =
                              opciones[index];
                          final String detalle = [
                            if ((organizacion.correo ?? '').isNotEmpty)
                              organizacion.correo!,
                            if (organizacion.administradores.isNotEmpty)
                              organizacion.administradores.join(', '),
                          ].join(' · ');

                          return InkWell(
                            onTap: () => onSelected(organizacion),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: CobroAppTheme.primary
                                        .withValues(alpha: 0.12),
                                    foregroundColor: CobroAppTheme.primary,
                                    child: const Icon(
                                      Icons.apartment_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          organizacion.nombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        if (detalle.isNotEmpty)
                                          Text(
                                            detalle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      context.clay.subtleText,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrganizacionAdminItem extends StatelessWidget {
  const _OrganizacionAdminItem({
    required this.organizacion,
    required this.guardando,
    required this.onEditar,
    required this.onActivoChanged,
  });

  final OrganizacionAdmin organizacion;
  final bool guardando;
  final VoidCallback onEditar;
  final ValueChanged<bool> onActivoChanged;

  @override
  Widget build(BuildContext context) {
    final Color estadoColor =
        organizacion.suspendida ? CobroAppTheme.danger : CobroAppTheme.success;
    final String administradores = organizacion.administradores.isEmpty
        ? 'Sin administrador'
        : organizacion.administradores.join(', ');

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: estadoColor.withValues(alpha: 0.12),
                foregroundColor: estadoColor,
                child: Icon(
                  organizacion.suspendida
                      ? Icons.block_rounded
                      : Icons.apartment_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      organizacion.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if ((organizacion.correo ?? '').isNotEmpty)
                          organizacion.correo!,
                        administradores,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.clay.subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                organizacion.estadoTexto,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: estadoColor,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _OrganizacionDato(
                icono: Icons.payments_rounded,
                texto:
                    '${_dinero(organizacion.montoPlan)} ${organizacion.monedaPlan}',
              ),
              _OrganizacionDato(
                icono: Icons.event_available_rounded,
                texto: organizacion.accesoTexto,
              ),
              _OrganizacionDato(
                icono: Icons.group_rounded,
                texto:
                    '${organizacion.usuariosActivos}/${organizacion.usuariosTotal} usuarios',
              ),
              if ((organizacion.motivoSuspension ?? '').isNotEmpty)
                _OrganizacionDato(
                  icono: Icons.info_outline_rounded,
                  texto: organizacion.motivoSuspension!,
                  color: CobroAppTheme.danger,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: guardando ? null : onEditar,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    organizacion.activo ? 'Activa' : 'Suspendida',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: context.clay.subtleText,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: organizacion.activo,
                    onChanged: guardando ? null : onActivoChanged,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrganizacionDato extends StatelessWidget {
  const _OrganizacionDato({
    required this.icono,
    required this.texto,
    this.color,
  });

  final IconData icono;
  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color acento = color ?? Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: acento.withValues(alpha: context.clay.isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icono, size: 16, color: acento),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.clay.text,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClienteItem extends StatelessWidget {
  const _ClienteItem({
    required this.cliente,
    required this.esAdministrador,
    required this.onModificar,
    required this.onEliminar,
  });

  final Cliente cliente;
  final bool esAdministrador;
  final VoidCallback onModificar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final String contacto = [
      if ((cliente.cedula ?? '').isNotEmpty) 'CC ${cliente.cedula!}',
      if ((cliente.direccion ?? '').isNotEmpty) cliente.direccion!,
      if ((cliente.telefono ?? '').isNotEmpty) cliente.telefono!,
      if ((cliente.correo ?? '').isNotEmpty) cliente.correo!,
    ].join(' · ');

    return ClaySurface(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: CobroAppTheme.primary.withValues(alpha: 0.12),
            child: Text(
              cliente.nombreCompleto.isEmpty
                  ? '?'
                  : cliente.nombreCompleto.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: CobroAppTheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  cliente.nombreCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if ((cliente.nombreComercial ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    cliente.nombreComercial!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.clay.subtleText,
                        ),
                  ),
                ],
                if (contacto.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    contacto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.clay.subtleText,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            cliente.estadoNombre,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: CobroAppTheme.success,
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (esAdministrador) ...<Widget>[
            const SizedBox(width: 4),
            PopupMenuButton<_AccionCliente>(
              tooltip: 'Acciones',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (_AccionCliente accion) {
                switch (accion) {
                  case _AccionCliente.modificar:
                    onModificar();
                  case _AccionCliente.eliminar:
                    onEliminar();
                }
              },
              itemBuilder: (BuildContext context) {
                return const <PopupMenuEntry<_AccionCliente>>[
                  PopupMenuItem<_AccionCliente>(
                    value: _AccionCliente.modificar,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('Modificar'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_AccionCliente>(
                    value: _AccionCliente.eliminar,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.delete_outline_rounded),
                        SizedBox(width: 12),
                        Text('Eliminar'),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _GestionEmpleadosPage extends StatefulWidget {
  const _GestionEmpleadosPage({
    required this.apiClient,
    required this.cargarEmpleados,
    required this.cargarActividadEmpleados,
    required this.crearEmpleado,
    required this.modificarEmpleado,
    required this.puedeGestionar,
    required this.mensajeError,
    required this.mostrarMensaje,
    this.embebida = false,
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
  State<_GestionEmpleadosPage> createState() => _GestionEmpleadosPageState();
}

class _GestionEmpleadosPageState extends State<_GestionEmpleadosPage> {
  List<EmpleadoGestion> _empleados = const <EmpleadoGestion>[];
  List<ActividadEmpleado> _actividades = const <ActividadEmpleado>[];
  late DateTime _actividadFechaInicio;
  late DateTime _actividadFechaFin;
  final TextEditingController _buscarActividadEmpleadoController =
      TextEditingController();
  String? _empleadoSeleccionadoId;
  Set<String> _permisosSeleccionados = Set<String>.of(
    _permisosEmpleadoCodigos,
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
    final DateTime ahora = _fechaHoraColombia();
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
      return 'Actividad del ${_fechaEtiqueta(_actividadFechaInicio)}';
    }

    return 'Actividad del ${_fechaEtiqueta(_actividadFechaInicio)} al '
        '${_fechaEtiqueta(_actividadFechaFin)}';
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
      _permisosSeleccionados = Set<String>.of(_permisosEmpleadoCodigos);
      return;
    }

    if (_aplicarATodos) {
      if (resetPermisos) {
        _permisosSeleccionados = Set<String>.of(_permisosEmpleadoCodigos);
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
              Set<String>.of(_permisosEmpleadoCodigos);
    }
  }

  void _seleccionarEmpleado(String? empleadoId) {
    final EmpleadoGestion? empleado = _empleadoPorId(empleadoId);
    setState(() {
      _aplicarATodos = false;
      _empleadoSeleccionadoId = empleado?.id;
      _permisosSeleccionados = empleado == null
          ? Set<String>.of(_permisosEmpleadoCodigos)
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
    final bool esMovil =
        MediaQuery.sizeOf(context).width < _HomePageState._mobileBreakpoint;
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
            child: _EstadoVacio(
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
              _EmpleadoGestionMetrica(
                icono: Icons.groups_rounded,
                etiqueta: 'Empleados',
                valor: _empleados.length.toString(),
              ),
              _EmpleadoGestionMetrica(
                icono: Icons.check_circle_rounded,
                etiqueta: 'Activos',
                valor: activos.toString(),
                color: CobroAppTheme.success,
              ),
              _EmpleadoGestionMetrica(
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
            _MensajePanel(
              icono: Icons.groups_outlined,
              titulo: 'Sin empleados',
              mensaje: 'Agrega un empleado para asignar permisos.',
            )
          else
            ..._empleados.map(
              (EmpleadoGestion empleado) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _EmpleadoGestionItem(
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
                          _permisosEmpleadoCodigos,
                        );
                      } else {
                        _empleadoSeleccionadoId ??= _empleados.first.id;
                        _permisosSeleccionados =
                            _empleadoPorId(_empleadoSeleccionadoId)
                                    ?.permisos
                                    .toSet() ??
                                Set<String>.of(_permisosEmpleadoCodigos);
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
                    ? empleado.nombreCompleto.trim().substring(0, 1).toUpperCase()
                    : '?';
                return CobroDropdownItem<String>(
                  value: empleado.id,
                  label: empleado.nombreCompleto,
                  subtitle:
                      empleado.usuario.isNotEmpty ? '@${empleado.usuario}' : null,
                  avatarText: inicial,
                );
              }).toList(growable: false),
              onChanged: _guardando ? null : _seleccionarEmpleado,
            ),
          ],
          const SizedBox(height: 16),
          if (_empleados.isEmpty)
            _MensajePanel(
              icono: Icons.lock_open_rounded,
              titulo: 'Permisos pendientes',
              mensaje: 'Cuando agregues empleados podras asignar accesos.',
            )
          else
            ..._permisosEmpleado.map(
              (_PermisoEmpleadoDef permiso) => CheckboxListTile(
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
            _MensajePanel(
              icono: Icons.route_outlined,
              titulo: 'Sin actividad',
              mensaje: 'No hay rutas, creditos o recaudos para mostrar.',
            )
          else if (actividades.isEmpty)
            _MensajePanel(
              icono: Icons.search_off_rounded,
              titulo: 'Sin resultados',
              mensaje: 'No hay empleados que coincidan con el filtro.',
            )
          else
            ...actividades.map(
              (ActividadEmpleado actividad) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActividadEmpleadoCard(actividad: actividad),
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
          label: Text('Inicio ${_fechaEtiqueta(_actividadFechaInicio)}'),
        ),
        OutlinedButton.icon(
          onPressed: _cargandoActividad
              ? null
              : () => _seleccionarFechaActividad(esInicio: false),
          icon: const Icon(Icons.event_available_rounded),
          label: Text('Fin ${_fechaEtiqueta(_actividadFechaFin)}'),
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

class _ActividadEmpleadoCard extends StatelessWidget {
  const _ActividadEmpleadoCard({required this.actividad});

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
                _ActividadDato(
                  icono: Icons.payments_rounded,
                  etiqueta: 'Recaudo hoy',
                  valor: _dinero(actividad.resumen.recaudoHoy),
                  color: CobroAppTheme.success,
                ),
                _ActividadDato(
                  icono: Icons.calendar_month_rounded,
                  etiqueta: 'Recaudo mes',
                  valor: _dinero(actividad.resumen.recaudoMes),
                ),
                _ActividadDato(
                  icono: Icons.add_business_rounded,
                  etiqueta: 'Creditos mes',
                  valor: actividad.resumen.creditosMes.toString(),
                ),
                _ActividadDato(
                  icono: Icons.warning_amber_rounded,
                  etiqueta: 'Pendientes',
                  valor: actividad.resumen.pendientesHoy.toString(),
                  color: actividad.resumen.pendientesHoy > 0
                      ? CobroAppTheme.warning
                      : CobroAppTheme.success,
                ),
                _ActividadDato(
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
                      (ActividadRutaEmpleado ruta) => _ActividadRutaRow(
                        ruta: ruta,
                      ),
                    )
                    .toList(growable: false),
              ),
            if (actividad.ultimaActividad != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Ultima actividad ${_fechaHoraEtiqueta(actividad.ultimaActividad)}',
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

class _ActividadDato extends StatelessWidget {
  const _ActividadDato({
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

class _ActividadRutaRow extends StatelessWidget {
  const _ActividadRutaRow({required this.ruta});

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
                    _dinero(ruta.recaudadoHoy),
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

class _EmpleadoGestionMetrica extends StatelessWidget {
  const _EmpleadoGestionMetrica({
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

class _MensajePanel extends StatelessWidget {
  const _MensajePanel({
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

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      width: double.infinity,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      child: Column(
        children: <Widget>[
          Icon(icono, size: 38, color: CobroAppTheme.primary),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.clay.subtleText,
                ),
          ),
          if (accion != null) ...<Widget>[
            const SizedBox(height: 16),
            accion!,
          ],
        ],
      ),
    );
  }
}

class _EmpleadoGestionItem extends StatelessWidget {
  const _EmpleadoGestionItem({
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

class _PermisoEmpleadoDef {
  const _PermisoEmpleadoDef({
    required this.codigo,
    required this.nombre,
  });

  final String codigo;
  final String nombre;
}

enum _AccionSesion {
  recargar,
  cambiarTema,
  sincronizarPendientes,
  gestionEmpleados,
  cerrarSesion,
}

enum _FiltroMovimientoCaja {
  todos,
  entradas,
  salidas,
}

enum _FiltroEstadoRuta {
  todos,
  alDia,
  pendiente,
  atrasado,
  pagado;

  EstadoCobro? get estadoCobro {
    return switch (this) {
      _FiltroEstadoRuta.todos => null,
      _FiltroEstadoRuta.alDia => EstadoCobro.alDia,
      _FiltroEstadoRuta.pendiente => EstadoCobro.pendiente,
      _FiltroEstadoRuta.atrasado => EstadoCobro.atrasado,
      _FiltroEstadoRuta.pagado => EstadoCobro.pagado,
    };
  }

  String? get wire {
    return switch (this) {
      _FiltroEstadoRuta.todos => null,
      _FiltroEstadoRuta.alDia => 'AL_DIA',
      _FiltroEstadoRuta.pendiente => 'PENDIENTE',
      _FiltroEstadoRuta.atrasado => 'ATRASADO',
      _FiltroEstadoRuta.pagado => 'PAGADO',
    };
  }
}

enum _FiltroEstadoCredito {
  todos,
  activos,
  inactivos,
}

enum _AccionCredito {
  modificar,
  eliminar,
}

enum _AccionCliente {
  modificar,
  eliminar,
}

enum _AccionMovimientoCaja {
  modificar,
  eliminar,
}

class ExportacionExcel {
  const ExportacionExcel({
    required this.archivo,
    required this.key,
    required this.url,
    required this.filas,
    required this.generadoEn,
    required this.vistaPrevia,
  });

  factory ExportacionExcel.fromJson(Map<String, dynamic> json) {
    return ExportacionExcel(
      archivo: json['archivo'] as String,
      key: json['key'] as String? ?? '',
      url: json['url'] as String,
      filas: _enteroJson(json['filas']),
      generadoEn: _fechaNullable(json['generadoEn']),
      vistaPrevia: ExportacionVistaPrevia.fromJson(json['vistaPrevia']),
    );
  }

  final String archivo;
  final String key;
  final String url;
  final int filas;
  final DateTime? generadoEn;
  final ExportacionVistaPrevia vistaPrevia;
}

class ExportacionVistaPrevia {
  const ExportacionVistaPrevia({
    required this.columnas,
    required this.filas,
  });

  factory ExportacionVistaPrevia.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const ExportacionVistaPrevia(
        columnas: <String>[],
        filas: <List<Object?>>[],
      );
    }

    final Object? columnasRaw = json['columnas'];
    final Object? filasRaw = json['filas'];

    return ExportacionVistaPrevia(
      columnas: columnasRaw is List<dynamic>
          ? columnasRaw.map((Object? value) => value.toString()).toList()
          : const <String>[],
      filas: filasRaw is List<dynamic>
          ? filasRaw
              .whereType<List<dynamic>>()
              .map((List<dynamic> fila) => List<Object?>.from(fila))
              .toList()
          : const <List<Object?>>[],
    );
  }

  final List<String> columnas;
  final List<List<Object?>> filas;
}

class Sesion {
  const Sesion({required this.token, required this.usuario});

  factory Sesion.fromJson(Map<String, dynamic> json) {
    return Sesion(
      token: json['token'] as String,
      usuario: SesionUsuario.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }

  final String token;
  final SesionUsuario usuario;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'token': token,
      'usuario': usuario.toJson(),
    };
  }
}

class SesionUsuario {
  const SesionUsuario({
    required this.id,
    required this.usuario,
    required this.nombreCompleto,
    required this.correo,
    required this.roles,
    required this.esAdministrador,
    required this.esSuperAdmin,
    required this.permisos,
    required this.activo,
  });

  factory SesionUsuario.fromJson(Map<String, dynamic> json) {
    final Object? rawRoles = json['roles'];
    final Object? rawPermisos = json['permisos'];
    final bool esAdministrador = json['esAdministrador'] as bool? ?? false;
    final List<String> permisos = rawPermisos is List<dynamic>
        ? rawPermisos.whereType<String>().toList(growable: false)
        : esAdministrador
            ? _permisosEmpleadoCodigos
            : const <String>[];

    return SesionUsuario(
      id: json['id'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      correo: json['correo'] as String,
      roles: rawRoles is List<dynamic>
          ? rawRoles.whereType<String>().toList(growable: false)
          : const <String>[],
      esAdministrador: esAdministrador,
      esSuperAdmin: json['esSuperAdmin'] as bool? ?? false,
      permisos: permisos,
      activo: json['activo'] as bool? ?? true,
    );
  }

  final String id;
  final String usuario;
  final String nombreCompleto;
  final String correo;
  final List<String> roles;
  final bool esAdministrador;
  final bool esSuperAdmin;
  final List<String> permisos;
  final bool activo;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'usuario': usuario,
      'nombreCompleto': nombreCompleto,
      'correo': correo,
      'roles': roles,
      'esAdministrador': esAdministrador,
      'esSuperAdmin': esSuperAdmin,
      'permisos': permisos,
      'activo': activo,
    };
  }

  bool puede(String permiso) {
    return esAdministrador || permisos.contains(permiso);
  }
}

class OrganizacionAdmin {
  const OrganizacionAdmin({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.correo,
    required this.activo,
    required this.esSistema,
    required this.montoPlan,
    required this.monedaPlan,
    required this.accesoHasta,
    required this.suspendidaEn,
    required this.motivoSuspension,
    required this.suspendida,
    required this.diasRestantes,
    required this.usuariosTotal,
    required this.usuariosActivos,
    required this.administradores,
  });

  factory OrganizacionAdmin.fromJson(Map<String, dynamic> json) {
    final Object? rawAdministradores = json['administradores'];
    return OrganizacionAdmin(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String?,
      correo: json['correo'] as String?,
      activo: json['activo'] as bool? ?? true,
      esSistema: json['esSistema'] as bool? ?? false,
      montoPlan: _doble(json['montoPlan']),
      monedaPlan: json['monedaPlan'] as String? ?? 'COP',
      accesoHasta: json['accesoHasta'] as String?,
      suspendidaEn: json['suspendidaEn'] as String?,
      motivoSuspension: json['motivoSuspension'] as String?,
      suspendida: json['suspendida'] as bool? ?? false,
      diasRestantes: _enteroNullableJson(json['diasRestantes']),
      usuariosTotal: _enteroJson(json['usuariosTotal']),
      usuariosActivos: _enteroJson(json['usuariosActivos']),
      administradores: rawAdministradores is List<dynamic>
          ? rawAdministradores.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  final String id;
  final String nombre;
  final String? telefono;
  final String? correo;
  final bool activo;
  final bool esSistema;
  final double montoPlan;
  final String monedaPlan;
  final String? accesoHasta;
  final String? suspendidaEn;
  final String? motivoSuspension;
  final bool suspendida;
  final int? diasRestantes;
  final int usuariosTotal;
  final int usuariosActivos;
  final List<String> administradores;

  String get estadoTexto {
    if (suspendida) {
      return 'Suspendida';
    }
    if (diasRestantes == null) {
      return 'Activa';
    }
    if (diasRestantes == 0) {
      return 'Vence hoy';
    }
    return 'Activa';
  }

  String get accesoTexto {
    if (accesoHasta == null) {
      return 'Sin vencimiento';
    }
    final int? dias = diasRestantes;
    if (dias == null) {
      return accesoHasta!;
    }
    if (dias < 0) {
      return '$accesoHasta (${dias.abs()} dias vencida)';
    }
    if (dias == 0) {
      return '$accesoHasta (vence hoy)';
    }
    return '$accesoHasta ($dias dias)';
  }
}

class EmpleadoGestion {
  const EmpleadoGestion({
    required this.id,
    required this.usuario,
    required this.nombreCompleto,
    required this.correo,
    required this.permisos,
    required this.activo,
  });

  factory EmpleadoGestion.fromJson(Map<String, dynamic> json) {
    final Object? rawPermisos = json['permisos'];
    return EmpleadoGestion(
      id: json['id'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      correo: json['correo'] as String,
      permisos: rawPermisos is List<dynamic>
          ? rawPermisos.whereType<String>().toList(growable: false)
          : const <String>[],
      activo: json['activo'] as bool? ?? true,
    );
  }

  final String id;
  final String usuario;
  final String nombreCompleto;
  final String correo;
  final List<String> permisos;
  final bool activo;
}

class ActividadEmpleadosFiltros {
  const ActividadEmpleadosFiltros({
    required this.fechaInicio,
    required this.fechaFin,
    this.empleadoId,
  });

  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? empleadoId;

  Map<String, String?> toQuery() {
    return <String, String?>{
      'inicio': _fechaValor(fechaInicio),
      'fin': _fechaValor(fechaFin),
      'empleadoId': empleadoId,
    };
  }
}

enum EstadoActividadEmpleado {
  cumplido,
  pendiente,
  sinRutaHoy;

  factory EstadoActividadEmpleado.fromWire(String? value) {
    return switch (value) {
      'CUMPLIDO' => EstadoActividadEmpleado.cumplido,
      'PENDIENTE' => EstadoActividadEmpleado.pendiente,
      _ => EstadoActividadEmpleado.sinRutaHoy,
    };
  }
}

class ActividadEmpleado {
  const ActividadEmpleado({
    required this.empleadoId,
    required this.usuario,
    required this.nombreCompleto,
    required this.correo,
    required this.activo,
    required this.estadoRuta,
    required this.porcentajeCumplimiento,
    required this.rutas,
    required this.resumen,
    this.ultimaActividad,
  });

  factory ActividadEmpleado.fromJson(Map<String, dynamic> json) {
    final Object? rawResumen = json['resumen'];
    return ActividadEmpleado(
      empleadoId: json['empleadoId'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      correo: json['correo'] as String,
      activo: json['activo'] as bool? ?? true,
      estadoRuta:
          EstadoActividadEmpleado.fromWire(json['estadoRuta'] as String?),
      porcentajeCumplimiento: math.max(
        0,
        math.min(100, _enteroJson(json['porcentajeCumplimiento'])),
      ),
      rutas: _lista(json['rutas'])
          .map(ActividadRutaEmpleado.fromJson)
          .toList(growable: false),
      resumen: rawResumen is Map<String, dynamic>
          ? ActividadEmpleadoResumen.fromJson(rawResumen)
          : const ActividadEmpleadoResumen.vacio(),
      ultimaActividad: _fechaNullable(json['ultimaActividad']),
    );
  }

  final String empleadoId;
  final String usuario;
  final String nombreCompleto;
  final String correo;
  final bool activo;
  final EstadoActividadEmpleado estadoRuta;
  final int porcentajeCumplimiento;
  final List<ActividadRutaEmpleado> rutas;
  final ActividadEmpleadoResumen resumen;
  final DateTime? ultimaActividad;
}

class ActividadEmpleadoResumen {
  const ActividadEmpleadoResumen({
    required this.totalCreditos,
    required this.creditosHoy,
    required this.creditosMes,
    required this.valorCreditosTotal,
    required this.recaudoHoy,
    required this.recaudoMes,
    required this.pagosHoy,
    required this.deberesHoy,
    required this.cumplidosHoy,
    required this.pendientesHoy,
    required this.atrasados,
  });

  const ActividadEmpleadoResumen.vacio()
      : totalCreditos = 0,
        creditosHoy = 0,
        creditosMes = 0,
        valorCreditosTotal = 0,
        recaudoHoy = 0,
        recaudoMes = 0,
        pagosHoy = 0,
        deberesHoy = 0,
        cumplidosHoy = 0,
        pendientesHoy = 0,
        atrasados = 0;

  factory ActividadEmpleadoResumen.fromJson(Map<String, dynamic> json) {
    return ActividadEmpleadoResumen(
      totalCreditos: _enteroJson(json['totalCreditos']),
      creditosHoy: _enteroJson(json['creditosHoy']),
      creditosMes: _enteroJson(json['creditosMes']),
      valorCreditosTotal: _doble(json['valorCreditosTotal']),
      recaudoHoy: _doble(json['recaudoHoy']),
      recaudoMes: _doble(json['recaudoMes']),
      pagosHoy: _enteroJson(json['pagosHoy']),
      deberesHoy: _enteroJson(json['deberesHoy']),
      cumplidosHoy: _enteroJson(json['cumplidosHoy']),
      pendientesHoy: _enteroJson(json['pendientesHoy']),
      atrasados: _enteroJson(json['atrasados']),
    );
  }

  final int totalCreditos;
  final int creditosHoy;
  final int creditosMes;
  final double valorCreditosTotal;
  final double recaudoHoy;
  final double recaudoMes;
  final int pagosHoy;
  final int deberesHoy;
  final int cumplidosHoy;
  final int pendientesHoy;
  final int atrasados;
}

class ActividadRutaEmpleado {
  const ActividadRutaEmpleado({
    required this.rutaId,
    required this.nombre,
    required this.creditos,
    required this.clientes,
    required this.debenHoy,
    required this.cumplidosHoy,
    required this.pendientesHoy,
    required this.atrasados,
    required this.recaudadoHoy,
  });

  factory ActividadRutaEmpleado.fromJson(Map<String, dynamic> json) {
    return ActividadRutaEmpleado(
      rutaId: json['rutaId'] as String? ?? '',
      nombre: json['nombre'] as String? ?? 'Ruta',
      creditos: _enteroJson(json['creditos']),
      clientes: _enteroJson(json['clientes']),
      debenHoy: _enteroJson(json['debenHoy']),
      cumplidosHoy: _enteroJson(json['cumplidosHoy']),
      pendientesHoy: _enteroJson(json['pendientesHoy']),
      atrasados: _enteroJson(json['atrasados']),
      recaudadoHoy: _doble(json['recaudadoHoy']),
    );
  }

  final String rutaId;
  final String nombre;
  final int creditos;
  final int clientes;
  final int debenHoy;
  final int cumplidosHoy;
  final int pendientesHoy;
  final int atrasados;
  final double recaudadoHoy;
}

class Catalogos {
  const Catalogos({
    required this.monedas,
    required this.frecuenciasPago,
    required this.mediosPago,
    required this.tiposMovimientoCaja,
    required this.rutas,
    required this.cajasMenores,
    required this.usuarios,
  });

  factory Catalogos.fromJson(Map<String, dynamic> json) {
    return Catalogos(
      monedas:
          _lista(json['monedas']).map(Moneda.fromJson).toList(growable: false),
      frecuenciasPago: _lista(json['frecuenciasPago'])
          .map(FrecuenciaPago.fromJson)
          .toList(growable: false),
      mediosPago: _lista(json['mediosPago'])
          .map(MedioPago.fromJson)
          .toList(growable: false),
      tiposMovimientoCaja: _lista(json['tiposMovimientoCaja'])
          .map(TipoMovimientoCaja.fromJson)
          .toList(growable: false),
      rutas: _lista(json['rutas'])
          .map(RutaCatalogo.fromJson)
          .toList(growable: false),
      cajasMenores: _lista(json['cajasMenores'])
          .map(CajaMenorCatalogo.fromJson)
          .toList(growable: false),
      usuarios: _lista(json['usuarios'])
          .map(UsuarioCatalogo.fromJson)
          .toList(growable: false),
    );
  }

  final List<Moneda> monedas;
  final List<FrecuenciaPago> frecuenciasPago;
  final List<MedioPago> mediosPago;
  final List<TipoMovimientoCaja> tiposMovimientoCaja;
  final List<RutaCatalogo> rutas;
  final List<CajaMenorCatalogo> cajasMenores;
  final List<UsuarioCatalogo> usuarios;

  Catalogos copyWith({
    List<Moneda>? monedas,
    List<FrecuenciaPago>? frecuenciasPago,
    List<MedioPago>? mediosPago,
    List<TipoMovimientoCaja>? tiposMovimientoCaja,
    List<RutaCatalogo>? rutas,
    List<CajaMenorCatalogo>? cajasMenores,
    List<UsuarioCatalogo>? usuarios,
  }) {
    return Catalogos(
      monedas: monedas ?? this.monedas,
      frecuenciasPago: frecuenciasPago ?? this.frecuenciasPago,
      mediosPago: mediosPago ?? this.mediosPago,
      tiposMovimientoCaja: tiposMovimientoCaja ?? this.tiposMovimientoCaja,
      rutas: rutas ?? this.rutas,
      cajasMenores: cajasMenores ?? this.cajasMenores,
      usuarios: usuarios ?? this.usuarios,
    );
  }

  List<RutaCatalogo> get rutasAbiertas => rutas
      .where((RutaCatalogo ruta) => ruta.estadoCodigo == 'ABIERTA')
      .toList(growable: false);

  List<CajaMenorCatalogo> get cajasMenoresActivas => cajasMenores
      .where((CajaMenorCatalogo caja) => caja.estaAbierta)
      .toList(growable: false);
}

class UsuarioCatalogo {
  const UsuarioCatalogo({
    required this.id,
    required this.nombreCompleto,
    this.usuario = '',
  });

  factory UsuarioCatalogo.fromJson(Map<String, dynamic> json) {
    return UsuarioCatalogo(
      id: json['id'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      usuario: (json['usuario'] as String?) ?? '',
    );
  }

  final String id;
  final String nombreCompleto;
  final String usuario;
}

class Moneda {
  const Moneda({required this.codigo, required this.nombre});

  factory Moneda.fromJson(Map<String, dynamic> json) {
    return Moneda(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );
  }

  final String codigo;
  final String nombre;
}

class FrecuenciaPago {
  const FrecuenciaPago({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.diasIntervalo,
  });

  factory FrecuenciaPago.fromJson(Map<String, dynamic> json) {
    return FrecuenciaPago(
      id: _enteroJson(json['id']),
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      diasIntervalo: _enteroJson(json['diasIntervalo']),
    );
  }

  final int id;
  final String codigo;
  final String nombre;
  final int diasIntervalo;
}

class MedioPago {
  const MedioPago({required this.codigo, required this.nombre});

  factory MedioPago.fromJson(Map<String, dynamic> json) {
    return MedioPago(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );
  }

  final String codigo;
  final String nombre;
}

class TipoMovimientoCaja {
  const TipoMovimientoCaja({
    required this.codigo,
    required this.nombre,
    required this.naturaleza,
  });

  factory TipoMovimientoCaja.fromJson(Map<String, dynamic> json) {
    return TipoMovimientoCaja(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      naturaleza: json['naturaleza'] as String,
    );
  }

  final String codigo;
  final String nombre;
  final String naturaleza;
}

class RutaCatalogo {
  const RutaCatalogo({
    required this.id,
    required this.nombre,
    required this.estadoCodigo,
  });

  factory RutaCatalogo.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> estado = json['estado'] as Map<String, dynamic>;
    return RutaCatalogo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      estadoCodigo: estado['codigo'] as String,
    );
  }

  final String id;
  final String nombre;
  final String estadoCodigo;
}

class CajaMenorCatalogo {
  const CajaMenorCatalogo({
    required this.id,
    required this.nombre,
    required this.activa,
    required this.monedaCodigo,
    this.fechaApertura,
    this.fechaCierre,
    this.responsable,
  });

  factory CajaMenorCatalogo.fromJson(Map<String, dynamic> json) {
    return CajaMenorCatalogo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      activa: json['activa'] as bool,
      monedaCodigo: (json['monedaCodigo'] as String?) ?? 'COP',
      fechaApertura: _fechaNullable(json['fechaApertura']),
      fechaCierre: _fechaNullable(json['fechaCierre']),
      responsable: json['responsable'] is Map<String, dynamic>
          ? UsuarioCatalogo.fromJson(
              json['responsable'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String id;
  final String nombre;
  final bool activa;
  final String monedaCodigo;
  final DateTime? fechaApertura;
  final DateTime? fechaCierre;
  final UsuarioCatalogo? responsable;

  bool get estaAbierta {
    if (!activa) {
      return false;
    }
    if (fechaCierre != null && !fechaCierre!.isAfter(DateTime.now())) {
      return false;
    }
    return true;
  }
}

class Cliente {
  const Cliente({
    required this.id,
    required this.nombreCompleto,
    required this.estadoNombre,
    this.cedula,
    this.direccion,
    this.nombreComercial,
    this.correo,
    this.telefono,
    this.latitude,
    this.longitude,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> estado = json['estado'] as Map<String, dynamic>;
    final Object? rawDirecciones = json['direcciones'];
    Map<String, dynamic>? direccionPrincipal;
    if (rawDirecciones is List) {
      for (final Object? item in rawDirecciones) {
        if (item is Map<String, dynamic> && item['esPrincipal'] == true) {
          direccionPrincipal = item;
          break;
        }
      }
      if (direccionPrincipal == null && rawDirecciones.isNotEmpty) {
        final Object? first = rawDirecciones.first;
        if (first is Map<String, dynamic>) {
          direccionPrincipal = first;
        }
      }
    }
    return Cliente(
      id: json['id'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      cedula: json['cedula'] as String?,
      direccion: json['direccion'] as String?,
      nombreComercial: json['nombreComercial'] as String?,
      correo: json['correo'] as String?,
      telefono: json['telefono'] as String?,
      estadoNombre: estado['nombre'] as String,
      latitude:
          _dobleNullable(json['latitud'] ?? direccionPrincipal?['latitud']),
      longitude:
          _dobleNullable(json['longitud'] ?? direccionPrincipal?['longitud']),
    );
  }

  final String id;
  final String nombreCompleto;
  final String? cedula;
  final String? direccion;
  final String? nombreComercial;
  final String? correo;
  final String? telefono;
  final double? latitude;
  final double? longitude;
  final String estadoNombre;

  bool get tieneUbicacion {
    final double? latitud = latitude;
    final double? longitud = longitude;
    return latitud != null &&
        longitud != null &&
        latitud.isFinite &&
        longitud.isFinite &&
        latitud >= -90 &&
        latitud <= 90 &&
        longitud >= -180 &&
        longitud <= 180;
  }
}

class CreditoRegistro {
  const CreditoRegistro({
    required this.id,
    required this.clienteId,
    required this.cliente,
    required this.rutaId,
    required this.ruta,
    required this.monedaCodigo,
    required this.frecuenciaPago,
    required this.estado,
    required this.fechaInicio,
    required this.valorPrincipal,
    required this.porcentajeInteres,
    required this.plazoDias,
    required this.omitirDomingos,
    required this.valorTotal,
    required this.valorCuota,
    required this.totalAbonado,
    required this.saldo,
    required this.numeroCuotas,
    required this.cuotasRestantes,
    required this.fechaMaxima,
    this.cedula,
    this.negocio,
    this.direccion,
    this.cajaMenorId,
    this.cajaMenor,
    this.refinanciacion,
    this.observacion,
    this.creadoEn,
    this.actualizadoEn,
  });

  factory CreditoRegistro.fromJson(Map<String, dynamic> json) {
    final Object? refinanciacion = json['refinanciacion'];
    return CreditoRegistro(
      id: json['id'] as String,
      clienteId: json['clienteId'] as String,
      cliente: json['cliente'] as String,
      cedula: json['cedula'] as String?,
      negocio: json['negocio'] as String?,
      direccion: json['direccion'] as String?,
      rutaId: json['rutaId'] as String? ?? '',
      ruta: json['ruta'] as String? ?? 'Sin ruta',
      cajaMenorId: json['cajaMenorId'] as String?,
      cajaMenor: json['cajaMenor'] as String?,
      monedaCodigo: json['monedaCodigo'] as String? ?? 'COP',
      frecuenciaPago: FrecuenciaPago.fromJson(
        json['frecuenciaPago'] as Map<String, dynamic>,
      ),
      estado: EstadoCreditoRegistro.fromJson(
        json['estado'] as Map<String, dynamic>,
      ),
      fechaInicio: DateTime.parse(json['fechaInicio'] as String),
      valorPrincipal: _doble(json['valorPrincipal']),
      porcentajeInteres: _doble(json['porcentajeInteres']),
      plazoDias: _enteroJson(json['plazoDias']),
      omitirDomingos: json['omitirDomingos'] as bool? ?? true,
      valorTotal: _doble(json['valorTotal']),
      valorCuota: _doble(json['valorCuota']),
      totalAbonado: _doble(json['totalAbonado']),
      saldo: _doble(json['saldo']),
      numeroCuotas: _enteroJson(json['numeroCuotas']),
      cuotasRestantes: _enteroJson(json['cuotasRestantes']),
      fechaMaxima: DateTime.parse(json['fechaMaxima'] as String),
      refinanciacion: refinanciacion is Map<String, dynamic>
          ? CreditoRefinanciacion.fromJson(refinanciacion)
          : null,
      observacion: json['observacion'] as String?,
      creadoEn: _fechaNullable(json['creadoEn']),
      actualizadoEn: _fechaNullable(json['actualizadoEn']),
    );
  }

  final String id;
  final String clienteId;
  final String cliente;
  final String? cedula;
  final String? negocio;
  final String? direccion;
  final String rutaId;
  final String ruta;
  final String? cajaMenorId;
  final String? cajaMenor;
  final String monedaCodigo;
  final FrecuenciaPago frecuenciaPago;
  final EstadoCreditoRegistro estado;
  final DateTime fechaInicio;
  final double valorPrincipal;
  final double porcentajeInteres;
  final int plazoDias;
  final bool omitirDomingos;
  final double valorTotal;
  final double valorCuota;
  final double totalAbonado;
  final double saldo;
  final int numeroCuotas;
  final int cuotasRestantes;
  final DateTime fechaMaxima;
  final CreditoRefinanciacion? refinanciacion;
  final String? observacion;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  bool get pagado =>
      estado.codigo == 'PAGADO' || saldo <= 0.009 || cuotasRestantes <= 0;

  bool get activo => estado.codigo == 'ACTIVO';

  bool get inactivo => estado.codigo == 'PAGADO';

  DateTime? get fechaModificacionVisible {
    final DateTime? actualizado = actualizadoEn;
    if (actualizado == null) {
      return null;
    }

    final DateTime? creado = creadoEn;
    if (creado == null) {
      return actualizado;
    }

    if (actualizado.difference(creado).abs() <= const Duration(seconds: 1)) {
      return null;
    }

    return actualizado;
  }

  static const Object _sinCambio = Object();

  CreditoRegistro copyWith({
    String? clienteId,
    String? cliente,
    Object? cedula = _sinCambio,
    Object? negocio = _sinCambio,
    Object? direccion = _sinCambio,
    String? rutaId,
    String? ruta,
    Object? cajaMenorId = _sinCambio,
    Object? cajaMenor = _sinCambio,
    String? monedaCodigo,
    FrecuenciaPago? frecuenciaPago,
    EstadoCreditoRegistro? estado,
    DateTime? fechaInicio,
    double? valorPrincipal,
    double? porcentajeInteres,
    int? plazoDias,
    bool? omitirDomingos,
    double? valorTotal,
    double? valorCuota,
    double? totalAbonado,
    double? saldo,
    int? numeroCuotas,
    int? cuotasRestantes,
    DateTime? fechaMaxima,
    Object? refinanciacion = _sinCambio,
    Object? observacion = _sinCambio,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return CreditoRegistro(
      id: id,
      clienteId: clienteId ?? this.clienteId,
      cliente: cliente ?? this.cliente,
      cedula: identical(cedula, _sinCambio) ? this.cedula : cedula as String?,
      negocio:
          identical(negocio, _sinCambio) ? this.negocio : negocio as String?,
      direccion: identical(direccion, _sinCambio)
          ? this.direccion
          : direccion as String?,
      rutaId: rutaId ?? this.rutaId,
      ruta: ruta ?? this.ruta,
      cajaMenorId: identical(cajaMenorId, _sinCambio)
          ? this.cajaMenorId
          : cajaMenorId as String?,
      cajaMenor: identical(cajaMenor, _sinCambio)
          ? this.cajaMenor
          : cajaMenor as String?,
      monedaCodigo: monedaCodigo ?? this.monedaCodigo,
      frecuenciaPago: frecuenciaPago ?? this.frecuenciaPago,
      estado: estado ?? this.estado,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      valorPrincipal: valorPrincipal ?? this.valorPrincipal,
      porcentajeInteres: porcentajeInteres ?? this.porcentajeInteres,
      plazoDias: plazoDias ?? this.plazoDias,
      omitirDomingos: omitirDomingos ?? this.omitirDomingos,
      valorTotal: valorTotal ?? this.valorTotal,
      valorCuota: valorCuota ?? this.valorCuota,
      totalAbonado: totalAbonado ?? this.totalAbonado,
      saldo: saldo ?? this.saldo,
      numeroCuotas: numeroCuotas ?? this.numeroCuotas,
      cuotasRestantes: cuotasRestantes ?? this.cuotasRestantes,
      fechaMaxima: fechaMaxima ?? this.fechaMaxima,
      refinanciacion: identical(refinanciacion, _sinCambio)
          ? this.refinanciacion
          : refinanciacion as CreditoRefinanciacion?,
      observacion: identical(observacion, _sinCambio)
          ? this.observacion
          : observacion as String?,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }
}

class EstadoCreditoRegistro {
  const EstadoCreditoRegistro({required this.codigo, required this.nombre});

  factory EstadoCreditoRegistro.fromJson(Map<String, dynamic> json) {
    return EstadoCreditoRegistro(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );
  }

  final String codigo;
  final String nombre;
}

class CreditoRefinanciacion {
  const CreditoRefinanciacion({
    required this.fecha,
    required this.valorAnterior,
    required this.valorNuevo,
  });

  factory CreditoRefinanciacion.fromJson(Map<String, dynamic> json) {
    return CreditoRefinanciacion(
      fecha: DateTime.parse(json['fecha'] as String),
      valorAnterior: _doble(json['valorAnterior']),
      valorNuevo: _doble(json['valorNuevo']),
    );
  }

  final DateTime fecha;
  final double valorAnterior;
  final double valorNuevo;
}

class _SelectorCobroRutaBuscable extends StatefulWidget {
  const _SelectorCobroRutaBuscable({
    required this.cobros,
    required this.cuotasSeleccionadas,
    required this.enabled,
    required this.onSelected,
  });

  final List<CobroRuta> cobros;
  final Set<String> cuotasSeleccionadas;
  final bool enabled;
  final ValueChanged<CobroRuta> onSelected;

  @override
  State<_SelectorCobroRutaBuscable> createState() =>
      _SelectorCobroRutaBuscableState();
}

class _SelectorCobroRutaBuscableState
    extends State<_SelectorCobroRutaBuscable> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _controller.addListener(_actualizarBusqueda);
  }

  @override
  void dispose() {
    _controller.removeListener(_actualizarBusqueda);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _actualizarBusqueda() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final String consulta = _controller.text.trim().toLowerCase();
    final List<CobroRuta> opciones = widget.cobros.where((CobroRuta cobro) {
      if (cobro.proximaCuotaId == null ||
          widget.cuotasSeleccionadas.contains(cobro.proximaCuotaId)) {
        return false;
      }

      if (consulta.isEmpty) {
        return true;
      }

      return cobro.cliente.toLowerCase().contains(consulta) ||
          (cobro.cedula ?? '').toLowerCase().contains(consulta) ||
          (cobro.negocio ?? '').toLowerCase().contains(consulta) ||
          cobro.ruta.toLowerCase().contains(consulta);
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Buscar y agregar cliente',
            prefixIcon: const Icon(Icons.person_search_rounded),
            suffixIcon: _controller.text.isEmpty
                ? const Icon(Icons.list_alt_rounded)
                : IconButton(
                    tooltip: 'Limpiar busqueda',
                    onPressed: widget.enabled ? _controller.clear : null,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
          onSubmitted: (_) {
            if (widget.enabled && opciones.isNotEmpty) {
              _seleccionar(opciones.first);
            }
          },
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: clay.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: clay.border),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: opciones.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      consulta.isEmpty
                          ? 'Todos los clientes pendientes ya estan agregados'
                          : 'Sin clientes pendientes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: clay.subtleText,
                          ),
                    ),
                  )
                : SizedBox(
                    height: math.min(
                      280.0,
                      math.max(72.0, opciones.length * 64.0),
                    ),
                    child: Scrollbar(
                      controller: _scrollController,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: opciones.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final CobroRuta cobro = opciones[index];
                          return ListTile(
                            dense: true,
                            enabled: widget.enabled,
                            leading: const Icon(Icons.person_add_alt_1_rounded),
                            title: Text(
                              cobro.cliente,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if ((cobro.cedula ?? '').isNotEmpty)
                                  'CC ${cobro.cedula!}',
                                cobro.ruta,
                                'Cuota ${cobro.proximaNumeroCuota ?? '-'}',
                                _dinero(cobro.proximoSaldoCuota),
                              ].join(' - '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: widget.enabled
                                ? () => _seleccionar(cobro)
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _seleccionar(CobroRuta cobro) {
    widget.onSelected(cobro);
    _controller.clear();
    _focusNode.requestFocus();
  }
}

class _SelectorMedioPagoBuscable extends StatelessWidget {
  const _SelectorMedioPagoBuscable({
    required this.mediosPago,
    required this.medioPagoCodigo,
    required this.enabled,
    required this.onChanged,
  });

  final List<MedioPago> mediosPago;
  final String medioPagoCodigo;
  final bool enabled;
  final ValueChanged<String> onChanged;

  static IconData _iconoMedioPago(String codigo) {
    switch (codigo.toUpperCase()) {
      case 'EFECTIVO':
        return Icons.payments_rounded;
      case 'TRANSFERENCIA':
        return Icons.account_balance_rounded;
      case 'TARJETA':
        return Icons.credit_card_rounded;
      case 'BILLETERA':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  static Color _colorMedioPago(String codigo) {
    switch (codigo.toUpperCase()) {
      case 'EFECTIVO':
        return const Color(0xFF10B981);
      case 'TRANSFERENCIA':
        return const Color(0xFF3B82F6);
      case 'TARJETA':
        return const Color(0xFF8B5CF6);
      case 'BILLETERA':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  static String _subtituloMedioPago(String codigo, String nombre) {
    switch (codigo.toUpperCase()) {
      case 'EFECTIVO':
        return 'Dinero en efectivo';
      case 'TRANSFERENCIA':
        return 'Transferencia bancaria';
      case 'TARJETA':
        return 'Tarjeta debito o credito';
      case 'BILLETERA':
        return 'Billetera digital (Nequi, Daviplata)';
      default:
        return 'Codigo: $codigo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool codigoValido =
        mediosPago.any((MedioPago m) => m.codigo == medioPagoCodigo);
    final String? valorActual = codigoValido
        ? medioPagoCodigo
        : (mediosPago.isNotEmpty ? mediosPago.first.codigo : null);

    return CobroDropdownField<String>(
      key: ValueKey<String?>('medio-pago-$valorActual'),
      labelText: 'Medio de pago',
      hintText: 'Selecciona medio de pago',
      prefixIcon: const Icon(Icons.payment_rounded),
      value: valorActual,
      enabled: enabled && mediosPago.isNotEmpty,
      menuWidth: 440,
      items: mediosPago.map((MedioPago medio) {
        return CobroDropdownItem<String>(
          value: medio.codigo,
          label: medio.nombre,
          subtitle: _subtituloMedioPago(medio.codigo, medio.nombre),
          icon: _iconoMedioPago(medio.codigo),
          iconColor: _colorMedioPago(medio.codigo),
        );
      }).toList(growable: false),
      onChanged: enabled
          ? (String? valor) {
              if (valor != null) {
                onChanged(valor);
              }
            }
          : null,
    );
  }
}


class _PagoRutaSolicitud {
  const _PagoRutaSolicitud({
    required this.cuotaId,
    required this.monto,
    required this.medioPagoCodigo,
    this.observacion,
  });

  final String cuotaId;
  final double monto;
  final String medioPagoCodigo;
  final String? observacion;
}

class _PagoRutaSeleccion {
  _PagoRutaSeleccion(this.cobro)
      : montoController =
            TextEditingController(text: _numero(cobro.proximoSaldoCuota));

  final CobroRuta cobro;
  final TextEditingController montoController;

  String? get cuotaId => cobro.proximaCuotaId;
}

class CobroRuta {
  const CobroRuta({
    required this.id,
    required this.clienteId,
    required this.cliente,
    required this.rutaId,
    required this.ruta,
    required this.valorTotal,
    required this.valorCuota,
    required this.totalAbonado,
    required this.saldo,
    required this.numeroCuotas,
    required this.cuotasRestantes,
    required this.estadoCobro,
    required this.proximoSaldoCuota,
    this.cedula,
    this.negocio,
    this.direccion,
    this.latitude,
    this.longitude,
    this.proximaCuotaId,
    this.proximaNumeroCuota,
    this.proximaFechaPago,
  });

  factory CobroRuta.fromJson(Map<String, dynamic> json) {
    return CobroRuta(
      id: json['id'] as String,
      clienteId: json['clienteId'] as String? ?? json['id'] as String,
      cliente: json['cliente'] as String,
      cedula: json['cedula'] as String?,
      negocio: json['negocio'] as String?,
      direccion: json['direccion'] as String?,
      latitude: _dobleNullable(json['latitud']),
      longitude: _dobleNullable(json['longitud']),
      rutaId: json['rutaId'] as String? ?? '',
      ruta: json['ruta'] as String? ?? 'Sin ruta',
      valorTotal: _doble(json['valorTotal']),
      valorCuota: _doble(json['valorCuota']),
      totalAbonado: _doble(json['totalAbonado']),
      saldo: _doble(json['saldo']),
      numeroCuotas: _enteroJson(json['numeroCuotas']),
      cuotasRestantes: _enteroJson(json['cuotasRestantes']),
      proximaCuotaId: json['proximaCuotaId'] as String?,
      proximaNumeroCuota: _enteroNullableJson(json['proximaNumeroCuota']),
      proximaFechaPago: _fechaNullable(json['proximaFechaPago']),
      proximoSaldoCuota: _doble(json['proximoSaldoCuota']),
      estadoCobro: EstadoCobro.fromWire(json['estadoCobro'] as String),
    );
  }

  static const Object _sinCambio = Object();

  CobroRuta copyWith({
    String? direccion,
    double? latitude,
    double? longitude,
    double? totalAbonado,
    double? saldo,
    int? cuotasRestantes,
    Object? proximaCuotaId = _sinCambio,
    Object? proximaNumeroCuota = _sinCambio,
    Object? proximaFechaPago = _sinCambio,
    double? proximoSaldoCuota,
    EstadoCobro? estadoCobro,
  }) {
    return CobroRuta(
      id: id,
      clienteId: clienteId,
      cliente: cliente,
      cedula: cedula,
      negocio: negocio,
      direccion: direccion ?? this.direccion,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rutaId: rutaId,
      ruta: ruta,
      valorTotal: valorTotal,
      valorCuota: valorCuota,
      totalAbonado: totalAbonado ?? this.totalAbonado,
      saldo: saldo ?? this.saldo,
      numeroCuotas: numeroCuotas,
      cuotasRestantes: cuotasRestantes ?? this.cuotasRestantes,
      proximaCuotaId: identical(proximaCuotaId, _sinCambio)
          ? this.proximaCuotaId
          : proximaCuotaId as String?,
      proximaNumeroCuota: identical(proximaNumeroCuota, _sinCambio)
          ? this.proximaNumeroCuota
          : proximaNumeroCuota as int?,
      proximaFechaPago: identical(proximaFechaPago, _sinCambio)
          ? this.proximaFechaPago
          : proximaFechaPago as DateTime?,
      proximoSaldoCuota: proximoSaldoCuota ?? this.proximoSaldoCuota,
      estadoCobro: estadoCobro ?? this.estadoCobro,
    );
  }

  final String id;
  final String clienteId;
  final String cliente;
  final String? cedula;
  final String? negocio;
  final String? direccion;
  final double? latitude;
  final double? longitude;
  final String rutaId;
  final String ruta;
  final double valorTotal;
  final double valorCuota;
  final double totalAbonado;
  final double saldo;
  final int numeroCuotas;
  final int cuotasRestantes;
  final String? proximaCuotaId;
  final int? proximaNumeroCuota;
  final DateTime? proximaFechaPago;
  final double proximoSaldoCuota;
  final EstadoCobro estadoCobro;

  bool get tieneUbicacion {
    final double? latitud = latitude;
    final double? longitud = longitude;
    return latitud != null &&
        longitud != null &&
        latitud.isFinite &&
        longitud.isFinite &&
        latitud >= -90 &&
        latitud <= 90 &&
        longitud >= -180 &&
        longitud <= 180;
  }
}

class MovimientoCaja {
  const MovimientoCaja({
    required this.id,
    required this.cajaMenorId,
    required this.cajaMenor,
    required this.tipoMovimiento,
    required this.fechaMovimiento,
    required this.monto,
    required this.montoConNaturaleza,
    required this.motivo,
    this.cliente,
    this.clienteIdentificacion,
    this.usuario,
    this.referenciaTabla,
    this.referenciaId,
  });

  factory MovimientoCaja.fromJson(Map<String, dynamic> json) {
    final Object? usuario = json['usuario'];
    return MovimientoCaja(
      id: json['id'] as String,
      cajaMenorId: json['cajaMenorId'] as String? ?? '',
      cajaMenor: json['cajaMenor'] as String,
      tipoMovimiento: TipoMovimientoCaja.fromJson(
        json['tipoMovimiento'] as Map<String, dynamic>,
      ),
      fechaMovimiento: DateTime.parse(json['fechaMovimiento'] as String),
      monto: _doble(json['monto']),
      montoConNaturaleza: _doble(json['montoConNaturaleza']),
      motivo: json['motivo'] as String,
      cliente: json['cliente'] as String?,
      clienteIdentificacion: json['clienteIdentificacion'] as String?,
      usuario: usuario is Map<String, dynamic>
          ? UsuarioCatalogo.fromJson(usuario)
          : null,
      referenciaTabla: json['referenciaTabla'] as String?,
      referenciaId: json['referenciaId'] as String?,
    );
  }

  final String id;
  final String cajaMenorId;
  final String cajaMenor;
  final TipoMovimientoCaja tipoMovimiento;
  final DateTime fechaMovimiento;
  final double monto;
  final double montoConNaturaleza;
  final String motivo;
  final String? cliente;
  final String? clienteIdentificacion;
  final UsuarioCatalogo? usuario;
  final String? referenciaTabla;
  final String? referenciaId;

  bool get esPago => referenciaTabla == 'pago';
  bool get esAuditoria => referenciaTabla == 'auditoria_caja_menor';
  bool get esEditablePorAdmin => !esAuditoria;

  MovimientoCaja copyWith({
    String? cajaMenorId,
    String? cajaMenor,
    TipoMovimientoCaja? tipoMovimiento,
    DateTime? fechaMovimiento,
    double? monto,
    double? montoConNaturaleza,
    String? motivo,
  }) {
    return MovimientoCaja(
      id: id,
      cajaMenorId: cajaMenorId ?? this.cajaMenorId,
      cajaMenor: cajaMenor ?? this.cajaMenor,
      tipoMovimiento: tipoMovimiento ?? this.tipoMovimiento,
      fechaMovimiento: fechaMovimiento ?? this.fechaMovimiento,
      monto: monto ?? this.monto,
      montoConNaturaleza: montoConNaturaleza ?? this.montoConNaturaleza,
      motivo: motivo ?? this.motivo,
      cliente: cliente,
      clienteIdentificacion: clienteIdentificacion,
      usuario: usuario,
      referenciaTabla: referenciaTabla,
      referenciaId: referenciaId,
    );
  }

  String get motivoVisible {
    final String? clienteNombre =
        cliente?.trim().isEmpty ?? true ? null : cliente!.trim();

    if (referenciaTabla == 'credito_desembolso' && clienteNombre != null) {
      return 'Desembolso de credito para $clienteNombre';
    }

    return motivo;
  }
}

class Presupuesto {
  const Presupuesto({required this.items, required this.totales});

  factory Presupuesto.fromJson(Map<String, dynamic> json) {
    return Presupuesto(
      items: _lista(json['items'])
          .map(PresupuestoItem.fromJson)
          .toList(growable: false),
      totales:
          PresupuestoTotales.fromJson(json['totales'] as Map<String, dynamic>),
    );
  }

  final List<PresupuestoItem> items;
  final PresupuestoTotales totales;
}

class PresupuestoItem {
  const PresupuestoItem({
    required this.cajaMenorId,
    required this.cajaMenorNombre,
    required this.monedaCodigo,
    required this.cajaMenor,
    required this.recaudado,
    required this.gastos,
    required this.creditos,
    required this.creditosRefinanciados,
    required this.clientesCreditos,
    required this.valorRefinanciado,
    required this.presupuesto,
  });

  factory PresupuestoItem.fromJson(Map<String, dynamic> json) {
    return PresupuestoItem(
      cajaMenorId: json['cajaMenorId'] as String? ?? '',
      cajaMenorNombre: json['cajaMenorNombre'] as String? ?? 'Caja menor',
      monedaCodigo: json['monedaCodigo'] as String,
      cajaMenor: _doble(json['cajaMenor']),
      recaudado: _doble(json['recaudado']),
      gastos: _doble(json['gastos']).abs(),
      creditos: _doble(json['creditos']),
      creditosRefinanciados: _enteroJson(json['creditosRefinanciados']),
      clientesCreditos: _enteroJson(json['clientesCreditos']),
      valorRefinanciado: _doble(json['valorRefinanciado']),
      presupuesto: _doble(json['presupuesto']),
    );
  }

  final String cajaMenorId;
  final String cajaMenorNombre;
  final String monedaCodigo;
  final double cajaMenor;
  final double recaudado;
  final double gastos;
  final double creditos;
  final int creditosRefinanciados;
  final int clientesCreditos;
  final double valorRefinanciado;
  final double presupuesto;
}

class PresupuestoTotales {
  const PresupuestoTotales({
    required this.cajaMenor,
    required this.recaudado,
    required this.gastos,
    required this.creditos,
    required this.creditosRefinanciados,
    required this.clientesCreditos,
    required this.valorRefinanciado,
    required this.presupuesto,
  });

  const PresupuestoTotales.vacio()
      : cajaMenor = 0,
        recaudado = 0,
        gastos = 0,
        creditos = 0,
        creditosRefinanciados = 0,
        clientesCreditos = 0,
        valorRefinanciado = 0,
        presupuesto = 0;

  factory PresupuestoTotales.fromJson(Map<String, dynamic> json) {
    return PresupuestoTotales(
      cajaMenor: _doble(json['cajaMenor']),
      recaudado: _doble(json['recaudado']),
      gastos: _doble(json['gastos']).abs(),
      creditos: _doble(json['creditos']),
      creditosRefinanciados: _enteroJson(json['creditosRefinanciados']),
      clientesCreditos: _enteroJson(json['clientesCreditos']),
      valorRefinanciado: _doble(json['valorRefinanciado']),
      presupuesto: _doble(json['presupuesto']),
    );
  }

  final double cajaMenor;
  final double recaudado;
  final double gastos;
  final double creditos;
  final int creditosRefinanciados;
  final int clientesCreditos;
  final double valorRefinanciado;
  final double presupuesto;
}

enum EstadoCobro {
  alDia,
  pendiente,
  atrasado,
  pagado;

  factory EstadoCobro.fromWire(String value) {
    return switch (value) {
      'AL_DIA' => EstadoCobro.alDia,
      'PENDIENTE' => EstadoCobro.pendiente,
      'ATRASADO' => EstadoCobro.atrasado,
      'PAGADO' => EstadoCobro.pagado,
      _ => EstadoCobro.pendiente,
    };
  }

  String get etiqueta {
    return switch (this) {
      EstadoCobro.alDia => 'Al día',
      EstadoCobro.pendiente => 'Debe hoy',
      EstadoCobro.atrasado => 'Atrasado',
      EstadoCobro.pagado => 'Pagado',
    };
  }

  Color get color {
    return switch (this) {
      EstadoCobro.alDia => CobroAppTheme.success,
      EstadoCobro.pendiente => CobroAppTheme.warning,
      EstadoCobro.atrasado => CobroAppTheme.danger,
      EstadoCobro.pagado => CobroAppTheme.primary,
    };
  }
}

List<Map<String, dynamic>> _lista(Object? value) {
  if (value is! List<dynamic>) {
    return const <Map<String, dynamic>>[];
  }

  return value.whereType<Map<String, dynamic>>().toList(growable: false);
}

double _doble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return _parseNumero(value) ?? 0;
  }
  return 0;
}

double? _dobleNullable(Object? value) {
  if (value == null) {
    return null;
  }
  final double? parsed = value is num
      ? value.toDouble()
      : value is String
          ? _parseNumero(value)
          : null;
  return parsed?.isFinite ?? false ? parsed : null;
}

int _enteroJson(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

int? _enteroNullableJson(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _fechaNullable(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String _fechaValor(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _fechaHoraValor(DateTime value) {
  return value.toUtc().toIso8601String();
}

DateTime _fechaHoraColombia([DateTime? value]) {
  return (value ?? DateTime.now()).toUtc().subtract(const Duration(hours: 5));
}

String _nombreCajaMenorPorDefecto([DateTime? value]) {
  final DateTime colombia = _fechaHoraColombia(value);
  return '${colombia.day.toString().padLeft(2, '0')}/'
      '${colombia.month.toString().padLeft(2, '0')}/'
      '${colombia.year.toString().padLeft(4, '0')} '
      '${colombia.hour.toString().padLeft(2, '0')}:'
      '${colombia.minute.toString().padLeft(2, '0')}';
}

String _fechaEtiqueta(DateTime? value) {
  if (value == null) {
    return '-';
  }

  const List<String> meses = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  return '${value.day.toString().padLeft(2, '0')} '
      '${meses[value.month - 1]} ${value.year}';
}

String _fechaHoraEtiqueta(DateTime? value) {
  if (value == null) {
    return '-';
  }

  final DateTime local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year.toString().padLeft(4, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _textoCeldaExportacion(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is num) {
    return _numero(value.toDouble()).replaceAll('.', ',');
  }
  return value.toString();
}

String _textoCreditos(int value) {
  return value == 1 ? '1 credito' : '$value creditos';
}

String _dinero(double value) {
  final bool negativo = value < 0;
  final String raw = _decimalPreciso(value.abs());
  final List<String> partes = raw.split('.');
  final String entero = partes.first;
  final StringBuffer buffer = StringBuffer();

  for (int i = 0; i < entero.length; i++) {
    final int desdeFinal = entero.length - i;
    buffer.write(entero[i]);
    if (desdeFinal > 1 && desdeFinal % 3 == 1) {
      buffer.write('.');
    }
  }

  final String decimales = partes.length == 2 ? ',${partes.last}' : '';
  return '${negativo ? '-' : ''}\$${buffer.toString()}$decimales';
}

String _dineroCredito(double value) {
  return _dinero(value);
}

String _etiquetaFrecuencia(FrecuenciaPago? frecuencia) {
  switch (frecuencia?.codigo.toUpperCase()) {
    case 'DIARIO':
      return 'diarias';
    case 'SEMANAL':
      return 'semanales';
    case 'QUINCENAL':
      return 'quincenales';
    case 'MENSUAL':
      return 'mensuales';
    default:
      return 'cada ${frecuencia?.diasIntervalo ?? 1} días';
  }
}

String _numero(double value) {
  if (value == 0) {
    return '0';
  }

  return '${value < 0 ? '-' : ''}${_decimalPreciso(value.abs())}';
}

double _leerMonto(String value) {
  final double? parsed = _parseNumero(value);
  if (parsed == null || parsed <= 0) {
    throw const FormatException('Ingresa un monto mayor que cero');
  }
  return parsed;
}

double _leerPorcentaje(String value) {
  final double? parsed = _parseNumero(value);
  if (parsed == null || parsed < 0) {
    throw const FormatException('Ingresa un porcentaje válido');
  }
  return parsed;
}

String _decimalPreciso(double value) {
  if (value == 0 || value.isNaN || value.isInfinite) {
    return '0';
  }

  final String raw = value.toString().toLowerCase();
  if (!raw.contains('e')) {
    return _quitarCerosDecimales(raw);
  }

  return _quitarCerosDecimales(_expandirNotacionCientifica(raw));
}

String _expandirNotacionCientifica(String raw) {
  final List<String> partes = raw.split('e');
  final String mantisa = partes.first;
  final int exponente = int.parse(partes.last);
  final int punto = mantisa.indexOf('.');
  final int posicionDecimal = punto == -1 ? mantisa.length : punto;
  final String digitos = mantisa.replaceAll('.', '');
  final int nuevaPosicion = posicionDecimal + exponente;

  if (nuevaPosicion <= 0) {
    final String ceros = ''.padLeft(-nuevaPosicion, '0');
    return '0.$ceros$digitos';
  }

  if (nuevaPosicion >= digitos.length) {
    final String ceros = ''.padLeft(nuevaPosicion - digitos.length, '0');
    return '$digitos$ceros';
  }

  return '${digitos.substring(0, nuevaPosicion)}.'
      '${digitos.substring(nuevaPosicion)}';
}

String _quitarCerosDecimales(String value) {
  if (!value.contains('.')) {
    return value;
  }

  var limpio = value;
  while (limpio.endsWith('0')) {
    limpio = limpio.substring(0, limpio.length - 1);
  }
  if (limpio.endsWith('.')) {
    limpio = limpio.substring(0, limpio.length - 1);
  }
  return limpio.isEmpty ? '0' : limpio;
}

int _leerEnteroPositivo(String value) {
  final double? parsed = _parseNumero(value);
  if (parsed == null || parsed <= 0) {
    throw const FormatException('Ingresa un plazo mayor que cero');
  }
  return math.max(1, parsed.round());
}

double? _parseNumero(String value) {
  final String normalized =
      value.trim().replaceAll(RegExp(r'[^0-9,.-]'), '').replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  final double? parsed = double.tryParse(normalized);
  if (parsed == null || parsed.isNaN || parsed.isInfinite) {
    return null;
  }
  return parsed;
}
