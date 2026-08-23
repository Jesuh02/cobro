import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import 'osrm_road_router.dart';

/// Keeps precise locations on the authenticated application channel. The
/// backend owns the OSRM provider, timeout and shared route cache.
class ApiRoadRouter implements RoadRouter {
  ApiRoadRouter(this._apiClient);

  static const Duration _requestTimeout = Duration(seconds: 12);
  static const int _maxCachedEntries = 96;

  final ApiClient _apiClient;
  final Map<String, List<RoadTravelEstimate?>> _estimateCache =
      <String, List<RoadTravelEstimate?>>{};
  final Map<String, RoadRoute> _routeCache = <String, RoadRoute>{};

  @override
  Future<List<RoadTravelEstimate?>?> estimateTrips({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    if (destinations.isEmpty) {
      return const <RoadTravelEstimate?>[];
    }
    final String cacheKey =
        'estimates:${_coordinate(origin)}>${_coordinates(destinations)}';
    final List<RoadTravelEstimate?>? cached = _estimateCache.remove(cacheKey);
    if (cached != null) {
      _estimateCache[cacheKey] = cached;
      return List<RoadTravelEstimate?>.of(cached, growable: false);
    }
    try {
      final Map<String, dynamic> json = await _apiClient.postObject(
        '/routing/estimates',
        <String, dynamic>{
          'origin': _point(origin),
          'destinations': destinations.map(_point).toList(growable: false),
        },
      ).timeout(_requestTimeout);
      if (json['providerAvailable'] == false) {
        return null;
      }
      final List<dynamic> estimates =
          json['estimates'] as List<dynamic>? ?? const <dynamic>[];
      final List<RoadTravelEstimate?> result =
          List<RoadTravelEstimate?>.generate(
        destinations.length,
        (int index) {
          if (index >= estimates.length ||
              estimates[index] is! Map<String, dynamic>) {
            return null;
          }
          final Map<String, dynamic> estimate =
              estimates[index] as Map<String, dynamic>;
          final double? durationMs =
              _nonNegativeFiniteDouble(estimate['durationMs']);
          final double? distanceMeters =
              _nonNegativeFiniteDouble(estimate['distanceMeters']);
          if (durationMs == null || distanceMeters == null) {
            return null;
          }
          return RoadTravelEstimate(
            duration: Duration(milliseconds: durationMs.round()),
            distanceMeters: distanceMeters,
          );
        },
        growable: false,
      );
      _rememberEstimates(cacheKey, result);
      return result;
    } on Object {
      return null;
    }
  }

  @override
  Future<RoadRoute?> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final String cacheKey =
        'route:${_coordinate(origin)}>${_coordinate(destination)}';
    final RoadRoute? cached = _routeCache.remove(cacheKey);
    if (cached != null) {
      _routeCache[cacheKey] = cached;
      return cached;
    }
    try {
      final Map<String, dynamic> json = await _apiClient.postObject(
        '/routing/route',
        <String, dynamic>{
          'origin': _point(origin),
          'destination': _point(destination),
        },
      ).timeout(_requestTimeout);
      final Object? rawRoute = json['route'];
      if (rawRoute is! Map<String, dynamic>) {
        return null;
      }
      final List<dynamic> rawPoints =
          rawRoute['points'] as List<dynamic>? ?? const <dynamic>[];
      final List<LatLng> points = rawPoints
          .whereType<List<dynamic>>()
          .map(_pointFromPair)
          .whereType<LatLng>()
          .toList(growable: false);
      final double? durationMs =
          _nonNegativeFiniteDouble(rawRoute['durationMs']);
      final double? distanceMeters =
          _nonNegativeFiniteDouble(rawRoute['distanceMeters']);
      if (points.length < 2 || durationMs == null || distanceMeters == null) {
        return null;
      }
      final RoadRoute result = RoadRoute(
        points: points,
        duration: Duration(milliseconds: durationMs.round()),
        distanceMeters: distanceMeters,
      );
      _rememberRoute(cacheKey, result);
      return result;
    } on Object {
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
    final String cacheKey =
        'through:${_coordinate(origin)}>${_coordinates(destinations)}';
    final RoadRoute? cached = _routeCache.remove(cacheKey);
    if (cached != null) {
      _routeCache[cacheKey] = cached;
      return cached;
    }
    try {
      final Map<String, dynamic> json = await _apiClient.postObject(
        '/routing/route-through',
        <String, dynamic>{
          'origin': _point(origin),
          'destinations': destinations.map(_point).toList(growable: false),
        },
      ).timeout(_requestTimeout);
      final RoadRoute? route = _routeFromJson(json['route']);
      if (route != null) {
        _rememberRoute(cacheKey, route);
      }
      return route;
    } on Object {
      return null;
    }
  }

  @override
  void close() {}

  static Map<String, double> _point(LatLng point) => <String, double>{
        'latitude': point.latitude,
        'longitude': point.longitude,
      };

  static String _coordinates(Iterable<LatLng> points) =>
      points.map(_coordinate).join(';');

  static String _coordinate(LatLng point) =>
      '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}';

  void _rememberEstimates(
    String key,
    List<RoadTravelEstimate?> estimates,
  ) {
    _estimateCache[key] = List<RoadTravelEstimate?>.of(
      estimates,
      growable: false,
    );
    _trimCache(_estimateCache);
  }

  void _rememberRoute(String key, RoadRoute route) {
    _routeCache[key] = route;
    _trimCache(_routeCache);
  }

  static void _trimCache<T>(Map<String, T> cache) {
    while (cache.length > _maxCachedEntries) {
      cache.remove(cache.keys.first);
    }
  }

  static RoadRoute? _routeFromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    final List<LatLng> points =
        (value['points'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<List<dynamic>>()
            .map(_pointFromPair)
            .whereType<LatLng>()
            .toList(growable: false);
    final double? durationMs = _nonNegativeFiniteDouble(value['durationMs']);
    final double? distanceMeters =
        _nonNegativeFiniteDouble(value['distanceMeters']);
    if (points.length < 2 || durationMs == null || distanceMeters == null) {
      return null;
    }
    return RoadRoute(
      points: points,
      duration: Duration(milliseconds: durationMs.round()),
      distanceMeters: distanceMeters,
    );
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

  static LatLng? _pointFromPair(List<dynamic> pair) {
    if (pair.length < 2) {
      return null;
    }
    final double? latitude = _finiteDouble(pair[0]);
    final double? longitude = _finiteDouble(pair[1]);
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
