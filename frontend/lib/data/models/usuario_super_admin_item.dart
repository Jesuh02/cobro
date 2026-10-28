import '../../core/utils/json_utils.dart';

class UsuarioSuperAdminItem {
  const UsuarioSuperAdminItem({
    required this.id,
    required this.usuario,
    required this.nombreCompleto,
    required this.nombres,
    required this.apellidos,
    required this.identificacion,
    required this.correo,
    required this.telefono,
    required this.activo,
    required this.organizacionId,
    required this.organizacionNombre,
    required this.organizacionSuspendida,
    required this.roles,
    required this.creadoEn,
  });

  factory UsuarioSuperAdminItem.fromJson(Map<String, dynamic> json) {
    final Object? rawRoles = json['roles'];
    return UsuarioSuperAdminItem(
      id: json['id'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String? ?? '',
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      identificacion: json['identificacion'] as String?,
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String?,
      activo: json['activo'] as bool? ?? true,
      organizacionId: json['organizacionId'] as String?,
      organizacionNombre: json['organizacionNombre'] as String?,
      organizacionSuspendida: json['organizacionSuspendida'] as bool? ?? false,
      roles: rawRoles is List<dynamic>
          ? rawRoles.whereType<String>().toList(growable: false)
          : const <String>[],
      creadoEn: parseJsonDateTime(json['creadoEn']),
    );
  }

  final String id;
  final String usuario;
  final String nombreCompleto;
  final String nombres;
  final String apellidos;
  final String? identificacion;
  final String correo;
  final String? telefono;
  final bool activo;
  final String? organizacionId;
  final String? organizacionNombre;
  final bool organizacionSuspendida;
  final List<String> roles;
  final DateTime? creadoEn;

  bool get esSuperAdmin => roles.contains('SUPER_ADMIN');
  bool get esAdministrador => roles.contains('ADMINISTRADOR');
  bool get esAdmin => esSuperAdmin || esAdministrador;
  bool get esCobrador => roles.contains('COBRADOR');
  bool get esAuditor => roles.contains('AUDITOR');

  String get nombreVisible {
    final String completo = nombreCompleto.trim();
    if (completo.isNotEmpty) return completo;

    final String compuesto = '$nombres $apellidos'.trim();
    return compuesto.isNotEmpty ? compuesto : usuario;
  }

  String get organizacionVisible {
    final String nombre = organizacionNombre?.trim() ?? '';
    return nombre.isEmpty ? 'Sin institución' : nombre;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'usuario': usuario,
      'nombreCompleto': nombreCompleto,
      'nombres': nombres,
      'apellidos': apellidos,
      'identificacion': identificacion,
      'correo': correo,
      'telefono': telefono,
      'activo': activo,
      'organizacionId': organizacionId,
      'organizacionNombre': organizacionNombre,
      'organizacionSuspendida': organizacionSuspendida,
      'roles': roles,
      'creadoEn': creadoEn?.toIso8601String(),
    };
  }

  UsuarioSuperAdminItem copyWith({
    bool? activo,
  }) {
    return UsuarioSuperAdminItem(
      id: id,
      usuario: usuario,
      nombreCompleto: nombreCompleto,
      nombres: nombres,
      apellidos: apellidos,
      identificacion: identificacion,
      correo: correo,
      telefono: telefono,
      activo: activo ?? this.activo,
      organizacionId: organizacionId,
      organizacionNombre: organizacionNombre,
      organizacionSuspendida: organizacionSuspendida,
      roles: roles,
      creadoEn: creadoEn,
    );
  }
}
