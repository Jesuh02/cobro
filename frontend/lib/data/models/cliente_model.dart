import '../../core/utils/json_utils.dart';

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
          parseJsonDoubleNullable(json['latitud'] ?? direccionPrincipal?['latitud']),
      longitude:
          parseJsonDoubleNullable(json['longitud'] ?? direccionPrincipal?['longitud']),
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

