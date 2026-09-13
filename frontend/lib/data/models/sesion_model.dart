import '../../core/constants/permisos_constants.dart';
import '../../core/utils/json_utils.dart';

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
            ? permisosEmpleadoCodigos
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
      montoPlan: parseJsonDouble(json['montoPlan']),
      monedaPlan: json['monedaPlan'] as String? ?? 'COP',
      accesoHasta: json['accesoHasta'] as String?,
      suspendidaEn: json['suspendidaEn'] as String?,
      motivoSuspension: json['motivoSuspension'] as String?,
      suspendida: json['suspendida'] as bool? ?? false,
      diasRestantes: parseJsonIntNullable(json['diasRestantes']),
      usuariosTotal: parseJsonInt(json['usuariosTotal']),
      usuariosActivos: parseJsonInt(json['usuariosActivos']),
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

