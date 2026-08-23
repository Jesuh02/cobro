import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/features/routes/data/api_road_router.dart';

void main() {
  test('interpreta estimaciones y geometría del proxy autenticado', () async {
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      client: MockClient((http.Request request) async {
        if (request.url.path.endsWith('/routing/estimates')) {
          return _jsonResponse(<String, dynamic>{
            'providerAvailable': true,
            'estimates': <dynamic>[
              <String, dynamic>{
                'durationMs': 90500,
                'distanceMeters': 1250.5,
              },
              null,
            ],
          });
        }
        return _jsonResponse(<String, dynamic>{
          'route': <String, dynamic>{
            'points': <List<double>>[
              <double>[11.54, -72.9],
              <double>[11.55, -72.91],
            ],
            'durationMs': 120000,
            'distanceMeters': 2100,
          },
        });
      }),
    );
    addTearDown(client.close);
    final ApiRoadRouter router = ApiRoadRouter(client);

    final estimates = await router.estimateTrips(
      origin: const LatLng(11.53, -72.89),
      destinations: const <LatLng>[
        LatLng(11.54, -72.9),
        LatLng(11.55, -72.91),
      ],
    );
    final route = await router.route(
      origin: const LatLng(11.54, -72.9),
      destination: const LatLng(11.55, -72.91),
    );
    final routeThrough = await router.routeThrough(
      origin: const LatLng(11.54, -72.9),
      destinations: const <LatLng>[
        LatLng(11.55, -72.91),
        LatLng(11.56, -72.92),
      ],
    );

    expect(estimates, hasLength(2));
    final parsedEstimates = estimates!;
    expect(
      parsedEstimates.first?.duration,
      const Duration(milliseconds: 90500),
    );
    expect(parsedEstimates.first?.distanceMeters, 1250.5);
    expect(parsedEstimates.last, isNull);
    expect(route?.points, const <LatLng>[
      LatLng(11.54, -72.9),
      LatLng(11.55, -72.91),
    ]);
    expect(route?.duration, const Duration(minutes: 2));
    expect(routeThrough?.points, hasLength(2));
  });

  test('degrada sin excepciones cuando el backend no responde', () async {
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      client: MockClient(
        (_) async => _jsonResponse(
          <String, dynamic>{'message': 'offline'},
          statusCode: 503,
        ),
      ),
    );
    addTearDown(client.close);
    final ApiRoadRouter router = ApiRoadRouter(client);

    final estimates = await router.estimateTrips(
      origin: const LatLng(11.53, -72.89),
      destinations: const <LatLng>[
        LatLng(11.54, -72.9),
        LatLng(11.55, -72.91),
      ],
    );
    final route = await router.route(
      origin: const LatLng(11.54, -72.9),
      destination: const LatLng(11.55, -72.91),
    );
    final routeThrough = await router.routeThrough(
      origin: const LatLng(11.54, -72.9),
      destinations: const <LatLng>[LatLng(11.55, -72.91)],
    );

    expect(estimates, isNull);
    expect(route, isNull);
    expect(routeThrough, isNull);
  });

  test('distingue una caída global de destinos individuales sin ruta',
      () async {
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      client: MockClient(
        (_) async => _jsonResponse(<String, dynamic>{
          'providerAvailable': false,
          'estimates': <dynamic>[null],
        }),
      ),
    );
    addTearDown(client.close);

    final estimates = await ApiRoadRouter(client).estimateTrips(
      origin: const LatLng(11.53, -72.89),
      destinations: const <LatLng>[LatLng(11.54, -72.9)],
    );

    expect(estimates, isNull);
  });
}

http.Response _jsonResponse(
  Object body, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
