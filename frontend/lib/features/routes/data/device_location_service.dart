import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// A user-facing location failure that can be shown without leaking platform
/// implementation details.
class RouteLocationException implements Exception {
  const RouteLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class RouteLocationService {
  Future<LatLng> currentPosition();
}

/// Reads one precise position on demand. This adapter does not persist or
/// stream it; the caller explicitly decides whether to store the result.
class DeviceRouteLocationService implements RouteLocationService {
  const DeviceRouteLocationService();

  @override
  Future<LatLng> currentPosition() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const RouteLocationException(
        'Activa la ubicación del equipo para calcular la ruta más rápida.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const RouteLocationException(
        'Necesitamos permiso de ubicación para encontrar el cobro más cercano.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const RouteLocationException(
        'El permiso de ubicación está bloqueado. Habilítalo en el navegador o en el sistema.',
      );
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } on RouteLocationException {
      rethrow;
    } catch (_) {
      throw const RouteLocationException(
        'No pudimos obtener tu ubicación. Verifica el permiso e inténtalo de nuevo.',
      );
    }
  }
}
