import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapcn_flutter/mapcn_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../core/map/map_tiles.dart';
import '../../../core/ui/clay.dart';
import '../data/device_location_service.dart';
import '../data/osrm_road_router.dart';
import '../domain/dijkstra_route_planner.dart';

typedef CollectionCustomerCardBuilder = Widget Function(
  BuildContext context,
  CollectionMapCustomer customer,
  bool selected,
  VoidCallback onSelected,
);

class CollectionMapCustomer {
  const CollectionMapCustomer({
    required this.id,
    required this.customerId,
    required this.creditId,
    required this.name,
    required this.routeName,
    required this.amountLabel,
    required this.installmentLabel,
    required this.balanceLabel,
    required this.dueDateLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.canCollect,
    required this.canRoute,
    required this.isDueNow,
    this.identification,
    this.business,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String customerId;
  final String creditId;
  final String name;
  final String routeName;
  final String amountLabel;
  final String installmentLabel;
  final String balanceLabel;
  final String dueDateLabel;
  final String statusLabel;
  final Color statusColor;
  final bool canCollect;
  final bool canRoute;
  final bool isDueNow;
  final String? identification;
  final String? business;
  final String? address;
  final double? latitude;
  final double? longitude;

  bool get hasLocation {
    final double? lat = latitude;
    final double? lon = longitude;
    return lat != null &&
        lon != null &&
        lat.isFinite &&
        lon.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180;
  }

  LatLng? get point => hasLocation ? LatLng(latitude!, longitude!) : null;
}

/// Desktop-only split view. It deliberately keeps list and map state together
/// so a selection from either side always produces the same focus and tooltip.
class DesktopCollectionRoute extends StatefulWidget {
  const DesktopCollectionRoute({
    required this.header,
    required this.filters,
    required this.summary,
    required this.customers,
    required this.cardBuilder,
    required this.onRefresh,
    required this.onCollect,
    required this.roadRouter,
    this.error,
    this.locationService,
    super.key,
  });

  final Widget header;
  final Widget filters;
  final Widget summary;
  final List<CollectionMapCustomer> customers;
  final CollectionCustomerCardBuilder cardBuilder;
  final Future<void> Function() onRefresh;
  final ValueChanged<CollectionMapCustomer> onCollect;
  final Widget? error;
  final RouteLocationService? locationService;
  final RoadRouter roadRouter;

  @override
  State<DesktopCollectionRoute> createState() => _DesktopCollectionRouteState();
}

class _DesktopCollectionRouteState extends State<DesktopCollectionRoute> {
  final GlobalKey<_CollectionRouteMapPanelState> _mapPanelKey =
      GlobalKey<_CollectionRouteMapPanelState>();
  late _MemoizedRouteLocationService _locationService;
  LatLng? _listOrigin;
  int _listOriginGeneration = 0;
  String? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _locationService = _MemoizedRouteLocationService(
      widget.locationService ?? const DeviceRouteLocationService(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadListOrigin());
      }
    });
  }

  @override
  void didUpdateWidget(DesktopCollectionRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.locationService, oldWidget.locationService)) {
      _locationService = _MemoizedRouteLocationService(
        widget.locationService ?? const DeviceRouteLocationService(),
      );
      unawaited(_loadListOrigin());
    }
    if (_selectedCustomerId != null &&
        !widget.customers.any(
          (CollectionMapCustomer customer) =>
              customer.id == _selectedCustomerId,
        )) {
      _selectedCustomerId = null;
    }
  }

  Future<void> _loadListOrigin() async {
    final int generation = ++_listOriginGeneration;
    try {
      final LatLng origin = await _locationService.currentPosition();
      if (!mounted || generation != _listOriginGeneration) {
        return;
      }
      setState(() => _listOrigin = origin);
    } on Object {
      if (!mounted || generation != _listOriginGeneration) {
        return;
      }
      setState(() => _listOrigin = null);
    }
  }

  void _toggleCustomer(CollectionMapCustomer customer) {
    if (_selectedCustomerId == customer.id) {
      setState(() => _selectedCustomerId = null);
      return;
    }
    setState(() => _selectedCustomerId = customer.id);
  }

  void _selectCustomer(CollectionMapCustomer customer) {
    if (_selectedCustomerId != customer.id) {
      setState(() => _selectedCustomerId = customer.id);
    }
  }

  void _clearCustomerSelection() {
    if (_selectedCustomerId != null) {
      setState(() => _selectedCustomerId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final List<CollectionMapCustomer> orderedCustomers =
        _orderCustomersFromOrigin(widget.customers, _listOrigin);
    final CollectionMapCustomer? selected = _selectedCustomerId == null
        ? null
        : orderedCustomers.cast<CollectionMapCustomer?>().firstWhere(
              (CollectionMapCustomer? customer) =>
                  customer?.id == _selectedCustomerId,
              orElse: () => null,
            );

    return ColoredBox(
      color: clay.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 47,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: clay.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: clay.border),
                  boxShadow: clay.raisedShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            widget.header,
                            if (widget.error != null) ...<Widget>[
                              const SizedBox(height: 12),
                              widget.error!,
                            ],
                            const SizedBox(height: 12),
                            widget.filters,
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: widget.summary,
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: clay.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${orderedCustomers.length} cobros en la ruta',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Text(
                              '${widget.customers.where((CollectionMapCustomer item) => item.hasLocation).length} ubicados',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: clay.subtleText),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: orderedCustomers.isEmpty
                            ? _RouteListEmpty(clay: clay)
                            : RefreshIndicator(
                                onRefresh: widget.onRefresh,
                                child: ListView.builder(
                                  key: const PageStorageKey<String>(
                                    'desktop-route-list',
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    6,
                                    14,
                                    18,
                                  ),
                                  itemCount: orderedCustomers.length,
                                  itemBuilder: (
                                    BuildContext context,
                                    int index,
                                  ) {
                                    final CollectionMapCustomer customer =
                                        orderedCustomers[index];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: widget.cardBuilder(
                                        context,
                                        customer,
                                        customer.id == _selectedCustomerId,
                                        () => _toggleCustomer(customer),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 53,
              child: CollectionRouteMapPanel(
                key: _mapPanelKey,
                customers: orderedCustomers,
                selectedCustomer: selected,
                onCustomerSelected: _selectCustomer,
                onSelectionCleared: _clearCustomerSelection,
                onCollect: widget.onCollect,
                locationService: _locationService,
                roadRouter: widget.roadRouter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<CollectionMapCustomer> _orderCustomersFromOrigin(
    List<CollectionMapCustomer> customers,
    LatLng? origin,
  ) {
    if (origin == null) {
      return customers;
    }

    final Distance distance = const Distance();
    final List<MapEntry<int, CollectionMapCustomer>> indexed =
        customers.asMap().entries.toList(growable: false);
    indexed.sort(
      (
        MapEntry<int, CollectionMapCustomer> left,
        MapEntry<int, CollectionMapCustomer> right,
      ) {
        final bool leftLocated = left.value.hasLocation;
        final bool rightLocated = right.value.hasLocation;
        if (leftLocated != rightLocated) {
          return leftLocated ? -1 : 1;
        }
        if (!leftLocated) {
          return left.key.compareTo(right.key);
        }

        final int distanceComparison = distance
            .as(LengthUnit.Meter, origin, left.value.point!)
            .compareTo(
              distance.as(LengthUnit.Meter, origin, right.value.point!),
            );
        if (distanceComparison != 0) {
          return distanceComparison;
        }

        final int nameComparison = left.value.name.compareTo(right.value.name);
        return nameComparison != 0
            ? nameComparison
            : left.value.id.compareTo(right.value.id);
      },
    );
    return indexed
        .map((MapEntry<int, CollectionMapCustomer> entry) => entry.value)
        .toList(growable: false);
  }
}

class _RouteListEmpty extends StatelessWidget {
  const _RouteListEmpty({required this.clay});

  final ClayTokens clay;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        const SizedBox(height: 54),
        Icon(Icons.route_outlined, size: 42, color: clay.subtleText),
        const SizedBox(height: 12),
        Text(
          'Sin cobros para mostrar',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          'Prueba con otro filtro o actualiza los datos.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: clay.subtleText),
        ),
      ],
    );
  }
}

class CollectionRouteMapPanel extends StatefulWidget {
  const CollectionRouteMapPanel({
    required this.customers,
    required this.selectedCustomer,
    required this.onCustomerSelected,
    required this.onSelectionCleared,
    required this.onCollect,
    required this.roadRouter,
    this.locationService,
    super.key,
  });

  final List<CollectionMapCustomer> customers;
  final CollectionMapCustomer? selectedCustomer;
  final ValueChanged<CollectionMapCustomer> onCustomerSelected;
  final VoidCallback onSelectionCleared;
  final ValueChanged<CollectionMapCustomer> onCollect;
  final RouteLocationService? locationService;
  final RoadRouter roadRouter;

  @override
  State<CollectionRouteMapPanel> createState() =>
      _CollectionRouteMapPanelState();
}

class _CollectionRouteMapPanelState extends State<CollectionRouteMapPanel>
    with TickerProviderStateMixin {
  static const LatLng _riohacha = LatLng(11.5444, -72.9072);
  static const int _matrixBatchSize = 24;
  static const int _matrixConcurrency = 3;
  static const double _fallbackDrivingMetersPerSecond = 8.33;
  static const double _routeSimplificationTolerance = 0.00006;
  static const double _routeWaypointToleranceMeters = 80;
  static const Duration _routeDebounceDuration = Duration(milliseconds: 70);
  static const Duration _focusDuration = Duration(milliseconds: 280);
  static const Duration _fitDuration = Duration(milliseconds: 320);
  static const Duration _zoomDuration = Duration(milliseconds: 180);

  late final MapcnController _mapController;
  late final RouteLocationService _locationService;

  LatLng? _currentPosition;
  List<LatLng> _routePoints = const <LatLng>[];
  RoadRoute? _roadRoute;
  bool _mapReady = false;
  bool _calculating = false;
  bool _usingApproximateRoute = false;
  String? _statusMessage;
  String? _routeTargetId;
  int _calculationGeneration = 0;
  int _routeRequestGeneration = 0;
  Timer? _routeDebounce;
  final ValueNotifier<int> _cameraRevision = ValueNotifier<int>(0);
  AnimationController? _cameraAnimation;

  List<CollectionMapCustomer> get _locatedCustomers {
    final Map<String, CollectionMapCustomer> unique =
        <String, CollectionMapCustomer>{};
    for (final CollectionMapCustomer customer in widget.customers) {
      if (customer.hasLocation) {
        final bool isSelected = customer.id == widget.selectedCustomer?.id;
        if (isSelected || !unique.containsKey(customer.customerId)) {
          unique[customer.customerId] = customer;
        }
      }
    }
    return unique.values.toList(growable: false);
  }

  List<CollectionMapCustomer> get _routableCustomers {
    final Map<String, CollectionMapCustomer> unique =
        <String, CollectionMapCustomer>{};
    for (final CollectionMapCustomer customer in widget.customers) {
      if (customer.hasLocation && customer.canRoute) {
        unique.putIfAbsent(customer.customerId, () => customer);
      }
    }
    return unique.values.toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapcnController(vsync: this);
    _locationService =
        widget.locationService ?? const DeviceRouteLocationService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scheduleAutomaticRoute();
      }
    });
  }

  @override
  void didUpdateWidget(CollectionRouteMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool routingChanged = _routingSignature(widget.customers) !=
        _routingSignature(oldWidget.customers);
    if (routingChanged) {
      _calculationGeneration++;
      _routeDebounce?.cancel();
      _calculating = false;
      _statusMessage = 'Actualizando la ruta automática…';
    }
    final CollectionMapCustomer? selected = widget.selectedCustomer;
    final CollectionMapCustomer? oldSelected = oldWidget.selectedCustomer;
    final bool selectionChanged = selected?.id != oldSelected?.id ||
        selected?.point != oldSelected?.point;
    if (selectionChanged && selected?.point != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusCustomer(selected!);
        }
      });
    }
    if (routingChanged && _mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scheduleAutomaticRoute();
        }
      });
    }
  }

  String _routingSignature(List<CollectionMapCustomer> customers) {
    final List<String> candidates = customers
        .map(
          (CollectionMapCustomer customer) =>
              '${customer.id}:${customer.customerId}:${customer.latitude}:${customer.longitude}:${customer.canRoute}',
        )
        .toList(growable: false)
      ..sort();
    return candidates.join('|');
  }

  Future<List<RoadTravelEstimate?>?> _estimateAllTrips({
    required LatLng origin,
    required List<CollectionMapCustomer> customers,
    required int calculationGeneration,
  }) async {
    final int batchCount = (customers.length / _matrixBatchSize).ceil();
    final List<List<RoadTravelEstimate?>?> batches =
        List<List<RoadTravelEstimate?>?>.filled(batchCount, null);
    var nextBatch = 0;
    var failed = false;

    Future<void> worker() async {
      while (!failed) {
        final int batchIndex = nextBatch++;
        if (batchIndex >= batchCount) {
          return;
        }
        final int start = batchIndex * _matrixBatchSize;
        final int end = math.min(start + _matrixBatchSize, customers.length);
        final List<CollectionMapCustomer> batch = customers.sublist(start, end);
        final List<RoadTravelEstimate?>? estimates =
            await _router.estimateTrips(
          origin: origin,
          destinations: batch
              .map((CollectionMapCustomer customer) => customer.point!)
              .toList(growable: false),
        );
        if (!mounted || calculationGeneration != _calculationGeneration) {
          failed = true;
          return;
        }
        if (estimates == null || estimates.length != batch.length) {
          failed = true;
          return;
        }
        batches[batchIndex] = estimates;
      }
    }

    await Future.wait<void>(
      List<Future<void>>.generate(
        math.min(batchCount, _matrixConcurrency),
        (_) => worker(),
        growable: false,
      ),
    );
    if (failed || batches.any((batch) => batch == null)) {
      return null;
    }
    return batches
        .expand((List<RoadTravelEstimate?>? batch) => batch!)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _routeDebounce?.cancel();
    _cancelCameraAnimation();
    _cameraRevision.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _selectCustomerFromMap(CollectionMapCustomer customer) {
    if (widget.selectedCustomer?.id == customer.id && !_calculating) {
      _focusCustomer(customer);
      return;
    }
    widget.onCustomerSelected(customer);
  }

  void _clearSelectionFromMap() {
    widget.onSelectionCleared();
  }

  void _scheduleAutomaticRoute() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(_routeDebounceDuration, () {
      _routeDebounce = null;
      if (mounted) {
        unawaited(_calculateCollectionRoute());
      }
    });
  }

  Future<void> _calculateCollectionRoute() async {
    final int calculationGeneration = ++_calculationGeneration;
    _routeRequestGeneration++;
    _routeTargetId = null;
    final List<CollectionMapCustomer> eligible = _routableCustomers;
    if (eligible.isEmpty) {
      setState(() {
        _calculating = false;
        _routePoints = const <LatLng>[];
        _roadRoute = null;
        _usingApproximateRoute = false;
        _statusMessage = widget.customers.isEmpty
            ? 'No hay cobros activos para trazar.'
            : _locatedCustomers.isEmpty
                ? 'Agrega coordenadas para crear la ruta automática.'
                : 'No hay cobros activos con ubicación.';
      });
      return;
    }

    setState(() {
      _calculating = true;
      _statusMessage = 'Calculando la ruta por todos los cobros…';
    });

    try {
      final LatLng origin = await _locationService.currentPosition();
      if (!mounted || calculationGeneration != _calculationGeneration) {
        return;
      }
      final List<CollectionMapCustomer> orderedCustomers =
          _nearestToFarthestCustomers(origin, eligible);
      final List<LatLng> destinations = orderedCustomers
          .map((CollectionMapCustomer customer) => customer.point!)
          .toList(growable: false);
      final List<LatLng> fallbackRoutePoints =
          _collectionRoutePath(origin, destinations);
      final RoadRoute fallbackRoute = _fallbackRoadRoute(fallbackRoutePoints);
      setState(() {
        _currentPosition = origin;
        _roadRoute = fallbackRoute;
        _routePoints = List<LatLng>.unmodifiable(fallbackRoutePoints);
        _usingApproximateRoute = true;
        _statusMessage = 'Preparando ${eligible.length} paradas…';
      });
      if (_mapReady) {
        _fitPoints(_routePoints, padding: 72, maxZoom: 15.5);
      }

      RoadRoute? roadRoute;
      try {
        roadRoute = await _router.routeThrough(
          origin: origin,
          destinations: destinations,
        );
      } on Object {
        roadRoute = null;
      }
      if (!mounted || calculationGeneration != _calculationGeneration) {
        return;
      }
      if (roadRoute != null &&
          !_routeVisitsDestinations(roadRoute.points, destinations)) {
        roadRoute = null;
      }

      final List<LatLng> rawPoints = roadRoute?.points ?? fallbackRoutePoints;
      List<LatLng> routePoints;
      try {
        routePoints = rawPoints.length > 2
            ? RouteUtils.simplifyRoute(
                rawPoints,
                tolerance: _routeSimplificationTolerance,
              )
            : rawPoints;
      } on Object {
        roadRoute = null;
        routePoints = fallbackRoutePoints;
      }
      if (routePoints.length < 2) {
        roadRoute = null;
        routePoints = fallbackRoutePoints;
      }
      if (roadRoute != null &&
          !_routeVisitsDestinations(routePoints, destinations)) {
        routePoints = rawPoints;
      }

      final bool approximate = roadRoute == null;
      setState(() {
        _roadRoute = roadRoute ?? fallbackRoute;
        _routePoints = List<LatLng>.unmodifiable(routePoints);
        _usingApproximateRoute = approximate;
        _statusMessage = approximate
            ? '${eligible.length} paradas enlazadas con una guía aproximada.'
            : 'Ruta automática por ${eligible.length} paradas.';
      });
      if (_mapReady) {
        _fitPoints(_routePoints, padding: 72, maxZoom: 15.5);
      }
    } on RouteLocationException catch (error) {
      if (mounted && calculationGeneration == _calculationGeneration) {
        setState(() => _statusMessage = error.message);
      }
    } on Object {
      if (mounted && calculationGeneration == _calculationGeneration) {
        setState(() {
          _statusMessage = 'No pudimos calcular la ruta automática.';
        });
      }
    } finally {
      if (mounted && calculationGeneration == _calculationGeneration) {
        setState(() => _calculating = false);
      }
    }
  }

  List<LatLng> _collectionRoutePath(
    LatLng origin,
    List<LatLng> destinations,
  ) =>
      <LatLng>[origin, ...destinations];

  List<CollectionMapCustomer> _nearestToFarthestCustomers(
    LatLng origin,
    List<CollectionMapCustomer> customers,
  ) {
    final Distance distance = const Distance();
    final List<CollectionMapCustomer> ordered =
        customers.toList(growable: false);
    ordered.sort((CollectionMapCustomer left, CollectionMapCustomer right) {
      final int distanceComparison = distance
          .as(LengthUnit.Meter, origin, left.point!)
          .compareTo(distance.as(LengthUnit.Meter, origin, right.point!));
      if (distanceComparison != 0) {
        return distanceComparison;
      }

      final int nameComparison = left.name.compareTo(right.name);
      return nameComparison != 0 ? nameComparison : left.id.compareTo(right.id);
    });
    return ordered;
  }

  CollectionMapCustomer _nearestCustomerByDijkstra(
    LatLng origin,
    List<CollectionMapCustomer> customers,
  ) {
    final Distance distance = const Distance();
    final List<GeoNode<CollectionMapCustomer?>> nodes =
        <GeoNode<CollectionMapCustomer?>>[
      GeoNode<CollectionMapCustomer?>(
        id: 'origin',
        latitude: origin.latitude,
        longitude: origin.longitude,
        value: null,
      ),
    ];
    final List<WeightedGeoEdge> edges = <WeightedGeoEdge>[];
    for (final CollectionMapCustomer customer in customers) {
      final String nodeId = 'customer:${customer.id}';
      nodes.add(
        GeoNode<CollectionMapCustomer?>(
          id: nodeId,
          latitude: customer.latitude!,
          longitude: customer.longitude!,
          value: customer,
        ),
      );
      edges.add(
        WeightedGeoEdge(
          from: 'origin',
          to: nodeId,
          weight: distance.as(LengthUnit.Meter, origin, customer.point!),
        ),
      );
    }
    final DijkstraPath<CollectionMapCustomer?>? result =
        DijkstraRoutePlanner<CollectionMapCustomer?>(
      nodes: nodes,
      edges: edges,
    ).findNearest(
      sourceId: 'origin',
      destinationIds: customers
          .map((CollectionMapCustomer customer) => 'customer:${customer.id}'),
    );
    final CollectionMapCustomer? customer = result?.destination.value;
    if (customer == null) {
      throw const RouteLocationException(
        'No encontramos un cliente alcanzable desde tu ubicaciÃ³n.',
      );
    }
    return customer;
  }

  RoadRoute _fallbackRoadRoute(List<LatLng> points) {
    final double meters = _pathDistanceMeters(points);
    return RoadRoute(
      points: points,
      duration: Duration(
        milliseconds:
            ((meters / _fallbackDrivingMetersPerSecond) * 1000).round(),
      ),
      distanceMeters: meters,
    );
  }

  double _pathDistanceMeters(List<LatLng> points) {
    if (points.length < 2) {
      return 0;
    }
    final Distance distance = const Distance();
    var total = 0.0;
    for (var index = 1; index < points.length; index++) {
      total += distance.as(LengthUnit.Meter, points[index - 1], points[index]);
    }
    return total;
  }

  bool _routeVisitsDestinations(
    List<LatLng> routePoints,
    List<LatLng> destinations,
  ) {
    if (routePoints.length < 2 || destinations.isEmpty) {
      return destinations.isEmpty;
    }
    for (final LatLng destination in destinations) {
      if (_distanceToRouteMeters(destination, routePoints) >
          _routeWaypointToleranceMeters) {
        return false;
      }
    }
    return true;
  }

  double _distanceToRouteMeters(LatLng point, List<LatLng> routePoints) {
    var closestMeters = double.infinity;
    for (var index = 1; index < routePoints.length; index++) {
      closestMeters = math.min(
        closestMeters,
        _distanceToSegmentMeters(
          point,
          routePoints[index - 1],
          routePoints[index],
        ),
      );
    }
    return closestMeters;
  }

  double _distanceToSegmentMeters(
    LatLng point,
    LatLng start,
    LatLng end,
  ) {
    final double latitudeMeters = 111320;
    final double longitudeMeters =
        latitudeMeters * math.cos(point.latitude * math.pi / 180);
    final double startX = (start.longitude - point.longitude) * longitudeMeters;
    final double startY = (start.latitude - point.latitude) * latitudeMeters;
    final double endX = (end.longitude - point.longitude) * longitudeMeters;
    final double endY = (end.latitude - point.latitude) * latitudeMeters;
    final double segmentX = endX - startX;
    final double segmentY = endY - startY;
    final double segmentLengthSquared =
        (segmentX * segmentX) + (segmentY * segmentY);
    if (segmentLengthSquared == 0) {
      return math.sqrt((startX * startX) + (startY * startY));
    }
    final double projection =
        ((-startX * segmentX) + (-startY * segmentY)) / segmentLengthSquared;
    final double clampedProjection = projection.clamp(0.0, 1.0).toDouble();
    final double closestX = startX + (segmentX * clampedProjection);
    final double closestY = startY + (segmentY * clampedProjection);
    return math.sqrt((closestX * closestX) + (closestY * closestY));
  }

  LatLng get _initialCenter {
    final List<CollectionMapCustomer> customers = _locatedCustomers;
    if (customers.isEmpty) {
      return _riohacha;
    }
    final double latitude = customers.fold<double>(
          0,
          (double total, CollectionMapCustomer item) => total + item.latitude!,
        ) /
        customers.length;
    final double longitude = customers.fold<double>(
          0,
          (double total, CollectionMapCustomer item) => total + item.longitude!,
        ) /
        customers.length;
    return LatLng(latitude, longitude);
  }

  Future<void> calculateFastestRouteLegacy() async {
    final int calculationGeneration = ++_calculationGeneration;
    _routeDebounce?.cancel();
    _routeDebounce = null;
    _routeRequestGeneration++;
    _routeTargetId = null;
    final List<CollectionMapCustomer> eligible = _routableCustomers;
    if (eligible.isEmpty) {
      setState(() {
        _routePoints = const <LatLng>[];
        _roadRoute = null;
        _usingApproximateRoute = false;
        _statusMessage = widget.customers.isEmpty
            ? 'No hay cobros activos para calcular.'
            : _locatedCustomers.isEmpty
                ? 'Agrega coordenadas a los clientes activos para calcular la ruta.'
                : 'No hay cobros activos con ubicación.';
      });
      return;
    }

    setState(() {
      _calculating = true;
      _routePoints = const <LatLng>[];
      _roadRoute = null;
      _usingApproximateRoute = false;
      _statusMessage = 'Buscando el cobro más rápido por vías…';
    });

    try {
      final LatLng origin = await _locationService.currentPosition();
      if (!mounted || calculationGeneration != _calculationGeneration) {
        return;
      }
      setState(() => _currentPosition = origin);

      final Distance distance = const Distance();
      eligible.sort((CollectionMapCustomer left, CollectionMapCustomer right) {
        final double leftDistance = distance.as(
          LengthUnit.Meter,
          origin,
          left.point!,
        );
        final double rightDistance = distance.as(
          LengthUnit.Meter,
          origin,
          right.point!,
        );
        final int byDistance = leftDistance.compareTo(rightDistance);
        return byDistance != 0 ? byDistance : left.id.compareTo(right.id);
      });

      final List<CollectionMapCustomer> candidates =
          eligible.toList(growable: false);
      final List<RoadTravelEstimate?>? roadEstimates = await _estimateAllTrips(
        origin: origin,
        customers: candidates,
        calculationGeneration: calculationGeneration,
      );
      if (!mounted || calculationGeneration != _calculationGeneration) {
        return;
      }
      final bool usingApproximateEstimates = roadEstimates == null;

      final Map<String, bool> approximateEstimateByCustomerId =
          <String, bool>{};
      final List<GeoNode<CollectionMapCustomer?>> nodes =
          <GeoNode<CollectionMapCustomer?>>[
        GeoNode<CollectionMapCustomer?>(
          id: 'origin',
          latitude: origin.latitude,
          longitude: origin.longitude,
          value: null,
        ),
      ];
      final List<WeightedGeoEdge> edges = <WeightedGeoEdge>[];
      for (var index = 0; index < candidates.length; index++) {
        final CollectionMapCustomer customer = candidates[index];
        final RoadTravelEstimate? estimate =
            roadEstimates?.elementAtOrNull(index);
        final double fallbackMeters = distance.as(
          LengthUnit.Meter,
          origin,
          customer.point!,
        );
        final double weight = usingApproximateEstimates
            ? (fallbackMeters / _fallbackDrivingMetersPerSecond) * 1000
            : estimate?.duration.inMilliseconds.toDouble() ?? double.infinity;
        approximateEstimateByCustomerId[customer.id] =
            usingApproximateEstimates;
        final String nodeId = 'customer:${customer.id}';
        nodes.add(
          GeoNode<CollectionMapCustomer?>(
            id: nodeId,
            latitude: customer.latitude!,
            longitude: customer.longitude!,
            value: customer,
          ),
        );
        if (weight.isFinite) {
          edges.add(
            WeightedGeoEdge(
              from: 'origin',
              to: nodeId,
              weight: weight,
              bidirectional: true,
            ),
          );
        }
      }

      final DijkstraRoutePlanner<CollectionMapCustomer?> planner =
          DijkstraRoutePlanner<CollectionMapCustomer?>(
        nodes: nodes,
        edges: edges,
      );
      final DijkstraPath<CollectionMapCustomer?>? fastest = planner.findNearest(
        sourceId: 'origin',
        destinationIds: candidates
            .map((CollectionMapCustomer item) => 'customer:${item.id}'),
      );
      final CollectionMapCustomer? customer = fastest?.destination.value;
      if (customer == null) {
        throw const RouteLocationException(
          'No encontramos un cliente alcanzable desde tu ubicación.',
        );
      }

      final bool customerStillEligible = _routableCustomers.any(
        (CollectionMapCustomer current) => current.id == customer.id,
      );
      if (!customerStillEligible ||
          calculationGeneration != _calculationGeneration) {
        return;
      }

      setState(() {
        _routePoints = const <LatLng>[];
        _roadRoute = null;
        _usingApproximateRoute = false;
        _statusMessage = 'Trazando la mejor ruta vial…';
      });
      widget.onCustomerSelected(customer);
      await _drawRouteTo(
        customer,
        fitRoute: true,
        selectedByDijkstra: true,
        approximateSelection:
            approximateEstimateByCustomerId[customer.id] ?? true,
      );
    } on RouteLocationException catch (error) {
      if (mounted && calculationGeneration == _calculationGeneration) {
        setState(() => _statusMessage = error.message);
      }
    } catch (_) {
      if (mounted && calculationGeneration == _calculationGeneration) {
        setState(() {
          _statusMessage =
              'No pudimos calcular la ruta. Revisa la conexión e inténtalo de nuevo.';
        });
      }
    } finally {
      if (mounted && calculationGeneration == _calculationGeneration) {
        setState(() => _calculating = false);
      }
    }
  }

  Future<void> _drawRouteTo(
    CollectionMapCustomer customer, {
    bool fitRoute = false,
    bool selectedByDijkstra = false,
    bool approximateSelection = false,
  }) async {
    final LatLng? origin = _currentPosition;
    final LatLng? destination = customer.point;
    if (origin == null || destination == null) {
      return;
    }

    _routeTargetId = customer.id;
    final int requestGeneration = ++_routeRequestGeneration;

    RoadRoute? roadRoute;
    try {
      roadRoute = await _router.route(
        origin: origin,
        destination: destination,
      );
    } on Object {
      roadRoute = null;
    }
    if (!mounted ||
        _routeTargetId != customer.id ||
        requestGeneration != _routeRequestGeneration) {
      return;
    }

    final List<LatLng> rawPoints =
        roadRoute?.points ?? <LatLng>[origin, destination];
    late List<LatLng> simplified;
    try {
      simplified = rawPoints.length > 2
          ? RouteUtils.simplifyRoute(
              rawPoints,
              tolerance: _routeSimplificationTolerance,
            )
          : rawPoints;
    } on Object {
      roadRoute = null;
      simplified = <LatLng>[origin, destination];
    }
    if (simplified.length < 2) {
      roadRoute = null;
      simplified = <LatLng>[origin, destination];
    }
    final bool approximate = roadRoute == null;
    setState(() {
      _roadRoute = roadRoute;
      _routePoints = List<LatLng>.unmodifiable(simplified);
      _usingApproximateRoute = approximate || approximateSelection;
      _statusMessage = approximate
          ? 'Sin trazado vial: se muestra una guía aproximada.'
          : approximateSelection
              ? 'Cliente cercano estimado; trazado vial disponible.'
              : selectedByDijkstra
                  ? 'Cobro más rápido seleccionado con Dijkstra.'
                  : 'Ruta vial al cliente seleccionado.';
    });

    if (fitRoute && _mapReady) {
      _fitPoints(
        _routePoints,
        padding: 78,
        maxZoom: 16,
      );
    }
  }

  void _focusCustomer(CollectionMapCustomer customer) {
    final LatLng? point = customer.point;
    if (!_mapReady || point == null) {
      return;
    }
    _animateCamera(
      point,
      zoom: 16.2,
      duration: _focusDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _fitAll() {
    final List<LatLng> points = <LatLng>[
      if (_currentPosition != null) _currentPosition!,
      ..._locatedCustomers.map(
        (CollectionMapCustomer customer) => customer.point!,
      ),
    ];
    if (points.isNotEmpty) {
      _fitPoints(points, padding: 62, maxZoom: 15.5);
    }
  }

  void _focusCluster(List<CollectionMapCustomer> customers) {
    if (!_mapReady || customers.isEmpty) {
      return;
    }
    final double latitude = customers.fold<double>(
          0,
          (double total, CollectionMapCustomer customer) =>
              total + customer.latitude!,
        ) /
        customers.length;
    final double longitude = customers.fold<double>(
          0,
          (double total, CollectionMapCustomer customer) =>
              total + customer.longitude!,
        ) /
        customers.length;
    _animateCamera(
      LatLng(latitude, longitude),
      zoom: math.min(_mapController.camera.zoom + 2.2, 17.2),
      duration: _fitDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _fitPoints(
    List<LatLng> points, {
    required double padding,
    required double maxZoom,
  }) {
    if (!_mapReady || points.isEmpty) {
      return;
    }
    double minLatitude = points.first.latitude;
    double maxLatitude = points.first.latitude;
    double minLongitude = points.first.longitude;
    double maxLongitude = points.first.longitude;
    for (final LatLng point in points.skip(1)) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
    }

    final LatLng center = LatLng(
      (minLatitude + maxLatitude) / 2,
      (minLongitude + maxLongitude) / 2,
    );
    final Size viewport = context.size ?? const Size(900, 600);
    final double usableWidth = math.max(80, viewport.width - (padding * 2));
    final double usableHeight = math.max(80, viewport.height - (padding * 2));
    final double longitudeSpan =
        math.max(0.000001, maxLongitude - minLongitude);
    final double latitudeSpan = math.max(0.000001, maxLatitude - minLatitude);
    final double longitudeZoom =
        math.log((usableWidth * 360) / (256 * longitudeSpan)) / math.ln2;
    final double latitudeZoom =
        math.log((usableHeight * 170) / (256 * latitudeSpan)) / math.ln2;
    final double zoom = math.min(longitudeZoom, latitudeZoom).clamp(
          3.0,
          maxZoom,
        );
    _animateCamera(
      center,
      zoom: zoom,
      duration: _fitDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _animateCamera(
    LatLng target, {
    required double zoom,
    required Duration duration,
    required Curve curve,
  }) {
    if (!_mapReady || !_mapController.isReady) {
      return;
    }
    _cancelCameraAnimation();

    final LatLng origin = _mapController.center;
    final double originZoom = _mapController.zoom;
    final AnimationController controller = AnimationController(
      vsync: this,
      duration: duration,
    );
    _cameraAnimation = controller;
    final Animation<double> progress = CurvedAnimation(
      parent: controller,
      curve: curve,
    );
    controller
      ..addListener(() {
        if (!mounted || !identical(_cameraAnimation, controller)) {
          return;
        }
        _mapController.jumpTo(
          LatLng(
            origin.latitude +
                ((target.latitude - origin.latitude) * progress.value),
            origin.longitude +
                ((target.longitude - origin.longitude) * progress.value),
          ),
          zoom: originZoom + ((zoom - originZoom) * progress.value),
        );
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed &&
            identical(_cameraAnimation, controller)) {
          _cameraAnimation = null;
          controller.dispose();
        }
      })
      ..forward();
  }

  void _cancelCameraAnimation() {
    final AnimationController? animation = _cameraAnimation;
    _cameraAnimation = null;
    animation?.dispose();
  }

  void _zoomBy(double delta) {
    if (!_mapReady) {
      return;
    }
    _animateCamera(
      _mapController.camera.center,
      zoom: (_mapController.camera.zoom + delta).clamp(3.0, 18.0),
      duration: _zoomDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final List<CollectionMapCustomer> customers = _locatedCustomers;
    final bool darkMode = Theme.of(context).brightness == Brightness.dark;
    final List<MapcnRoute> routes = _routePoints.length < 2
        ? const <MapcnRoute>[]
        : <MapcnRoute>[
            MapcnRoute(
              id: 'automatic-collection-route',
              points: _routePoints,
              config: RouteConfig(
                color: _usingApproximateRoute
                    ? CobroAppTheme.warning
                    : CobroAppTheme.primary,
                width: _usingApproximateRoute ? 3.5 : 5,
                style: _usingApproximateRoute
                    ? RouteStyle.dashed
                    : RouteStyle.solid,
                showArrows: !_usingApproximateRoute,
                arrowSpacing: 84,
                showEndpoints: !_usingApproximateRoute,
                startColor: CobroAppTheme.success,
                endColor: CobroAppTheme.danger,
                showGlow: !_usingApproximateRoute,
                glowIntensity: _usingApproximateRoute ? 0 : 0.32,
                borderColor: const Color(0xFF07111F),
                borderWidth: 1.8,
              ),
            ),
          ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: clay.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: clay.border),
        boxShadow: clay.raisedShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: Mapcn(
                controller: _mapController,
                initialCenter: _initialCenter,
                initialZoom: customers.length == 1 ? 15 : 13.2,
                style: darkMode ? MapcnStyle.dark : MapcnStyle.normal,
                tileUrlTemplate: CobroMapTiles.routeLightUrlTemplate,
                attributionText: CobroMapTiles.attribution,
                points: const <LatLng>[],
                routes: routes,
                accentColor: CobroAppTheme.primary,
                markerConfig: MarkerConfig.minimal,
                showTooltip: false,
                showAttribution: true,
                minZoom: 3,
                maxZoom: 18,
                useRepaintBoundary: true,
                enableTileCaching: true,
                maxTileCache: 180,
                onCameraMove: (_, bool hasGesture) {
                  if (hasGesture) {
                    _cancelCameraAnimation();
                  }
                  _cameraRevision.value++;
                },
                onMapReady: () {
                  if (!mounted) {
                    return;
                  }
                  setState(() => _mapReady = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _routePoints.length < 2 && !_calculating) {
                      _scheduleAutomaticRoute();
                    } else if (mounted && _routePoints.length >= 2) {
                      _fitPoints(_routePoints, padding: 72, maxZoom: 15.5);
                    }
                  });
                },
              ),
            ),
            _ProjectedMapOverlay(
              controller: _mapController,
              cameraChanges: _cameraRevision,
              mapReady: _mapReady,
              customers: customers,
              currentPosition: _currentPosition,
              selectedCustomer: widget.selectedCustomer,
              onCustomerSelected: _selectCustomerFromMap,
              onClusterSelected: _focusCluster,
              onSelectionCleared: _clearSelectionFromMap,
              onCollect: widget.onCollect,
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 76,
              child: Align(
                alignment: Alignment.topLeft,
                child: _MapSummaryPill(
                  locations: customers.length,
                  statusMessage: _statusMessage,
                  calculating: _calculating,
                  approximate: _usingApproximateRoute,
                  route: _roadRoute,
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: _MapControls(
                onZoomIn: () => _zoomBy(1),
                onZoomOut: () => _zoomBy(-1),
                onFit: _fitAll,
              ),
            ),
            if (customers.isEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: _NoLocationsCard(total: widget.customers.length),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  RoadRouter get _router => widget.roadRouter;
}

class _ProjectedMapOverlay extends StatefulWidget {
  const _ProjectedMapOverlay({
    required this.controller,
    required this.cameraChanges,
    required this.mapReady,
    required this.customers,
    required this.currentPosition,
    required this.selectedCustomer,
    required this.onCustomerSelected,
    required this.onClusterSelected,
    required this.onSelectionCleared,
    required this.onCollect,
  });

  final MapcnController controller;
  final ValueListenable<int> cameraChanges;
  final bool mapReady;
  final List<CollectionMapCustomer> customers;
  final LatLng? currentPosition;
  final CollectionMapCustomer? selectedCustomer;
  final ValueChanged<CollectionMapCustomer> onCustomerSelected;
  final ValueChanged<List<CollectionMapCustomer>> onClusterSelected;
  final VoidCallback onSelectionCleared;
  final ValueChanged<CollectionMapCustomer> onCollect;

  @override
  State<_ProjectedMapOverlay> createState() => _ProjectedMapOverlayState();
}

class _ProjectedMapOverlayState extends State<_ProjectedMapOverlay> {
  @override
  void initState() {
    super.initState();
    widget.cameraChanges.addListener(_refreshProjection);
  }

  @override
  void didUpdateWidget(_ProjectedMapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraChanges != widget.cameraChanges) {
      oldWidget.cameraChanges.removeListener(_refreshProjection);
      widget.cameraChanges.addListener(_refreshProjection);
    }
  }

  void _refreshProjection() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.cameraChanges.removeListener(_refreshProjection);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.mapReady || !widget.controller.isReady) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final List<Widget> overlays = <Widget>[];
        final double zoom = widget.controller.camera.zoom;
        final double clusterCellSize = zoom >= 16.2
            ? 28
            : zoom >= 14.5
                ? 38
                : 48;
        final Map<String, List<CollectionMapCustomer>> groupedCustomers =
            <String, List<CollectionMapCustomer>>{};
        final Map<String, List<Offset>> groupedOffsets =
            <String, List<Offset>>{};

        for (final CollectionMapCustomer customer in widget.customers) {
          final LatLng? point = customer.point;
          if (point == null) {
            continue;
          }
          final Offset offset =
              widget.controller.camera.latLngToScreenOffset(point);
          if (!_inside(offset, constraints, margin: 36)) {
            continue;
          }
          final String cell =
              '${(offset.dx / clusterCellSize).floor()}:${(offset.dy / clusterCellSize).floor()}';
          final List<CollectionMapCustomer> customerGroup =
              groupedCustomers.putIfAbsent(
            cell,
            () => <CollectionMapCustomer>[],
          );
          customerGroup.add(customer);
          final List<Offset> offsetGroup =
              groupedOffsets.putIfAbsent(cell, () => <Offset>[]);
          offsetGroup.add(offset);
        }

        for (final MapEntry<String, List<CollectionMapCustomer>> entry
            in groupedCustomers.entries) {
          final List<Offset> offsets = groupedOffsets[entry.key]!;
          final Offset center = Offset(
            offsets.fold<double>(
                  0,
                  (double sum, Offset item) => sum + item.dx,
                ) /
                offsets.length,
            offsets.fold<double>(
                  0,
                  (double sum, Offset item) => sum + item.dy,
                ) /
                offsets.length,
          );
          final List<CollectionMapCustomer> customers = entry.value;
          if (customers.length == 1) {
            final CollectionMapCustomer customer = customers.single;
            overlays.add(
              Positioned(
                left: center.dx - 15,
                top: center.dy - 15,
                child: _CustomerPointMarker(
                  customer: customer,
                  selected: customer.id == widget.selectedCustomer?.id,
                  onTap: () => widget.onCustomerSelected(customer),
                ),
              ),
            );
          } else {
            overlays.add(
              Positioned(
                left: center.dx - 19,
                top: center.dy - 19,
                child: _CustomerClusterMarker(
                  count: customers.length,
                  onTap: () => widget.onClusterSelected(customers),
                ),
              ),
            );
          }
        }

        final LatLng? current = widget.currentPosition;
        if (current != null) {
          final Offset offset =
              widget.controller.camera.latLngToScreenOffset(current);
          if (_inside(offset, constraints, margin: 28)) {
            overlays.add(
              Positioned(
                left: offset.dx - 14,
                top: offset.dy - 14,
                child: const IgnorePointer(child: _CurrentPositionMarker()),
              ),
            );
          }
        }

        final CollectionMapCustomer? selected = widget.selectedCustomer;
        final LatLng? selectedPoint = selected?.point;
        if (selected != null && selectedPoint != null) {
          final Offset offset =
              widget.controller.camera.latLngToScreenOffset(selectedPoint);
          if (_inside(offset, constraints, margin: 80) &&
              constraints.maxWidth >= 260 &&
              constraints.maxHeight >= 280) {
            const double preferredWidth = 350;
            final double width = math.min(
              preferredWidth,
              math.max(236, constraints.maxWidth - 24),
            );
            final double maxLeft = math.max(
              12,
              constraints.maxWidth - width - 12,
            );
            final double left = (offset.dx - (width / 2)).clamp(
              12.0,
              maxLeft,
            );
            final bool placeAbove = offset.dy > 266;
            final double maxTop = math.max(
              12,
              constraints.maxHeight - 250,
            );
            final double top = placeAbove
                ? (offset.dy - 250).clamp(12, maxTop)
                : (offset.dy + 24).clamp(12, maxTop);
            overlays.add(
              Positioned(
                left: left,
                top: top,
                width: width,
                child: _CustomerMapTooltip(
                  customer: selected,
                  onClose: widget.onSelectionCleared,
                  onCollect: selected.canCollect
                      ? () => widget.onCollect(selected)
                      : null,
                ),
              ),
            );
          }
        }

        return Stack(children: overlays);
      },
    );
  }

  static bool _inside(
    Offset offset,
    BoxConstraints constraints, {
    required double margin,
  }) {
    return offset.dx >= -margin &&
        offset.dy >= -margin &&
        offset.dx <= constraints.maxWidth + margin &&
        offset.dy <= constraints.maxHeight + margin;
  }
}

class _CustomerPointMarker extends StatelessWidget {
  const _CustomerPointMarker({
    required this.customer,
    required this.selected,
    required this.onTap,
  });

  final CollectionMapCustomer customer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ver cobro de ${customer.name}',
      child: Tooltip(
        message: customer.name,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('map-point-${customer.id}'),
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? CobroAppTheme.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : customer.statusColor.withValues(alpha: 0.9),
                  width: selected ? 3 : 2.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: selected ? 13 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 8 : 9,
                  height: selected ? 8 : 9,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : customer.statusColor,
                    shape: BoxShape.circle,
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

class _CustomerClusterMarker extends StatelessWidget {
  const _CustomerClusterMarker({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Acercar grupo de $count clientes',
      child: Tooltip(
        message: '$count clientes en esta zona',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentPositionMarker extends StatelessWidget {
  const _CurrentPositionMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: CobroAppTheme.primary.withValues(alpha: 0.32),
          width: 5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CobroAppTheme.primary.withValues(alpha: 0.34),
            blurRadius: 14,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const SizedBox.square(
        dimension: 28,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CobroAppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: 10),
          ),
        ),
      ),
    );
  }
}

class _CustomerMapTooltip extends StatelessWidget {
  const _CustomerMapTooltip({
    required this.customer,
    required this.onClose,
    required this.onCollect,
  });

  final CollectionMapCustomer customer;
  final VoidCallback onClose;
  final VoidCallback? onCollect;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(20);
    const Color glassBase = Color(0xFF0F172A);
    const Color glassBaseHigh = Color(0xFF243141);
    const Color tooltipText = Color(0xFFF8FAFC);
    const Color tooltipSubtle = Color(0xFFB8C3D1);

    return Material(
      key: ValueKey<String>('map-tooltip-${customer.id}'),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: glassBase.withValues(alpha: 0.74),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0x5A3A4656),
                  Color(0xD1172435),
                  Color(0xE60F172A),
                ],
              ),
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.06),
                  blurRadius: 10,
                  spreadRadius: -3,
                  offset: const Offset(-4, -5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                              customer.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: tooltipText,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            if ((customer.business ?? '').isNotEmpty)
                              ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  customer.business!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: tooltipSubtle),
                                ),
                              ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: customer.statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Text(
                            customer.statusLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: customer.statusColor,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      IconButton(
                        tooltip: 'Cerrar detalle',
                        onPressed: onClose,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 19),
                        style: IconButton.styleFrom(
                          backgroundColor: glassBaseHigh.withValues(alpha: 0.5),
                          foregroundColor: tooltipText,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.location_on_rounded,
                        size: 17,
                        color: tooltipSubtle,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          (customer.address ?? '').isEmpty
                              ? customer.routeName
                              : '${customer.address} Â· ${customer.routeName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: tooltipSubtle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _TooltipMetric(
                          label: 'Cobrar ahora',
                          value: customer.amountLabel,
                          labelColor: tooltipSubtle,
                          valueColor: tooltipText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TooltipMetric(
                          label: 'Saldo',
                          value: customer.balanceLabel,
                          labelColor: tooltipSubtle,
                          valueColor: tooltipText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'PrÃ³xima: ${customer.dueDateLabel}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: tooltipSubtle,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: onCollect,
                        icon: const Icon(Icons.payments_rounded, size: 18),
                        label: Text(onCollect == null ? 'Pagado' : 'Cobrar'),
                      ),
                    ],
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

class _TooltipMetric extends StatelessWidget {
  const _TooltipMetric({
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor ?? context.clay.subtleText,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _MemoizedRouteLocationService implements RouteLocationService {
  _MemoizedRouteLocationService(this._delegate);

  final RouteLocationService _delegate;
  Future<LatLng>? _pending;
  LatLng? _lastPosition;

  @override
  Future<LatLng> currentPosition() {
    final LatLng? lastPosition = _lastPosition;
    if (lastPosition != null) {
      return Future<LatLng>.value(lastPosition);
    }

    final Future<LatLng>? pending = _pending;
    if (pending != null) {
      return pending;
    }

    final Future<LatLng> request = _delegate.currentPosition().then((value) {
      _lastPosition = value;
      _pending = null;
      return value;
    }).catchError((Object error) {
      _pending = null;
      throw error;
    });
    _pending = request;
    return request;
  }
}

class _MapSummaryPill extends StatelessWidget {
  const _MapSummaryPill({
    required this.locations,
    required this.statusMessage,
    required this.calculating,
    required this.approximate,
    required this.route,
  });

  final int locations;
  final String? statusMessage;
  final bool calculating;
  final bool approximate;
  final RoadRoute? route;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    final String routeSummary = route == null
        ? '$locations puntos en el mapa'
        : '${_formatDistance(route!.distanceMeters)} · ${_formatDuration(route!.duration)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: clay.surfaceHigh.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: clay.border),
        boxShadow: clay.raisedShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (calculating)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                approximate ? Icons.info_outline_rounded : Icons.route_rounded,
                size: 17,
                color:
                    approximate ? CobroAppTheme.warning : CobroAppTheme.primary,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                statusMessage ?? routeSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: clay.text,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  static String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours} h ${duration.inMinutes % 60} min';
    }
    return '${duration.inMinutes.clamp(1, 999)} min';
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _MapControlButton(
          tooltip: 'Acercar',
          icon: Icons.add_rounded,
          onPressed: onZoomIn,
        ),
        const SizedBox(height: 7),
        _MapControlButton(
          tooltip: 'Alejar',
          icon: Icons.remove_rounded,
          onPressed: onZoomOut,
        ),
        const SizedBox(height: 7),
        _MapControlButton(
          tooltip: 'Ver todos',
          icon: Icons.fit_screen_rounded,
          onPressed: onFit,
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _NoLocationsCard extends StatelessWidget {
  const _NoLocationsCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final ClayTokens clay = context.clay;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: clay.surfaceHigh.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: clay.border),
          boxShadow: clay.raisedShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.location_off_rounded,
                color: CobroAppTheme.warning,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                total == 0
                    ? 'Sin cobros para ubicar'
                    : 'Ubicaciones pendientes',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                total == 0
                    ? 'Los clientes aparecerán aquí cuando haya cobros activos.'
                    : 'Agrega latitud y longitud a la dirección principal de cada cliente.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: clay.subtleText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _SafeListAccess<T> on List<T> {
  T? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}
