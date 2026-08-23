import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoadTravelEstimate {
  const RoadTravelEstimate({
    required this.duration,
    required this.distanceMeters,
  });

  final Duration duration;
  final double distanceMeters;
}

class RoadRoute {
  RoadRoute({
    required Iterable<LatLng> points,
    required this.duration,
    required this.distanceMeters,
  }) : points = List<LatLng>.unmodifiable(points);

  final List<LatLng> points;
  final Duration duration;
  final double distanceMeters;
}

abstract interface class RoadRouter {
  /// Returns `null` when the provider is unavailable. Null entries inside a
  /// successful batch mean that the individual destination is unreachable.
  Future<List<RoadTravelEstimate?>?> estimateTrips({
    required LatLng origin,
    required List<LatLng> destinations,
  });

  Future<RoadRoute?> route({
    required LatLng origin,
    required LatLng destination,
  });

  /// Builds one continuous road route that starts at [origin] and visits
  /// every destination in the supplied order.
  Future<RoadRoute?> routeThrough({
    required LatLng origin,
    required List<LatLng> destinations,
  });

  void close();
}

/// Thin OSRM adapter. The endpoint is configurable at build time so production
/// can use a dedicated OSRM/Valhalla-compatible deployment instead of the
/// public demo service.
class OsrmRoadRouter implements RoadRouter {
  OsrmRoadRouter({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'OSRM_BASE_URL',
                  defaultValue: 'https://router.project-osrm.org',
                ))
            .replaceFirst(RegExp(r'/+$'), '');

  static const Duration _timeout = Duration(seconds: 9);
  static const int _maxCachedRoutes = 96;

  final http.Client _client;
  final bool _ownsClient;
  final String _baseUrl;
  final Map<String, RoadRoute> _routeCache = <String, RoadRoute>{};
  final Map<String, List<RoadTravelEstimate?>> _estimateCache =
      <String, List<RoadTravelEstimate?>>{};

  @override
  Future<List<RoadTravelEstimate?>?> estimateTrips({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    if (destinations.isEmpty) {
      return const <RoadTravelEstimate?>[];
    }
    final String cacheKey =
        '${_coordinate(origin)}>${_coordinates(destinations)}';
    final List<RoadTravelEstimate?>? cached = _estimateCache.remove(cacheKey);
    if (cached != null) {
      _estimateCache[cacheKey] = cached;
      return List<RoadTravelEstimate?>.of(cached, growable: false);
    }

    final List<LatLng> coordinates = <LatLng>[origin, ...destinations];
    final String destinationIndexes = List<String>.generate(
      destinations.length,
      (int index) => '${index + 1}',
      growable: false,
    ).join(';');
    final Uri uri = Uri.parse(
      '$_baseUrl/table/v1/driving/${_coordinates(coordinates)}',
    ).replace(
      queryParameters: <String, String>{
        'sources': '0',
        'destinations': destinationIndexes,
        'annotations': 'duration,distance',
      },
    );

    try {
      final http.Response response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') {
        return null;
      }

      final List<dynamic> durations = _firstMatrixRow(json['durations']);
      final List<dynamic> distances = _firstMatrixRow(json['distances']);
      final List<RoadTravelEstimate?> result =
          List<RoadTravelEstimate?>.generate(
        destinations.length,
        (int i) {
          final double? seconds =
              _nonNegativeFiniteDouble(durations.elementAtOrNull(i));
          final double? meters =
              _nonNegativeFiniteDouble(distances.elementAtOrNull(i));
          if (seconds == null || meters == null) {
            return null;
          }
          return RoadTravelEstimate(
            duration: Duration(milliseconds: (seconds * 1000).round()),
            distanceMeters: meters,
          );
        },
        growable: false,
      );
      _estimateCache[cacheKey] = List<RoadTravelEstimate?>.of(
        result,
        growable: false,
      );
      _trimCache(_estimateCache);
      return result;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RoadRoute?> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final String cacheKey =
        '${_coordinate(origin)}>${_coordinate(destination)}';
    final RoadRoute? cached = _routeCache.remove(cacheKey);
    if (cached != null) {
      _routeCache[cacheKey] = cached;
      return cached;
    }

    final Uri uri = Uri.parse(
      '$_baseUrl/route/v1/driving/${_coordinates(<LatLng>[
            origin,
            destination,
          ])}',
    ).replace(
      queryParameters: const <String, String>{
        'overview': 'simplified',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    try {
      final http.Response response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> routes = json['routes'] as List<dynamic>? ?? const [];
      if (json['code'] != 'Ok' || routes.isEmpty) {
        return null;
      }

      final Map<String, dynamic> route = routes.first as Map<String, dynamic>;
      final Map<String, dynamic> geometry =
          route['geometry'] as Map<String, dynamic>? ?? const {};
      final List<dynamic> rawCoordinates =
          geometry['coordinates'] as List<dynamic>? ?? const [];
      final List<LatLng> points = rawCoordinates
          .whereType<List<dynamic>>()
          .map(_pointFromGeoJson)
          .whereType<LatLng>()
          .toList(growable: false);
      final double? durationSeconds =
          _nonNegativeFiniteDouble(route['duration']);
      final double? distanceMeters =
          _nonNegativeFiniteDouble(route['distance']);
      if (points.length < 2 ||
          durationSeconds == null ||
          distanceMeters == null) {
        return null;
      }

      final RoadRoute result = RoadRoute(
        points: points,
        duration: Duration(
          milliseconds: (durationSeconds * 1000).round(),
        ),
        distanceMeters: distanceMeters,
      );
      _routeCache[cacheKey] = result;
      _trimCache(_routeCache);
      return result;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RoadRoute?> routeThrough({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    if (destinations.isEmpty) {
      return null;
    }
    if (destinations.length == 1) {
      return route(origin: origin, destination: destinations.first);
    }

    final List<LatLng> points = <LatLng>[origin, ...destinations];
    final String cacheKey = 'through:${_coordinates(points)}';
    final RoadRoute? cached = _routeCache.remove(cacheKey);
    if (cached != null) {
      _routeCache[cacheKey] = cached;
      return cached;
    }

    final Uri uri = Uri.parse(
      '$_baseUrl/route/v1/driving/${_coordinates(points)}',
    ).replace(
      queryParameters: const <String, String>{
        'overview': 'simplified',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    try {
      final http.Response response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }
      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> routes = json['routes'] as List<dynamic>? ?? const [];
      if (json['code'] != 'Ok' || routes.isEmpty) {
        return null;
      }
      final Map<String, dynamic> rawRoute =
          routes.first as Map<String, dynamic>;
      final Map<String, dynamic> geometry =
          rawRoute['geometry'] as Map<String, dynamic>? ?? const {};
      final List<LatLng> routePoints =
          (geometry['coordinates'] as List<dynamic>? ?? const [])
              .whereType<List<dynamic>>()
              .map(_pointFromGeoJson)
              .whereType<LatLng>()
              .toList(growable: false);
      final double? durationSeconds =
          _nonNegativeFiniteDouble(rawRoute['duration']);
      final double? distanceMeters =
          _nonNegativeFiniteDouble(rawRoute['distance']);
      if (routePoints.length < 2 ||
          durationSeconds == null ||
          distanceMeters == null) {
        return null;
      }
      final RoadRoute result = RoadRoute(
        points: routePoints,
        duration: Duration(milliseconds: (durationSeconds * 1000).round()),
        distanceMeters: distanceMeters,
      );
      _routeCache[cacheKey] = result;
      _trimCache(_routeCache);
      return result;
    } catch (_) {
      return null;
    }
  }

  @override
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  static String _coordinates(Iterable<LatLng> points) =>
      points.map(_coordinate).join(';');

  static String _coordinate(LatLng point) =>
      '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}';

  static void _trimCache<T>(Map<String, T> cache) {
    while (cache.length > _maxCachedRoutes) {
      cache.remove(cache.keys.first);
    }
  }

  static List<dynamic> _firstMatrixRow(Object? value) {
    final List<dynamic> matrix = value as List<dynamic>? ?? const [];
    if (matrix.isEmpty) {
      return const [];
    }
    return matrix.first as List<dynamic>? ?? const [];
  }

  static double? _finiteDouble(Object? value) {
    if (value is! num) {
      return null;
    }
    final double result = value.toDouble();
    return result.isFinite ? result : null;
  }

  static double? _nonNegativeFiniteDouble(Object? value) {
    final double? result = _finiteDouble(value);
    return result != null && result >= 0 ? result : null;
  }

  static LatLng? _pointFromGeoJson(List<dynamic> pair) {
    if (pair.length < 2) {
      return null;
    }
    final double? longitude = _finiteDouble(pair[0]);
    final double? latitude = _finiteDouble(pair[1]);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }
}

extension _SafeListAccess<T> on List<T> {
  T? elementAtOrNull(int index) =>
      index < 0 || index >= length ? null : this[index];
}
