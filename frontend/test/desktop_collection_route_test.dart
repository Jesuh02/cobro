import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapcn_flutter/mapcn_flutter.dart';

import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/core/map/map_tiles.dart';
import 'package:cobro_app/features/routes/data/device_location_service.dart';
import 'package:cobro_app/features/routes/data/osrm_road_router.dart';
import 'package:cobro_app/features/routes/presentation/desktop_collection_route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seleccionar una tarjeta enfoca y muestra su tooltip sin imagen',
      (WidgetTester tester) async {
    _setDesktopViewport(tester);

    await tester.pumpWidget(
      _testApp(
        customers: _customers,
        roadRouter: _FakeRoadRouter(),
        locationService: const _FakeLocationService(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Mapcn), findsOneWidget);
    final Mapcn map = tester.widget<Mapcn>(find.byType(Mapcn));
    expect(map.style, MapcnStyle.normal);
    expect(map.tileUrlTemplate, CobroMapTiles.routeLightUrlTemplate);
    expect(map.attributionText, CobroMapTiles.attribution);
    expect(find.byKey(const ValueKey<String>('map-tooltip-a')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('route-card-a')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byKey(const ValueKey<String>('map-tooltip-a')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('map-tooltip-a')),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    final Text tooltipName = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('map-tooltip-a')),
        matching: find.text('Cliente cercano lento'),
      ),
    );
    expect(tooltipName.style?.color, const Color(0xFFF8FAFC));
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('route-card-a')));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('map-tooltip-a')), findsNothing);
  });

  testWidgets('el mapa conserva el estilo oscuro en modo oscuro',
      (WidgetTester tester) async {
    _setDesktopViewport(tester);

    await tester.pumpWidget(
      _testApp(
        customers: _customers,
        theme: CobroAppTheme.dark(),
        roadRouter: _FakeRoadRouter(),
        locationService: const _FakeLocationService(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.widget<Mapcn>(find.byType(Mapcn)).style, MapcnStyle.dark);
  });

  testWidgets('traza automáticamente una sola ruta por todos los cobros',
      (WidgetTester tester) async {
    _setDesktopViewport(tester);
    final _FakeRoadRouter router = _FakeRoadRouter();

    await tester.pumpWidget(
      _testApp(
        customers: _customers,
        roadRouter: router,
        locationService: const _FakeLocationService(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(
      find.byKey(const ValueKey<String>('calculate-fastest-route')),
      findsNothing,
    );
    final List<String> texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((Text widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    expect(texts, contains('Ruta automática por 2 paradas.'));
    expect(router.routedStops, hasLength(1));
    expect(
      router.routedStops.single,
      _customers.map((customer) => customer.point).toList(),
    );
    expect(tester.widget<Mapcn>(find.byType(Mapcn)).routes, hasLength(1));
    final Mapcn map = tester.widget<Mapcn>(find.byType(Mapcn));
    expect(map.routes, hasLength(1));
    expect(map.routes.single.id, 'automatic-collection-route');
  });

  testWidgets('ordena cada parada desde el punto visitado mas cercano',
      (WidgetTester tester) async {
    _setDesktopViewport(tester);
    final _FakeRoadRouter router = _FakeRoadRouter();

    await tester.pumpWidget(
      _testApp(
        customers: _unorderedCustomers,
        roadRouter: router,
        locationService: const _FakeLocationService(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(router.routedStops, hasLength(1));
    expect(
      router.routedStops.single,
      <LatLng>[
        _unorderedCustomers[2].point!,
        _unorderedCustomers[1].point!,
        _unorderedCustomers[0].point!,
      ],
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey<String>('route-card-near')))
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('route-card-middle')),
            )
            .dy,
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('route-card-middle')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey<String>('route-card-far')))
            .dy,
      ),
    );
  });

  testWidgets(
      'usa una sola linea por todas las paradas si el proveedor omite una',
      (WidgetTester tester) async {
    _setDesktopViewport(tester);
    final _SkippingRoadRouter router = _SkippingRoadRouter();

    await tester.pumpWidget(
      _testApp(
        customers: _zigzagCustomers,
        roadRouter: router,
        locationService: const _FakeLocationService(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    final Mapcn map = tester.widget<Mapcn>(find.byType(Mapcn));
    expect(map.routes, hasLength(1));
    expect(
      map.routes.single.points,
      <LatLng>[
        const LatLng(11.54, -72.90),
        ...router.routedStops.single,
      ],
    );
  });

  testWidgets('calcula ruta para cobros activos aunque no esten vencidos',
      (WidgetTester tester) async {
    _setDesktopViewport(tester);
    final _FakeRoadRouter router = _FakeRoadRouter();

    await tester.pumpWidget(
      _testApp(
        customers: _futureCustomers,
        roadRouter: router,
        locationService: const _FakeLocationService(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(router.routedStops, hasLength(1));
    expect(router.routedStops.single, hasLength(2));
  });

  testWidgets('seleccionar un cliente no cancela la ruta automática',
      (WidgetTester tester) async {
    _setDesktopViewport(tester);
    final _DelayedRoadRouter router = _DelayedRoadRouter();

    await tester.pumpWidget(
      _testApp(
        customers: _customers,
        roadRouter: router,
        locationService: const _FakeLocationService(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routeThroughStarted, isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('route-card-a')));
    await tester.pump();
    router.completeRoute();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byKey(const ValueKey<String>('map-tooltip-a')), findsOneWidget);
    expect(tester.widget<Mapcn>(find.byType(Mapcn)).routes, hasLength(1));
    expect(
      find.byKey(const ValueKey<String>('calculate-fastest-route')),
      findsNothing,
    );
  });

  testWidgets('incluye todos los clientes en una ruta de muchas paradas',
      (WidgetTester tester) async {
    _setDesktopViewport(tester);
    final List<CollectionMapCustomer> customers =
        List<CollectionMapCustomer>.generate(25, _customerAt);
    final _BatchRoadRouter router = _BatchRoadRouter();

    await tester.pumpWidget(
      _testApp(
        customers: customers,
        roadRouter: router,
        locationService: const _FakeLocationService(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(router.routedStops, hasLength(25));
    expect(router.routedStops.last, customers.last.point);
  });
}

void _setDesktopViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _testApp({
  required List<CollectionMapCustomer> customers,
  required RoadRouter roadRouter,
  required RouteLocationService locationService,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? CobroAppTheme.light(),
    home: Scaffold(
      body: DesktopCollectionRoute(
        header: const Text('Ruta activa'),
        filters: const SizedBox(height: 40),
        summary: const Text('2 pendientes'),
        customers: customers,
        roadRouter: roadRouter,
        locationService: locationService,
        onRefresh: () async {},
        onCollect: (_) {},
        cardBuilder: (
          BuildContext context,
          CollectionMapCustomer customer,
          bool selected,
          VoidCallback onSelected,
        ) {
          return Material(
            color: selected ? Colors.blue.shade50 : Colors.transparent,
            child: InkWell(
              key: ValueKey<String>('route-card-${customer.id}'),
              onTap: onSelected,
              child: SizedBox(
                height: 84,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(customer.name),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

const List<CollectionMapCustomer> _customers = <CollectionMapCustomer>[
  CollectionMapCustomer(
    id: 'a',
    customerId: 'customer-a',
    creditId: 'credit-a',
    name: 'Cliente cercano lento',
    routeName: 'Centro',
    amountLabel: r'$ 50.000',
    installmentLabel: r'$ 50.000',
    balanceLabel: r'$ 500.000',
    dueDateLabel: '22 ago',
    statusLabel: 'Debe hoy',
    statusColor: Colors.orange,
    canCollect: true,
    canRoute: true,
    isDueNow: true,
    address: 'Calle 1 # 2-3',
    latitude: 11.541,
    longitude: -72.901,
  ),
  CollectionMapCustomer(
    id: 'b',
    customerId: 'customer-b',
    creditId: 'credit-b',
    name: 'Cliente rápido por vía',
    routeName: 'Centro',
    amountLabel: r'$ 80.000',
    installmentLabel: r'$ 80.000',
    balanceLabel: r'$ 800.000',
    dueDateLabel: '22 ago',
    statusLabel: 'Debe hoy',
    statusColor: Colors.orange,
    canCollect: true,
    canRoute: true,
    isDueNow: true,
    address: 'Carrera 7 # 8-9',
    latitude: 11.55,
    longitude: -72.91,
  ),
];

const List<CollectionMapCustomer> _futureCustomers = <CollectionMapCustomer>[
  CollectionMapCustomer(
    id: 'future-a',
    customerId: 'future-customer-a',
    creditId: 'future-credit-a',
    name: 'Cliente al dia lento',
    routeName: 'Centro',
    amountLabel: r'$ 50.000',
    installmentLabel: r'$ 50.000',
    balanceLabel: r'$ 500.000',
    dueDateLabel: '25 ago',
    statusLabel: 'Al dia',
    statusColor: Colors.green,
    canCollect: true,
    canRoute: true,
    isDueNow: false,
    address: 'Calle 10 # 2-3',
    latitude: 11.541,
    longitude: -72.901,
  ),
  CollectionMapCustomer(
    id: 'future-b',
    customerId: 'future-customer-b',
    creditId: 'future-credit-b',
    name: 'Cliente al dia rapido',
    routeName: 'Centro',
    amountLabel: r'$ 80.000',
    installmentLabel: r'$ 80.000',
    balanceLabel: r'$ 800.000',
    dueDateLabel: '25 ago',
    statusLabel: 'Al dia',
    statusColor: Colors.green,
    canCollect: true,
    canRoute: true,
    isDueNow: false,
    address: 'Carrera 17 # 8-9',
    latitude: 11.55,
    longitude: -72.91,
  ),
];

const List<CollectionMapCustomer> _unorderedCustomers =
    <CollectionMapCustomer>[
  CollectionMapCustomer(
    id: 'far',
    customerId: 'customer-far',
    creditId: 'credit-far',
    name: 'Cliente lejano',
    routeName: 'Centro',
    amountLabel: r'$ 50.000',
    installmentLabel: r'$ 50.000',
    balanceLabel: r'$ 500.000',
    dueDateLabel: '22 ago',
    statusLabel: 'Debe hoy',
    statusColor: Colors.orange,
    canCollect: true,
    canRoute: true,
    isDueNow: true,
    address: 'Centro',
    latitude: 11.541,
    longitude: -72.90,
  ),
  CollectionMapCustomer(
    id: 'middle',
    customerId: 'customer-middle',
    creditId: 'credit-middle',
    name: 'Cliente intermedio',
    routeName: 'Centro',
    amountLabel: r'$ 50.000',
    installmentLabel: r'$ 50.000',
    balanceLabel: r'$ 500.000',
    dueDateLabel: '22 ago',
    statusLabel: 'Debe hoy',
    statusColor: Colors.orange,
    canCollect: true,
    canRoute: true,
    isDueNow: true,
    address: 'Centro',
    latitude: 11.5402,
    longitude: -72.90,
  ),
  CollectionMapCustomer(
    id: 'near',
    customerId: 'customer-near',
    creditId: 'credit-near',
    name: 'Cliente cercano',
    routeName: 'Centro',
    amountLabel: r'$ 50.000',
    installmentLabel: r'$ 50.000',
    balanceLabel: r'$ 500.000',
    dueDateLabel: '22 ago',
    statusLabel: 'Debe hoy',
    statusColor: Colors.orange,
    canCollect: true,
    canRoute: true,
    isDueNow: true,
    address: 'Centro',
    latitude: 11.5401,
    longitude: -72.90,
  ),
];

const List<CollectionMapCustomer> _zigzagCustomers = <CollectionMapCustomer>[
  CollectionMapCustomer(
    id: 'south-west',
    customerId: 'customer-south-west',
    creditId: 'credit-south-west',
    name: 'Cliente suroeste',
    routeName: 'Centro',
    amountLabel: r'$ 50.000',
    installmentLabel: r'$ 50.000',
    balanceLabel: r'$ 500.000',
    dueDateLabel: '22 ago',
    statusLabel: 'Debe hoy',
    statusColor: Colors.orange,
    canCollect: true,
    canRoute: true,
    isDueNow: true,
    address: 'Centro',
    latitude: 11.5404,
    longitude: -72.9002,
  ),
  CollectionMapCustomer(
    id: 'east',
    customerId: 'customer-east',
    creditId: 'credit-east',
    name: 'Cliente este',
    routeName: 'Centro',
    amountLabel: r'$ 50.000',
    installmentLabel: r'$ 50.000',
    balanceLabel: r'$ 500.000',
    dueDateLabel: '22 ago',
    statusLabel: 'Debe hoy',
    statusColor: Colors.orange,
    canCollect: true,
    canRoute: true,
    isDueNow: true,
    address: 'Centro',
    latitude: 11.5407,
    longitude: -72.8978,
  ),
  CollectionMapCustomer(
    id: 'north',
    customerId: 'customer-north',
    creditId: 'credit-north',
    name: 'Cliente norte',
    routeName: 'Centro',
    amountLabel: r'$ 50.000',
    installmentLabel: r'$ 50.000',
    balanceLabel: r'$ 500.000',
    dueDateLabel: '22 ago',
    statusLabel: 'Debe hoy',
    statusColor: Colors.orange,
    canCollect: true,
    canRoute: true,
    isDueNow: true,
    address: 'Centro',
    latitude: 11.544,
    longitude: -72.9002,
  ),
];

CollectionMapCustomer _customerAt(int index) {
  return CollectionMapCustomer(
    id: 'customer-$index',
    customerId: 'person-$index',
    creditId: 'credit-$index',
    name: 'Cliente ${index + 1}',
    routeName: 'Centro',
    amountLabel: r'$ 50.000',
    installmentLabel: r'$ 50.000',
    balanceLabel: r'$ 500.000',
    dueDateLabel: '22 ago',
    statusLabel: 'Debe hoy',
    statusColor: Colors.orange,
    canCollect: true,
    canRoute: true,
    isDueNow: true,
    address: 'Centro',
    latitude: 11.54 + (index * 0.0001),
    longitude: -72.9,
  );
}

class _FakeLocationService implements RouteLocationService {
  const _FakeLocationService();

  @override
  Future<LatLng> currentPosition() async => const LatLng(11.54, -72.90);
}

class _FakeRoadRouter implements RoadRouter {
  final List<LatLng> routedDestinations = <LatLng>[];
  final List<List<LatLng>> routedStops = <List<LatLng>>[];

  @override
  Future<List<RoadTravelEstimate?>> estimateTrips({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    return destinations
        .map(
          (LatLng destination) => RoadTravelEstimate(
            duration: destination.latitude > 11.545
                ? const Duration(seconds: 90)
                : const Duration(minutes: 10),
            distanceMeters: const Distance().as(
              LengthUnit.Meter,
              origin,
              destination,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<RoadRoute?> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    routedDestinations.add(destination);
    return RoadRoute(
      points: <LatLng>[origin, destination],
      duration: const Duration(seconds: 90),
      distanceMeters: const Distance().as(
        LengthUnit.Meter,
        origin,
        destination,
      ),
    );
  }

  @override
  Future<RoadRoute?> routeThrough({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    routedStops.add(List<LatLng>.of(destinations));
    return RoadRoute(
      points: <LatLng>[origin, ...destinations],
      duration: const Duration(minutes: 5),
      distanceMeters: 5000,
    );
  }

  @override
  void close() {}
}

class _DelayedRoadRouter implements RoadRouter {
  final Completer<RoadRoute?> _route = Completer<RoadRoute?>();
  bool routeThroughStarted = false;

  void completeRoute() {
    _route.complete(
      RoadRoute(
        points: <LatLng>[
          const LatLng(11.54, -72.90),
          ..._customers.map((customer) => customer.point!),
        ],
        duration: const Duration(minutes: 4),
        distanceMeters: 4000,
      ),
    );
  }

  @override
  Future<List<RoadTravelEstimate?>> estimateTrips({
    required LatLng origin,
    required List<LatLng> destinations,
  }) {
    return Future<List<RoadTravelEstimate?>>.value(
      List<RoadTravelEstimate?>.filled(destinations.length, null),
    );
  }

  @override
  Future<RoadRoute?> routeThrough({
    required LatLng origin,
    required List<LatLng> destinations,
  }) {
    routeThroughStarted = true;
    return _route.future;
  }

  @override
  Future<RoadRoute?> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return RoadRoute(
      points: <LatLng>[origin, destination],
      duration: const Duration(minutes: 1),
      distanceMeters: 100,
    );
  }

  @override
  void close() {}
}

class _SkippingRoadRouter extends _FakeRoadRouter {
  @override
  Future<RoadRoute?> routeThrough({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    routedStops.add(List<LatLng>.of(destinations));
    return RoadRoute(
      points: <LatLng>[origin, destinations.last],
      duration: const Duration(minutes: 5),
      distanceMeters: 5000,
    );
  }
}

class _BatchRoadRouter implements RoadRouter {
  final List<LatLng> routedStops = <LatLng>[];

  @override
  Future<List<RoadTravelEstimate?>?> estimateTrips({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    return destinations
        .map(
          (LatLng destination) => RoadTravelEstimate(
            duration: const Duration(minutes: 5),
            distanceMeters: const Distance().as(
              LengthUnit.Meter,
              origin,
              destination,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<RoadRoute?> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return RoadRoute(
      points: <LatLng>[origin, destination],
      duration: const Duration(seconds: 15),
      distanceMeters: const Distance().as(
        LengthUnit.Meter,
        origin,
        destination,
      ),
    );
  }

  @override
  Future<RoadRoute?> routeThrough({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    routedStops
      ..clear()
      ..addAll(destinations);
    return RoadRoute(
      points: <LatLng>[origin, ...destinations],
      duration: const Duration(minutes: 20),
      distanceMeters: 12000,
    );
  }

  @override
  void close() {}
}
