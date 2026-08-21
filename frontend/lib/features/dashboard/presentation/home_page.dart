import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/platform/export_download.dart';
import '../../../core/ui/clay.dart';

part 'dashboard_charts.dart';

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
  late final bool _cerrarApiClientAlSalir;
  static const double _mobileBreakpoint = 760;
  static const int _pageSize = 40;
  static const String _interesCreditoPredeterminado = '20';
  static const String _plazoCreditoPredeterminado = '30';
  static const String _todasLasCajasFiltro = '__todas_las_cajas__';
  static const List<_DestinoMenu> _destinosMenu = <_DestinoMenu>[
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

  final TextEditingController _buscarRutaController = TextEditingController();
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
  int _siguienteOffsetCreditos = 0;
  int _siguienteOffsetMovimientosCaja = 0;
  bool _hayMasCreditos = false;
  bool _hayMasMovimientosCaja = false;
  bool _cargandoCreditos = false;
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
  String? _error;
  OverlayEntry? _mensajeOverlay;
  Timer? _mensajeTimer;
  Timer? _refrescoTimer;
  Timer? _filtrosListasTimer;
  int _cargaSerial = 0;
  DateTime? _fechaCajaDesde;
  DateTime? _fechaCajaHasta;
  DateTime? _fechaCreditoDesde;
  DateTime? _fechaCreditoHasta;
  String? _cajaMenorFiltroId;

  String? _rutaFiltroId;
  String? _clienteCreditoId;
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
    _cerrarApiClientAlSalir = widget.apiClient == null;
    _buscarRutaController.addListener(_refrescar);
    _buscarCreditoController.addListener(_programarRecargaListasPesadas);
    _buscarCajaController.addListener(_programarRecargaListasPesadas);
    _buscarClienteController.addListener(_refrescar);
  }

  @override
  void dispose() {
    _mensajeTimer?.cancel();
    _refrescoTimer?.cancel();
    _filtrosListasTimer?.cancel();
    _mensajeOverlay?.remove();
    if (_cerrarApiClientAlSalir) {
      _apiClient.close();
    }
    _buscarRutaController.dispose();
    _buscarCreditoController.dispose();
    _buscarCajaController.dispose();
    _buscarClienteController.dispose();
    _valorCreditoController.dispose();
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

    final List<Widget> vistas = <Widget>[
      KeyedSubtree(
        key: const ValueKey<String>('inicio'),
        child: _construirPresupuesto(context),
      ),
      KeyedSubtree(
        key: const ValueKey<String>('ruta'),
        child: _construirRutaActiva(context),
      ),
      KeyedSubtree(
        key: const ValueKey<String>('credito'),
        child: _construirNuevoCredito(context),
      ),
      KeyedSubtree(
        key: const ValueKey<String>('caja-menor'),
        child: _construirCajaMenor(context),
      ),
      KeyedSubtree(
        key: const ValueKey<String>('clientes'),
        child: _construirClientes(context),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const _MarcaAplicacion(),
        actions: <Widget>[
          if (!esMovil) ...<Widget>[
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
                  case _AccionSesion.crearEmpleado:
                    _abrirCrearEmpleado();
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
                  if (usuarioSesion.esAdministrador)
                    const PopupMenuItem<_AccionSesion>(
                      value: _AccionSesion.crearEmpleado,
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.person_add_alt_1_rounded),
                          SizedBox(width: 12),
                          Text('Crear empleado'),
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
              if (!esMovil) ...<Widget>[
                _construirMenuLateral(context),
                VerticalDivider(width: 1, color: context.clay.border),
              ],
              Expanded(
                child: _cargando && _catalogos == null
                    ? const Center(child: CircularProgressIndicator())
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 360),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (
                          Widget child,
                          Animation<double> animation,
                        ) {
                          final Animation<Offset> slide = Tween<Offset>(
                            begin: const Offset(0.025, 0),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: vistas[_seccionActual],
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          esMovil ? _construirNavegacionInferior(context) : null,
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
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed:
                            _guardando ? null : _abrirCrearAdministradorInicial,
                        icon: const Icon(Icons.admin_panel_settings_rounded),
                        label: const Text('Crear administrador inicial'),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      ..._destinosMenu.asMap().entries.map(
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
                      const Spacer(),
                      if (_usuarioSesion?.esAdministrador ?? false) ...<Widget>[
                        OutlinedButton.icon(
                          onPressed: _guardando ? null : _abrirCrearEmpleado,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Crear empleado'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextButton.icon(
                        onPressed: _cerrarSesion,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Cerrar sesion'),
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
                        destinations: _destinosMenu
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
                    if (_usuarioSesion?.esAdministrador ?? false)
                      Tooltip(
                        message: 'Crear empleado',
                        child: IconButton(
                          onPressed: _guardando ? null : _abrirCrearEmpleado,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                        ),
                      ),
                    Tooltip(
                      message: 'Cerrar sesion',
                      child: IconButton(
                        onPressed: _cerrarSesion,
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
        },
      ),
    );
  }

  Widget _construirNavegacionInferior(BuildContext context) {
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
            children: _destinosMenu.asMap().entries.map(
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

  void _seleccionarSeccion(int index) {
    if (index == 2) {
      setState(() => _seccionActual = index);
      _abrirCrearCreditoModal();
      return;
    }

    setState(() => _seccionActual = index);
  }

  Widget _construirPresupuesto(BuildContext context) {
    final PresupuestoTotales totales =
        _presupuesto?.totales ?? const PresupuestoTotales.vacio();
    final int clientesActivos = _clientes.length;
    final double cartera = _cobrosRuta.fold<double>(
      0,
      (double total, CobroRuta cobro) => total + cobro.saldo,
    );
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
      clientesActivos: clientesActivos,
      cartera: cartera,
      fechaInicio: inicioPeriodo,
      fechaFin: ahora,
      items: _presupuesto?.items ?? const <PresupuestoItem>[],
      error: _error,
      onRefresh: _cargar,
    );
  }

  Widget _construirRutaActiva(BuildContext context) {
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

    return _Pagina(
      titulo: 'Ruta activa',
      subtitulo: 'Cuotas pendientes desde créditos reales',
      error: _error,
      onRefresh: _cargar,
      children: <Widget>[
        _FiltrosRuta(
          buscarController: _buscarRutaController,
          rutas: _catalogos?.rutas ?? const <RutaCatalogo>[],
          rutaSeleccionadaId: _rutaFiltroId,
          exportando: _exportando,
          onRutaChanged: (String? rutaId) {
            setState(() => _rutaFiltroId = rutaId);
          },
          onExportar: _exportarCobrosRuta,
        ),
        const SizedBox(height: 14),
        _ResumenEstados(
          alDia: alDia,
          pendientes: pendientes,
          atrasados: atrasados,
          filtro: _filtroEstadoRuta,
          onFiltroChanged: (_FiltroEstadoRuta filtro) {
            setState(() {
              _filtroEstadoRuta = _filtroEstadoRuta == filtro
                  ? _FiltroEstadoRuta.todos
                  : filtro;
            });
          },
        ),
        const SizedBox(height: 16),
        if (cobros.isEmpty)
          _EstadoVacio(
            icono: Icons.route_outlined,
            titulo: 'Sin cuotas por cobrar',
            mensaje: 'No hay créditos activos con saldo para el filtro actual.',
            accion: FilledButton.icon(
              onPressed: _guardando ? null : _abrirCrearCreditoModal,
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
                onRegistrarPago: _guardando ||
                        cobro.proximaCuotaId == null ||
                        _cuotasEnPago.contains(cobro.proximaCuotaId)
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

    return _Pagina(
      titulo: 'Credito',
      subtitulo: 'Creacion, refinanciacion e historial',
      error: _error,
      onRefresh: _cargar,
      onNearEnd: _cargarMasCreditosSiHaceFalta,
      acciones: <Widget>[
        OutlinedButton.icon(
          onPressed: _guardando || !hayCreditoActivo
              ? null
              : _abrirSeleccionRefinanciacion,
          icon: const Icon(Icons.currency_exchange_rounded),
          label: const Text('Refinanciar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _abrirCrearCreditoModal,
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
                : 'Necesitas clientes, monedas, frecuencias y caja menor activa.',
            accion: FilledButton.icon(
              onPressed: _guardando ? null : _abrirCrearCreditoModal,
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
              onPressed: _guardando ? null : _abrirCrearCreditoModal,
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
                esAdministrador: _usuarioSesion?.esAdministrador ?? false,
                onModificar: () => _abrirModificarCredito(credito),
                onEliminar: () => _confirmarEliminarCredito(credito),
                onRefinanciar: credito.activo && !_guardando
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
    return _Pagina(
      titulo: 'Caja menor',
      subtitulo: 'Movimientos y pagos registrados  ',
      error: _error,
      onRefresh: _cargar,
      onNearEnd: _cargarMasMovimientosCajaSiHaceFalta,
      acciones: <Widget>[
        if (hayCajaMenor)
          OutlinedButton.icon(
            onPressed: _guardando ? null : _abrirCrearCajaMenor,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Nueva caja menor'),
          ),
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
        if (movimientos.isEmpty)
          _EstadoVacio(
            icono: Icons.savings_outlined,
            titulo: hayCajaMenor ? 'Sin movimientos' : 'Sin caja menor',
            mensaje: hayCajaMenor
                ? 'No hay movimientos ni pagos para mostrar.'
                : 'Crea una caja menor para comenzar a registrar movimientos.',
            accion: FilledButton.icon(
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
          )
        else
          ...movimientos.map(
            (MovimientoCaja movimiento) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MovimientoCajaItem(
                movimiento: movimiento,
                esAdministrador: _usuarioSesion?.esAdministrador ?? false,
                onModificar: () => _abrirEditarMovimientoCaja(movimiento),
                onEliminar: () => _confirmarEliminarMovimientoCaja(movimiento),
              ),
            ),
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
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'filtro-caja-${_cajaMenorFiltroId ?? _todasLasCajasFiltro}',
              ),
              initialValue: filtroCajaValido
                  ? _cajaMenorFiltroId
                  : _todasLasCajasFiltro,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Caja',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: _todasLasCajasFiltro,
                  child: Text('Todas las cajas'),
                ),
                ...cajas.map(
                  (CajaMenorCatalogo caja) => DropdownMenuItem<String>(
                    value: caja.id,
                    child: Text(
                      caja.nombre,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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

  Future<void> _seleccionarFechaCredito({required bool esDesde}) async {
    final DateTime ahora = DateTime.now();
    final DateTime? actual =
        esDesde ? _fechaCreditoDesde : _fechaCreditoHasta;
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

  Widget _construirClientes(BuildContext context) {
    final List<Cliente> clientes = _filtrarClientes();

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
                child: _ClienteItem(cliente: cliente),
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
      final Sesion sesion = Sesion.fromJson(
        await _apiClient.postObject('/auth/login', <String, dynamic>{
          'usuario': usuario,
          'contrasena': contrasena,
        }),
      );

      _apiClient.setAuthToken(sesion.token);

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
        _movimientosCaja = const <MovimientoCaja>[];
        _cajaMenorFiltroId = null;
      });

      await _cargar();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _abrirCrearAdministradorInicial() async {
    final Map<String, String>? datos = await _pedirDatosUsuario(
      titulo: 'Administrador inicial',
      accion: 'Crear administrador',
    );

    if (datos == null) {
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final Sesion sesion = Sesion.fromJson(
        await _apiClient.postObject(
          '/auth/bootstrap-admin',
          <String, dynamic>{...datos},
        ),
      );

      _apiClient.setAuthToken(sesion.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _usuarioSesion = sesion.usuario;
        _seccionActual = 0;
      });

      await _cargar();
      _mostrarMensaje('Administrador creado');
    } catch (error) {
      if (mounted) {
        setState(() => _error = _mensajeError(error));
        _mostrarMensaje(_mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _abrirCrearEmpleado() async {
    if (!(_usuarioSesion?.esAdministrador ?? false)) {
      _mostrarMensaje('Solo el administrador puede crear usuarios');
      return;
    }

    final Map<String, String>? datos = await _pedirDatosUsuario(
      titulo: 'Crear empleado',
      accion: 'Crear empleado',
    );

    if (datos == null) {
      return;
    }

    final bool guardado = await _ejecutarAccion(() async {
      await _apiClient.postObject('/usuarios', <String, dynamic>{...datos});
      await _cargar();
    });

    if (guardado) {
      _mostrarMensaje('Empleado creado');
    }
  }

  Future<Map<String, String>?> _pedirDatosUsuario({
    required String titulo,
    required String accion,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController nombreController = TextEditingController();
        final TextEditingController usuarioController = TextEditingController();
        final TextEditingController contrasenaController =
            TextEditingController();
        final TextEditingController correoController = TextEditingController();
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
                        labelText: 'Contrasena',
                        helperText: 'Minimo 8 caracteres',
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
                  if (contrasena.length < 8) {
                    _mostrarMensaje(
                      'La contrasena debe tener minimo 8 caracteres',
                    );
                    return;
                  }

                  Navigator.of(dialogContext).pop(<String, String>{
                    'nombreCompleto': nombre,
                    'usuario': nombreUsuario,
                    'correo': correo,
                    'contrasena': contrasena,
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
    _loginContrasenaController.clear();

    setState(() {
      _usuarioSesion = null;
      _catalogos = null;
      _presupuesto = null;
      _clientes = const <Cliente>[];
      _cobrosRuta = const <CobroRuta>[];
      _creditos = const <CreditoRegistro>[];
      _movimientosCaja = const <MovimientoCaja>[];
      _siguienteOffsetCreditos = 0;
      _siguienteOffsetMovimientosCaja = 0;
      _hayMasCreditos = false;
      _hayMasMovimientosCaja = false;
      _cargandoCreditos = false;
      _cargandoMasCreditos = false;
      _cargandoMasMovimientosCaja = false;
      _seccionActual = 0;
      _cajaMenorFiltroId = null;
      _cargando = false;
      _guardando = false;
      _error = null;
    });
  }

  Future<void> _cargar() async {
    if (_usuarioSesion == null) {
      return;
    }

    final int cargaActual = ++_cargaSerial;
    setState(() {
      _cargando = true;
      _cargandoCreditos = true;
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
        _ajustarSelecciones();
      });
    } catch (error) {
      if (!mounted || cargaActual != _cargaSerial) {
        return;
      }
      _manejarErrorCarga(error);
    } finally {
      if (mounted && cargaActual == _cargaSerial) {
        setState(() {
          _cargando = false;
          _cargandoCreditos = false;
        });
      }
    }
  }

  Future<Catalogos> _obtenerCatalogos() async {
    return Catalogos.fromJson(await _apiClient.getObject('/catalogos'));
  }

  Future<Presupuesto> _obtenerPresupuesto() async {
    return Presupuesto.fromJson(await _apiClient.getObject('/presupuesto'));
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
      'fechaDesde': _fechaCreditoDesde == null
          ? null
          : _fechaValor(_fechaCreditoDesde!),
      'fechaHasta': _fechaCreditoHasta == null
          ? null
          : _fechaValor(_fechaCreditoHasta!),
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
        }
        if (creditosIndex != null) {
          final _PaginaDatos<CreditoRegistro> pagina =
              resultados[creditosIndex!] as _PaginaDatos<CreditoRegistro>;
          _creditos = pagina.items;
          _siguienteOffsetCreditos = pagina.nextOffset ?? _creditos.length;
          _hayMasCreditos = pagina.hasMore;
        }
        if (movimientosCajaIndex != null) {
          final _PaginaDatos<MovimientoCaja> pagina =
              resultados[movimientosCajaIndex!]
                  as _PaginaDatos<MovimientoCaja>;
          _movimientosCaja = pagina.items;
          _siguienteOffsetMovimientosCaja =
              pagina.nextOffset ?? _movimientosCaja.length;
          _hayMasMovimientosCaja = pagina.hasMore;
        }
        _ajustarSelecciones();
      });
    } catch (error) {
      if (!mounted || cargaActual != _cargaSerial) {
        return;
      }
      _manejarErrorCarga(error);
    } finally {
      if (mounted && cargaActual == _cargaSerial && creditos) {
        setState(() => _cargandoCreditos = false);
      }
    }
  }

  void _manejarErrorCarga(Object error) {
    if (!mounted) {
      return;
    }

    if (error is ApiException && error.statusCode == 401) {
      _apiClient.setAuthToken(null);
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
  }) {
    final List<String> disponibles = valores.toList(growable: false);
    if (actual != null && disponibles.contains(actual)) {
      return actual;
    }
    if (permitirNulo) {
      return null;
    }
    return disponibles.isEmpty ? null : disponibles.first;
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

      if (_filtroCredito == _FiltroEstadoCredito.activos &&
          !credito.activo) {
        return false;
      }

      if (_filtroCredito == _FiltroEstadoCredito.inactivos &&
          credito.activo) {
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

    final String? clienteId = _clienteCreditoId;
    final String? rutaId = _rutaCreditoId;
    final String? monedaCodigo = _monedaCreditoCodigo;
    final int? frecuenciaPagoId = _frecuenciaPagoId;
    final String? cajaMenorId = _cajaMenorCreditoId;

    if (clienteId == null || monedaCodigo == null || frecuenciaPagoId == null) {
      _mostrarMensaje('Faltan datos reales para crear el crédito');
      return false;
    }

    if (cajaMenorId == null) {
      _mostrarMensaje('No se puede hacer credito sin caja menor');
      return false;
    }

    final double valorPrincipal;
    final double porcentajeInteres;
    final int plazoDias;

    try {
      valorPrincipal = _leerMonto(_valorCreditoController.text);
      porcentajeInteres = _leerPorcentaje(_interesController.text);
      plazoDias = _leerEnteroPositivo(_plazoController.text);
    } catch (error) {
      _mostrarMensaje(_mensajeError(error));
      return false;
    }

    if (!_validarPresupuestoCaja(cajaMenorId, valorPrincipal)) {
      return false;
    }

    cerrarFormulario?.call();
    _mostrarMensaje('Creando credito...');

    return _ejecutarAccion(() async {
      final CreditoRegistro credito = CreditoRegistro.fromJson(
        await _apiClient.postObject('/creditos', <String, dynamic>{
          'clienteId': clienteId,
          if (rutaId != null) 'rutaId': rutaId,
          'monedaCodigo': monedaCodigo,
          'frecuenciaPagoId': frecuenciaPagoId,
          'fechaInicio': _fechaValor(_fechaInicioCredito),
          'valorPrincipal': valorPrincipal,
          'porcentajeInteres': porcentajeInteres,
          'plazoDias': plazoDias,
          'omitirDomingos': _omitirDomingos,
          'cajaMenorId': cajaMenorId,
          if (_observacionCreditoController.text.trim().isNotEmpty)
            'observacion': _observacionCreditoController.text.trim(),
        }),
      );
      _guardarCreditoLocal(credito);
      _valorCreditoController.clear();
      _interesController.text = _interesCreditoPredeterminado;
      _plazoController.text = _plazoCreditoPredeterminado;
      _observacionCreditoController.clear();
      _mostrarCuotasRegistradas();
      _mostrarMensaje('Crédito creado con sus cuotas');
      _recargarEnSegundoPlano(
        catalogos: rutaId == null,
        presupuesto: true,
        cobrosRuta: true,
        movimientosCaja: true,
      );
    });
  }

  Future<void> _abrirCrearCreditoModal() async {
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

      _mostrarMensaje(
        'Necesitas clientes, monedas, frecuencias y caja menor activa.',
      );
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
                maxWidth: 600,
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
                  interesController: _interesController,
                  plazoController: _plazoController,
                  observacionController: _observacionCreditoController,
                  guardando: guardandoDialogo,
                  onClienteChanged: (String? value) {
                    actualizarFormulario(() => _clienteCreditoId = value);
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

    final List<CajaMenorCatalogo> cajasCompatibles = catalogos
        .cajasMenoresActivas
        .where((CajaMenorCatalogo caja) =>
            caja.monedaCodigo == credito.monedaCodigo)
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
    int? frecuenciaPagoId = catalogos.frecuenciasPago
            .any((FrecuenciaPago frecuencia) =>
                frecuencia.id == credito.frecuenciaPago.id)
        ? credito.frecuenciaPago.id
        : catalogos.frecuenciasPago.first.id;
    DateTime fechaInicio = DateTime.now();
    bool omitirDomingos = credito.omitirDomingos;
    final List<Cliente> clientesFormulario = _clientes
            .any((Cliente cliente) => cliente.id == credito.clienteId)
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
    if (!(_usuarioSesion?.esAdministrador ?? false)) {
      _mostrarMensaje('Solo los administradores pueden modificar creditos');
      return;
    }

    final Catalogos? catalogos = _catalogos;
    if (catalogos == null ||
        catalogos.frecuenciasPago.isEmpty ||
        catalogos.cajasMenoresActivas.isEmpty) {
      _mostrarMensaje('Necesitas catalogos y caja menor activa');
      return;
    }

    final List<CajaMenorCatalogo> cajasCompatibles = catalogos
        .cajasMenoresActivas
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
    int? frecuenciaPagoId = catalogos.frecuenciasPago
            .any((FrecuenciaPago frecuencia) =>
                frecuencia.id == credito.frecuenciaPago.id)
        ? credito.frecuenciaPago.id
        : catalogos.frecuenciasPago.first.id;
    DateTime fechaInicio = credito.fechaInicio;
    bool omitirDomingos = credito.omitirDomingos;
    final List<Cliente> clientesFormulario = _clientes
            .any((Cliente cliente) => cliente.id == credito.clienteId)
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

                      setDialogState(() => guardandoDialogo = true);
                      final bool actualizado = await _ejecutarAccion(
                        () async {
                          final CreditoRegistro respuesta =
                              CreditoRegistro.fromJson(
                            await _apiClient.patchObject(
                              '/creditos/${credito.id}',
                              <String, dynamic>{
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
                                if (observacionController.text
                                    .trim()
                                    .isNotEmpty)
                                  'observacion':
                                      observacionController.text.trim(),
                              },
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
                        },
                      );

                      if (!dialogContext.mounted) {
                        return;
                      }

                      if (actualizado) {
                        Navigator.of(dialogContext).pop(true);
                        _mostrarMensaje('Credito modificado');
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

  Future<void> _confirmarEliminarCredito(CreditoRegistro credito) async {
    if (!(_usuarioSesion?.esAdministrador ?? false)) {
      _mostrarMensaje('Solo los administradores pueden eliminar creditos');
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
        await _apiClient.deleteObject('/creditos/${credito.id}');
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
                    DropdownButtonFormField<String>(
                      initialValue: medioPagoCodigo,
                      decoration: const InputDecoration(
                        labelText: 'Medio de pago',
                        prefixIcon: Icon(Icons.credit_card_rounded),
                      ),
                      items: mediosPago
                          .map(
                            (MedioPago medio) => DropdownMenuItem<String>(
                              value: medio.codigo,
                              child: Text(medio.nombre),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => medioPagoCodigo = value);
                        }
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

  Future<void> _registrarPagoRuta({
    required String cuotaId,
    required double monto,
    required String medioPagoCodigo,
    String? observacion,
  }) async {
    if (_cuotasEnPago.contains(cuotaId)) {
      return;
    }

    if (mounted) {
      setState(() {
        _guardando = true;
        _error = null;
        _cuotasEnPago.add(cuotaId);
      });
    }
    final List<CobroRuta> cobrosAntes = _cobrosRuta;
    _aplicarPagoRutaOptimista(cuotaId, monto);
    _mostrarMensaje('Procesando pago...');

    try {
      await _apiClient.postObject('/pagos', <String, dynamic>{
        'creditoCuotaId': cuotaId,
        'montoPagado': monto,
        'medioPagoCodigo': medioPagoCodigo,
        if (observacion != null) 'observacion': observacion,
      });
      _mostrarMensaje('Pago registrado');
      _recargarEnSegundoPlano();
    } catch (error) {
      if (mounted) {
        setState(() {
          _cobrosRuta = cobrosAntes;
          _error = _mensajeError(error);
        });
        _mostrarMensaje(_mensajeError(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
          _cuotasEnPago.remove(cuotaId);
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

  void _aplicarPagoRutaOptimista(String cuotaId, double monto) {
    if (!mounted) {
      return;
    }

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
        final int cuotasRestantes = cuotaCubierta
            ? math.max(0, cobro.cuotasRestantes - 1)
            : cobro.cuotasRestantes;

        return cobro.copyWith(
          totalAbonado: nuevoAbonado,
          saldo: nuevoSaldo,
          cuotasRestantes: cuotasRestantes,
          proximoSaldoCuota: cuotaCubierta ? 0 : saldoCuota,
          proximaCuotaId: cuotaCubierta ? null : cobro.proximaCuotaId,
        );
      }).toList(growable: false);
    });
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
                    prefixIcon: Icon(Icons.location_on_rounded),
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

                await _ejecutarAccion(() async {
                  final Cliente cliente = Cliente.fromJson(
                    await _apiClient.postObject('/clientes', <String, dynamic>{
                      'nombreCompleto': nombreController.text.trim(),
                      if (cedulaController.text.trim().isNotEmpty)
                        'cedula': cedulaController.text.trim(),
                      if (direccionController.text.trim().isNotEmpty)
                        'direccion': direccionController.text.trim(),
                      if (correoController.text.trim().isNotEmpty)
                        'correo': correoController.text.trim(),
                      if (telefonoController.text.trim().isNotEmpty)
                        'telefono': telefonoController.text.trim(),
                    }),
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
                        prefixIcon: Icon(Icons.location_on_rounded),
                      ),
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
                                    if (correoController.text.trim().isNotEmpty)
                                      'correo': correoController.text.trim(),
                                    if (telefonoController.text
                                        .trim()
                                        .isNotEmpty)
                                      'telefono':
                                          telefonoController.text.trim(),
                                  },
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

  Future<void> _abrirCrearCajaMenor() async {
    if (_catalogos == null) {
      _mostrarMensaje('Los datos todavia estan cargando. Intenta nuevamente.');
      return;
    }

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
            return AlertDialog(
              title: const Text('Crear caja menor'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
                          final DateTime? selected = await _seleccionarFechaHora(
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
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final String nombre = nombreController.text.trim();
                    if (nombre.length < 2) {
                      _mostrarMensaje('Escribe un nombre para la caja menor');
                      return;
                    }
                    final DateTime fechaAperturaActual = DateTime.now();
                    if (!fechaCierre.isAfter(fechaAperturaActual)) {
                      setDialogState(() => fechaApertura = fechaAperturaActual);
                      _mostrarMensaje(
                        'El cierre debe ser posterior a la apertura',
                      );
                      return;
                    }

                    final bool guardada = await _ejecutarAccion(() async {
                      final CajaMenorCatalogo caja = CajaMenorCatalogo.fromJson(
                        await _apiClient.postObject(
                          '/caja-menor',
                          <String, dynamic>{
                            'nombre': nombre,
                            'fechaApertura':
                                _fechaHoraValor(fechaAperturaActual),
                            'fechaCierre': _fechaHoraValor(fechaCierre),
                          },
                        ),
                      );
                      _guardarCajaMenorLocal(caja);
                      _recargarEnSegundoPlano(
                        catalogos: true,
                        cobrosRuta: false,
                        movimientosCaja: false,
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

  Future<void> _abrirMovimientoCaja() async {
    final Catalogos? catalogos = _catalogos;
    if (catalogos == null) {
      _mostrarMensaje('Los datos todavía están cargando. Intenta nuevamente.');
      return;
    }
    if (catalogos.cajasMenoresActivas.isEmpty) {
      _mostrarMensaje('Primero debes crear una caja menor');
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: cajaMenorId,
                      decoration: const InputDecoration(
                        labelText: 'Caja menor',
                        prefixIcon: Icon(Icons.savings_rounded),
                      ),
                      items: catalogos.cajasMenoresActivas
                          .map(
                            (CajaMenorCatalogo caja) =>
                                DropdownMenuItem<String>(
                              value: caja.id,
                              child: Text(caja.nombre),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => cajaMenorId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tipoMovimientoCodigo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        prefixIcon: Icon(Icons.swap_vert_rounded),
                      ),
                      items: catalogos.tiposMovimientoCaja
                          .map(
                            (TipoMovimientoCaja tipo) =>
                                DropdownMenuItem<String>(
                              value: tipo.codigo,
                              child: Text(tipo.nombre),
                            ),
                          )
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
                          setDialogState(() => fechaMovimiento = selected);
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
                            'fechaMovimiento': _fechaValor(fechaMovimiento),
                            'monto': monto,
                            'motivo': motivoController.text.trim(),
                          },
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
    if (!(_usuarioSesion?.esAdministrador ?? false)) {
      _mostrarMensaje('Solo los administradores pueden modificar movimientos');
      return;
    }
    if (!movimiento.esEditablePorAdmin) {
      _mostrarMensaje('Este movimiento no se puede modificar desde caja menor');
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: cajaMenorId,
                      decoration: const InputDecoration(
                        labelText: 'Caja menor',
                        prefixIcon: Icon(Icons.savings_rounded),
                      ),
                      items: catalogos.cajasMenoresActivas
                          .map(
                            (CajaMenorCatalogo caja) =>
                                DropdownMenuItem<String>(
                              value: caja.id,
                              child: Text(caja.nombre),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => cajaMenorId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tipoMovimientoCodigo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        prefixIcon: Icon(Icons.swap_vert_rounded),
                      ),
                      items: catalogos.tiposMovimientoCaja
                          .map(
                            (TipoMovimientoCaja tipo) =>
                                DropdownMenuItem<String>(
                              value: tipo.codigo,
                              child: Text(tipo.nombre),
                            ),
                          )
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
                          setDialogState(() => fechaMovimiento = selected);
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

                    final bool actualizado = await _ejecutarAccion(() async {
                      final MovimientoCaja respuesta = MovimientoCaja.fromJson(
                        await _apiClient.patchObject(
                          '/caja-menor/movimientos/${movimiento.id}',
                          <String, dynamic>{
                            'cajaMenorId': cajaMenorId,
                            'tipoMovimientoCodigo': tipoMovimientoCodigo,
                            'fechaMovimiento': _fechaValor(fechaMovimiento),
                            'monto': monto,
                            'motivo': motivoController.text.trim(),
                          },
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
                    });

                    if (actualizado && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
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
    if (!(_usuarioSesion?.esAdministrador ?? false)) {
      _mostrarMensaje('Solo los administradores pueden eliminar movimientos');
      return;
    }
    if (!movimiento.esEditablePorAdmin) {
      _mostrarMensaje('Este movimiento no se puede eliminar desde caja menor');
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
        );
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

  if (normalizado.contains('cread') ||
      normalizado.contains('registrad') ||
      normalizado.contains('complet')) {
    return _TipoMensaje.exito;
  }

  if (normalizado.contains('error') ||
      normalizado.contains('no se pudo') ||
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
      nextOffset: json['nextOffset'] as int?,
    );
  }

  final List<T> items;
  final bool hasMore;
  final int? nextOffset;
}

class _PaginaInicioPresupuesto extends StatelessWidget {
  const _PaginaInicioPresupuesto({
    required this.totales,
    required this.clientesActivos,
    required this.cartera,
    required this.fechaInicio,
    required this.fechaFin,
    required this.items,
    required this.onRefresh,
    this.error,
  });

  final PresupuestoTotales totales;
  final int clientesActivos;
  final double cartera;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final List<PresupuestoItem> items;
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
                              subtitulo: 'Detalle por moneda disponible',
                            ),
                            const SizedBox(height: 12),
                            if (items.isEmpty)
                              const _EstadoVacio(
                                icono: Icons.account_balance_wallet_outlined,
                                titulo: 'Sin caja menor',
                                mensaje:
                                    'Aún no hay registros para calcular el presupuesto.',
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
                'Caja menor + Recaudado - Gastos',
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
        etiqueta: 'Créditos',
        valor: _dinero(totales.creditos),
        color: CobroAppTheme.danger,
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
        etiqueta: 'Clientes activos',
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
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;
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
            'Caja menor ${item.monedaCodigo}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          _LineaMonto(label: 'Caja menor', value: item.cajaMenor),
          _LineaMonto(label: 'Recaudado', value: item.recaudado),
          _LineaMonto(label: 'Gastos', value: item.gastos),
          _LineaMonto(label: 'Créditos', value: item.creditos),
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
    required this.onRutaChanged,
    required this.onExportar,
  });

  final TextEditingController buscarController;
  final List<RutaCatalogo> rutas;
  final String? rutaSeleccionadaId;
  final bool exportando;
  final ValueChanged<String?> onRutaChanged;
  final VoidCallback onExportar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 620;
        final List<Widget> children = <Widget>[
          Expanded(
            flex: compact ? 0 : 2,
            child: TextField(
              controller: buscarController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Buscar cliente, cedula o negocio',
              ),
            ),
          ),
          SizedBox(width: compact ? 0 : 12, height: compact ? 12 : 0),
          Expanded(
            flex: compact ? 0 : 1,
            child: DropdownButtonFormField<String?>(
              key: ValueKey<String?>(rutaSeleccionadaId),
              initialValue: rutaSeleccionadaId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.route_rounded),
                labelText: 'Ruta',
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas'),
                ),
                ...rutas.map(
                  (RutaCatalogo ruta) => DropdownMenuItem<String?>(
                    value: ruta.id,
                    child: Text(ruta.nombre),
                  ),
                ),
              ],
              onChanged: onRutaChanged,
            ),
          ),
          SizedBox(width: compact ? 0 : 12, height: compact ? 12 : 0),
          SizedBox(
            width: compact ? double.infinity : null,
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
          ),
        ];

        return compact
            ? Column(children: children)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
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
    required this.filtro,
    required this.onFiltroChanged,
  });

  final int alDia;
  final int pendientes;
  final int atrasados;
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
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

class _TarjetaCreditoRegistro extends StatelessWidget {
  const _TarjetaCreditoRegistro({
    required this.credito,
    required this.esAdministrador,
    required this.onModificar,
    required this.onEliminar,
    required this.onRefinanciar,
  });

  final CreditoRegistro credito;
  final bool esAdministrador;
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
              if (esAdministrador) ...<Widget>[
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
                    return const <PopupMenuEntry<_AccionCredito>>[
                      PopupMenuItem<_AccionCredito>(
                        value: _AccionCredito.modificar,
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 12),
                            Text('Modificar'),
                          ],
                        ),
                      ),
                      PopupMenuItem<_AccionCredito>(
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
                value:
                    '${credito.cuotasRestantes} / ${credito.numeroCuotas}',
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
    required this.onRegistrarPago,
  });

  final CobroRuta cobro;
  final bool pagoEnProceso;
  final VoidCallback? onRegistrarPago;

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
            child: FilledButton.icon(
              onPressed: onRegistrarPago,
              icon: const Icon(Icons.payments_rounded),
              label: Text(pagoEnProceso ? 'Procesando' : 'Registrar pago'),
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
  final TextEditingController interesController;
  final TextEditingController plazoController;
  final TextEditingController observacionController;
  final bool guardando;
  final ValueChanged<String?> onClienteChanged;
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
    final Widget contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DropdownButtonFormField<String>(
          key: ValueKey<String?>('cliente-$clienteId'),
          isExpanded: true,
          initialValue: clienteId,
          decoration: const InputDecoration(
            labelText: 'Cliente',
            prefixIcon: Icon(Icons.person_rounded),
          ),
          items: clientes
              .map(
                (Cliente cliente) => DropdownMenuItem<String>(
                  value: cliente.id,
                  child: Text(cliente.nombreCompleto),
                ),
              )
              .toList(growable: false),
          onChanged: guardando || clienteBloqueado ? null : onClienteChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: ValueKey<String?>('ruta-$rutaId'),
          isExpanded: true,
          initialValue: rutaId,
          decoration: const InputDecoration(
            labelText: 'Ruta',
            prefixIcon: Icon(Icons.route_rounded),
          ),
          hint: const Text('Automatica'),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Automatica'),
            ),
            ...rutas.map(
              (RutaCatalogo ruta) => DropdownMenuItem<String?>(
                value: ruta.id,
                child: Text(ruta.nombre),
              ),
            ),
          ],
          onChanged: guardando ? null : onRutaChanged,
        ),
        const SizedBox(height: 12),
        _DosColumnas(
          left: DropdownButtonFormField<String>(
            key: ValueKey<String?>('moneda-$monedaCodigo'),
            isExpanded: true,
            initialValue: monedaCodigo,
            decoration: const InputDecoration(
              labelText: 'Moneda',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
            items: monedas
                .map(
                  (Moneda moneda) => DropdownMenuItem<String>(
                    value: moneda.codigo,
                    child: Text(moneda.codigo),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando || monedaBloqueada ? null : onMonedaChanged,
          ),
          right: DropdownButtonFormField<int>(
            key: ValueKey<String>('frecuencia-$frecuenciaPagoId'),
            isExpanded: true,
            initialValue: frecuenciaPagoId,
            decoration: const InputDecoration(
              labelText: 'Frecuencia',
              prefixIcon: Icon(Icons.event_repeat_rounded),
            ),
            items: frecuencias
                .map(
                  (FrecuenciaPago frecuencia) => DropdownMenuItem<int>(
                    value: frecuencia.id,
                    child: Text(frecuencia.nombre),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando ? null : onFrecuenciaChanged,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: ValueKey<String?>('caja-$cajaMenorId'),
          isExpanded: true,
          initialValue: cajaMenorId,
          decoration: const InputDecoration(
            labelText: 'Caja menor',
            prefixIcon: Icon(Icons.savings_rounded),
          ),
          items: cajasMenores
              .map(
                (CajaMenorCatalogo caja) => DropdownMenuItem<String?>(
                  value: caja.id,
                  child: Text(caja.nombre),
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
        DropdownButtonFormField<String?>(
          key: ValueKey<String?>('nuevo-cliente-modal-ruta-$rutaId'),
          isExpanded: true,
          initialValue: rutaId,
          decoration: const InputDecoration(
            labelText: 'Ruta',
            prefixIcon: Icon(Icons.route_rounded),
          ),
          hint: const Text('Automatica'),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Automatica'),
            ),
            ...rutas.map(
              (RutaCatalogo ruta) => DropdownMenuItem<String?>(
                value: ruta.id,
                child: Text(ruta.nombre),
              ),
            ),
          ],
          onChanged: guardando ? null : onRutaChanged,
        ),
        const SizedBox(height: 12),
        _DosColumnas(
          left: DropdownButtonFormField<String>(
            key: ValueKey<String?>('nuevo-cliente-modal-moneda-$monedaCodigo'),
            isExpanded: true,
            initialValue: monedaCodigo,
            decoration: const InputDecoration(
              labelText: 'Moneda',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
            items: monedas
                .map(
                  (Moneda moneda) => DropdownMenuItem<String>(
                    value: moneda.codigo,
                    child: Text(moneda.codigo),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando ? null : onMonedaChanged,
          ),
          right: DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'nuevo-cliente-modal-frecuencia-$frecuenciaPagoId',
            ),
            isExpanded: true,
            initialValue: frecuenciaPagoId,
            decoration: const InputDecoration(
              labelText: 'Frecuencia',
              prefixIcon: Icon(Icons.event_repeat_rounded),
            ),
            items: frecuencias
                .map(
                  (FrecuenciaPago frecuencia) => DropdownMenuItem<int>(
                    value: frecuencia.id,
                    child: Text(frecuencia.nombre),
                  ),
                )
                .toList(growable: false),
            onChanged: guardando ? null : onFrecuenciaChanged,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: ValueKey<String?>('nuevo-cliente-modal-caja-$cajaMenorId'),
          isExpanded: true,
          initialValue: cajaMenorId,
          decoration: const InputDecoration(
            labelText: 'Caja menor',
            prefixIcon: Icon(Icons.savings_rounded),
          ),
          items: cajasMenores
              .map(
                (CajaMenorCatalogo caja) => DropdownMenuItem<String?>(
                  value: caja.id,
                  child: Text(caja.nombre),
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
    required this.esAdministrador,
    required this.onModificar,
    required this.onEliminar,
  });

  final MovimientoCaja movimiento;
  final bool esAdministrador;
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
          if (esAdministrador && movimiento.esEditablePorAdmin) ...<Widget>[
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
                return const <PopupMenuEntry<_AccionMovimientoCaja>>[
                  PopupMenuItem<_AccionMovimientoCaja>(
                    value: _AccionMovimientoCaja.modificar,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('Modificar'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_AccionMovimientoCaja>(
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

class _ClienteItem extends StatelessWidget {
  const _ClienteItem({required this.cliente});

  final Cliente cliente;

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
  crearEmpleado,
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
  atrasado;

  EstadoCobro? get estadoCobro {
    return switch (this) {
      _FiltroEstadoRuta.todos => null,
      _FiltroEstadoRuta.alDia => EstadoCobro.alDia,
      _FiltroEstadoRuta.pendiente => EstadoCobro.pendiente,
      _FiltroEstadoRuta.atrasado => EstadoCobro.atrasado,
    };
  }

  String? get wire {
    return switch (this) {
      _FiltroEstadoRuta.todos => null,
      _FiltroEstadoRuta.alDia => 'AL_DIA',
      _FiltroEstadoRuta.pendiente => 'PENDIENTE',
      _FiltroEstadoRuta.atrasado => 'ATRASADO',
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
      filas: json['filas'] as int,
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
}

class SesionUsuario {
  const SesionUsuario({
    required this.id,
    required this.usuario,
    required this.nombreCompleto,
    required this.correo,
    required this.roles,
    required this.esAdministrador,
  });

  factory SesionUsuario.fromJson(Map<String, dynamic> json) {
    final Object? rawRoles = json['roles'];

    return SesionUsuario(
      id: json['id'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      correo: json['correo'] as String,
      roles: rawRoles is List<dynamic>
          ? rawRoles.whereType<String>().toList(growable: false)
          : const <String>[],
      esAdministrador: json['esAdministrador'] as bool? ?? false,
    );
  }

  final String id;
  final String usuario;
  final String nombreCompleto;
  final String correo;
  final List<String> roles;
  final bool esAdministrador;
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
      .where((CajaMenorCatalogo caja) => caja.activa)
      .toList(growable: false);
}

class UsuarioCatalogo {
  const UsuarioCatalogo({required this.id, required this.nombreCompleto});

  factory UsuarioCatalogo.fromJson(Map<String, dynamic> json) {
    return UsuarioCatalogo(
      id: json['id'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
    );
  }

  final String id;
  final String nombreCompleto;
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
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      diasIntervalo: json['diasIntervalo'] as int,
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
  });

  factory CajaMenorCatalogo.fromJson(Map<String, dynamic> json) {
    return CajaMenorCatalogo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      activa: json['activa'] as bool,
      monedaCodigo: json['monedaCodigo'] as String,
      fechaApertura: _fechaNullable(json['fechaApertura']),
      fechaCierre: _fechaNullable(json['fechaCierre']),
    );
  }

  final String id;
  final String nombre;
  final bool activa;
  final String monedaCodigo;
  final DateTime? fechaApertura;
  final DateTime? fechaCierre;
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
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> estado = json['estado'] as Map<String, dynamic>;
    return Cliente(
      id: json['id'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      cedula: json['cedula'] as String?,
      direccion: json['direccion'] as String?,
      nombreComercial: json['nombreComercial'] as String?,
      correo: json['correo'] as String?,
      telefono: json['telefono'] as String?,
      estadoNombre: estado['nombre'] as String,
    );
  }

  final String id;
  final String nombreCompleto;
  final String? cedula;
  final String? direccion;
  final String? nombreComercial;
  final String? correo;
  final String? telefono;
  final String estadoNombre;
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
      rutaId: json['rutaId'] as String,
      ruta: json['ruta'] as String,
      cajaMenorId: json['cajaMenorId'] as String?,
      cajaMenor: json['cajaMenor'] as String?,
      monedaCodigo: json['monedaCodigo'] as String,
      frecuenciaPago: FrecuenciaPago.fromJson(
        json['frecuenciaPago'] as Map<String, dynamic>,
      ),
      estado: EstadoCreditoRegistro.fromJson(
        json['estado'] as Map<String, dynamic>,
      ),
      fechaInicio: DateTime.parse(json['fechaInicio'] as String),
      valorPrincipal: _doble(json['valorPrincipal']),
      porcentajeInteres: _doble(json['porcentajeInteres']),
      plazoDias: json['plazoDias'] as int,
      omitirDomingos: json['omitirDomingos'] as bool? ?? true,
      valorTotal: _doble(json['valorTotal']),
      valorCuota: _doble(json['valorCuota']),
      totalAbonado: _doble(json['totalAbonado']),
      saldo: _doble(json['saldo']),
      numeroCuotas: json['numeroCuotas'] as int,
      cuotasRestantes: json['cuotasRestantes'] as int,
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

  bool get activo => !<String>{'PAGADO', 'ANULADO'}.contains(estado.codigo);

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

class CobroRuta {
  const CobroRuta({
    required this.id,
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
    this.proximaCuotaId,
    this.proximaNumeroCuota,
    this.proximaFechaPago,
  });

  factory CobroRuta.fromJson(Map<String, dynamic> json) {
    return CobroRuta(
      id: json['id'] as String,
      cliente: json['cliente'] as String,
      cedula: json['cedula'] as String?,
      negocio: json['negocio'] as String?,
      direccion: json['direccion'] as String?,
      rutaId: json['rutaId'] as String,
      ruta: json['ruta'] as String,
      valorTotal: _doble(json['valorTotal']),
      valorCuota: _doble(json['valorCuota']),
      totalAbonado: _doble(json['totalAbonado']),
      saldo: _doble(json['saldo']),
      numeroCuotas: json['numeroCuotas'] as int,
      cuotasRestantes: json['cuotasRestantes'] as int,
      proximaCuotaId: json['proximaCuotaId'] as String?,
      proximaNumeroCuota: json['proximaNumeroCuota'] as int?,
      proximaFechaPago: _fechaNullable(json['proximaFechaPago']),
      proximoSaldoCuota: _doble(json['proximoSaldoCuota']),
      estadoCobro: EstadoCobro.fromWire(json['estadoCobro'] as String),
    );
  }

  static const Object _sinCambio = Object();

  CobroRuta copyWith({
    double? totalAbonado,
    double? saldo,
    int? cuotasRestantes,
    Object? proximaCuotaId = _sinCambio,
    double? proximoSaldoCuota,
  }) {
    return CobroRuta(
      id: id,
      cliente: cliente,
      cedula: cedula,
      negocio: negocio,
      direccion: direccion,
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
      proximaNumeroCuota: proximaNumeroCuota,
      proximaFechaPago: proximaFechaPago,
      proximoSaldoCuota: proximoSaldoCuota ?? this.proximoSaldoCuota,
      estadoCobro: estadoCobro,
    );
  }

  final String id;
  final String cliente;
  final String? cedula;
  final String? negocio;
  final String? direccion;
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
    required this.monedaCodigo,
    required this.cajaMenor,
    required this.recaudado,
    required this.gastos,
    required this.creditos,
    required this.presupuesto,
  });

  factory PresupuestoItem.fromJson(Map<String, dynamic> json) {
    return PresupuestoItem(
      cajaMenorId: json['cajaMenorId'] as String? ?? '',
      monedaCodigo: json['monedaCodigo'] as String,
      cajaMenor: _doble(json['cajaMenor']),
      recaudado: _doble(json['recaudado']),
      gastos: _doble(json['gastos']).abs(),
      creditos: _doble(json['creditos']),
      presupuesto: _doble(json['presupuesto']),
    );
  }

  final String cajaMenorId;
  final String monedaCodigo;
  final double cajaMenor;
  final double recaudado;
  final double gastos;
  final double creditos;
  final double presupuesto;
}

class PresupuestoTotales {
  const PresupuestoTotales({
    required this.cajaMenor,
    required this.recaudado,
    required this.gastos,
    required this.creditos,
    required this.presupuesto,
  });

  const PresupuestoTotales.vacio()
      : cajaMenor = 0,
        recaudado = 0,
        gastos = 0,
        creditos = 0,
        presupuesto = 0;

  factory PresupuestoTotales.fromJson(Map<String, dynamic> json) {
    return PresupuestoTotales(
      cajaMenor: _doble(json['cajaMenor']),
      recaudado: _doble(json['recaudado']),
      gastos: _doble(json['gastos']).abs(),
      creditos: _doble(json['creditos']),
      presupuesto: _doble(json['presupuesto']),
    );
  }

  final double cajaMenor;
  final double recaudado;
  final double gastos;
  final double creditos;
  final double presupuesto;
}

enum EstadoCobro {
  alDia,
  pendiente,
  atrasado;

  factory EstadoCobro.fromWire(String value) {
    return switch (value) {
      'AL_DIA' => EstadoCobro.alDia,
      'PENDIENTE' => EstadoCobro.pendiente,
      'ATRASADO' => EstadoCobro.atrasado,
      _ => EstadoCobro.pendiente,
    };
  }

  String get etiqueta {
    return switch (this) {
      EstadoCobro.alDia => 'Al día',
      EstadoCobro.pendiente => 'Debe hoy',
      EstadoCobro.atrasado => 'Atrasado',
    };
  }

  Color get color {
    return switch (this) {
      EstadoCobro.alDia => CobroAppTheme.success,
      EstadoCobro.pendiente => CobroAppTheme.warning,
      EstadoCobro.atrasado => CobroAppTheme.danger,
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
