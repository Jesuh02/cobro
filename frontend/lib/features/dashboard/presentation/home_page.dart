export '../../../data/models/models.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_theme.dart';
import '../../../app/session_cache.dart';
import '../../../core/constants/permisos_constants.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/offline_mutation.dart';
import '../../../core/platform/export_download.dart';
import '../../../core/ui/chips_indicadores.dart';
import '../../../core/ui/cobro_dropdown.dart';
import '../../../core/ui/marca_aplicacion.dart';
import '../../../core/ui/modal_layouts.dart';
import '../../../core/ui/page_layout.dart';
import '../../../core/ui/skeletons.dart';
import '../../../core/ui/visor_exportacion_excel.dart';
import '../../../data/models/models.dart';
import '../../caja_menor/presentation/caja_menor_view.dart';
import '../../clientes/presentation/clientes_view.dart';
import '../../clientes/presentation/widgets/cliente_ubicacion_picker.dart';
import '../../creditos/presentation/creditos_view.dart';
import '../../empleados/presentation/gestion_empleados_page.dart';
import '../../organizaciones/presentation/widgets/organizacion_admin_picker.dart';
import '../../presupuesto/presentation/inicio_presupuesto_view.dart';
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

const String _direccionCasaHint = 'Ej: cr14 #28-26';
const String _mensajeDireccionCasa =
    'Escribe la direccion de la casa asociada a esta ubicacion';
const String _mensajeUbicacionCasa =
    'Ubicacion marcada. Escribe la direccion de la casa, ej: cr14 #28-26';

typedef _PermisoEmpleadoDef = PermisoEmpleadoDef;
const List<_PermisoEmpleadoDef> _permisosEmpleado = permisosEmpleado;

const List<String> _permisosEmpleadoCodigos = permisosEmpleadoCodigos;

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
          _cajaMenorFiltroId =
              value == _todasLasCajasFiltro ? null : value;
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
    return mapCustomerFromCobro(
      cobro,
      canCollect: _puedeRegistrarPagoRuta(cobro),
      canRoute: _cobroActivoParaRuta(cobro),
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

typedef _TipoMensaje = TipoMensaje;

_TipoMensaje _tipoMensaje(String message) => calcularTipoMensaje(message);

typedef _AvisoFlotante = AvisoFlotante;

typedef _AvisoEstilo = AvisoEstilo;

typedef _MarcaAplicacion = MarcaAplicacion;

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

typedef _PaginaDatos<T> = PaginaDatos<T>;

typedef _ConteoCreditosInicio = ConteoCreditosInicio;
typedef _PaginaInicioPresupuesto = PaginaInicioPresupuesto;
typedef _FiltrosInicioPresupuesto = FiltrosInicioPresupuesto;
typedef _ResumenCreditosInicio = ResumenCreditosInicio;
typedef _AccesoCreditoInicio = AccesoCreditoInicio;
typedef _TarjetaAccesoCreditoInicio = TarjetaAccesoCreditoInicio;
typedef _EntradaAnimada = EntradaAnimada;
typedef _EncabezadoInicioPresupuesto = EncabezadoInicioPresupuesto;
typedef _TarjetaTotalPresupuesto = TarjetaTotalPresupuesto;
typedef _TituloSeccionPresupuesto = TituloSeccionPresupuesto;
typedef _ComposicionPresupuesto = ComposicionPresupuesto;
typedef _LineaDatoPresupuesto = LineaDatoPresupuesto;
typedef _ActividadPresupuesto = ActividadPresupuesto;
typedef _TarjetaActividadPresupuesto = TarjetaActividadPresupuesto;
typedef _DatoPresupuesto = DatoPresupuesto;
typedef _PresupuestoItem = TarjetaPresupuestoItem;
typedef _Pagina = Pagina;
typedef _Encabezado = Encabezado;
typedef _ErrorBanner = ErrorBanner;
typedef _LineaMonto = LineaMonto;
typedef _EstadoVacio = EstadoVacio;

typedef _FiltrosRuta = FiltrosRuta;
typedef _ResumenEstados = ResumenEstados;
typedef _EstadoContador = EstadoContador;
typedef _TarjetaCobroRuta = TarjetaCobroRuta;
typedef _VisorExportacionExcel = VisorExportacionExcel;
typedef _EtiquetaExportacion = EtiquetaExportacion;
typedef _TablaVistaPreviaExcel = TablaVistaPreviaExcel;
typedef _SkeletonListaCreditos = SkeletonListaCreditos;
typedef _SkeletonTarjetaCredito = SkeletonTarjetaCredito;
typedef _SkeletonDatoCredito = SkeletonDatoCredito;
typedef _SkeletonCreditoBloque = SkeletonCreditoBloque;
typedef _SkeletonListaMovimientosCaja = SkeletonListaMovimientosCaja;
typedef _SkeletonTarjetaMovimientoCaja = SkeletonTarjetaMovimientoCaja;

typedef _BarraSaldo = BarraSaldo;
typedef _EstadoChip = EstadoChip;
typedef _DatoResumen = DatoResumen;


typedef _ResumenCreditoAnimado = ResumenCreditoAnimado;


typedef _FlujoBilletes = FlujoBilletes;
typedef _Billete = Billete;
typedef _FlechaFlujo = FlechaFlujo;
typedef _PasoCalculo = PasoCalculo;
typedef _CalculoCredito = CalculoCredito;


typedef _SelectorClienteCredito = SelectorClienteCredito;
typedef _ClienteOpcionCredito = ClienteOpcionCredito;
String _etiquetaCliente(Cliente cliente) => etiquetaCliente(cliente);


typedef _SelectorClientesCreditoMultiple = SelectorClientesCreditoMultiple;
typedef _MontosClientesCredito = MontosClientesCredito;
typedef _MontoClienteCreditoItem = MontoClienteCreditoItem;


typedef _FormularioCredito = FormularioCredito;


typedef _CamposCreditoSinCliente = CamposCreditoSinCliente;


typedef _ClienteUbicacionPicker = ClienteUbicacionPicker;
typedef _DialogContent = DialogContent;
typedef _DosColumnas = DosColumnas;


typedef _MovimientoCajaItem = MovimientoCajaItem;

typedef _OrganizacionAdminPicker = OrganizacionAdminPicker;
typedef _OrganizacionAdminItem = OrganizacionAdminItem;
typedef _OrganizacionDato = OrganizacionDato;

typedef _ClienteItem = ClienteItem;

typedef _GestionEmpleadosPage = GestionEmpleadosPage;
typedef _ActividadEmpleadoCard = ActividadEmpleadoCard;
typedef _ActividadDato = ActividadDato;
typedef _ActividadRutaRow = ActividadRutaRow;
typedef _EmpleadoGestionMetrica = EmpleadoGestionMetrica;
typedef _MensajePanel = MensajePanel;
typedef _EmpleadoGestionItem = EmpleadoGestionItem;

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

typedef _FiltroMovimientoCaja = FiltroMovimientoCaja;

typedef _FiltroEstadoRuta = FiltroEstadoRuta;

typedef _FiltroEstadoCredito = FiltroEstadoCredito;

typedef _AccionCredito = AccionCredito;

typedef _AccionCliente = AccionCliente;

typedef _AccionMovimientoCaja = AccionMovimientoCaja;


typedef _SelectorCobroRutaBuscable = SelectorCobroRutaBuscable;


typedef _SelectorMedioPagoBuscable = SelectorMedioPagoBuscable;
typedef _PagoRutaSolicitud = PagoRutaSolicitud;
typedef _PagoRutaSeleccion = PagoRutaSeleccion;


List<Map<String, dynamic>> _lista(Object? value) {
  if (value is! List<dynamic>) {
    return const <Map<String, dynamic>>[];
  }

  return value.whereType<Map<String, dynamic>>().toList(growable: false);
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

String _fechaValor(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _fechaHoraValor(DateTime value) {
  return value.toUtc().toIso8601String();
}

DateTime _fechaHoraColombia([DateTime? value]) => fechaHoraColombia(value);

String _nombreCajaMenorPorDefecto([DateTime? value]) =>
    nombreCajaMenorPorDefecto(value);

String _fechaEtiqueta(DateTime? value) => formatDateLabel(value);

String _fechaHoraEtiqueta(DateTime? value) => formatDateTimeLabel(value);

String _textoCeldaExportacion(Object? value) => formatExportCellText(value);

String _textoCreditos(int value) => formatCreditsCount(value);

double _redondearDinero(double value, [int decimales = 2]) =>
    roundMoney(value, decimales);

String _dinero(double value) => formatMoney(value);

String _dineroCredito(double value) => formatMoney(value);

String _etiquetaFrecuencia(FrecuenciaPago? frecuencia) =>
    etiquetaFrecuencia(frecuencia);

String _numero(double value) => formatNumber(value);

double _leerMonto(String value) => parseMontoInput(value);

double _leerPorcentaje(String value) => parsePorcentajeInput(value);

String _decimalPreciso(double value) => preciseDecimal(value);

String _expandirNotacionCientifica(String raw) =>
    expandirNotacionCientifica(raw);

String _quitarCerosDecimales(String value) => quitarCerosDecimales(value);

int _leerEnteroPositivo(String value) => parseEnteroPositivoInput(value);

double? _parseNumero(String value) => parseNumero(value);