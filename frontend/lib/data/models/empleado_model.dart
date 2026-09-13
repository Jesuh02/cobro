import 'dart:math' as math;

import '../../core/utils/json_utils.dart';

class EmpleadoGestion {
  const EmpleadoGestion({
    required this.id,
    required this.usuario,
    required this.nombreCompleto,
    required this.correo,
    required this.permisos,
    required this.activo,
  });

  factory EmpleadoGestion.fromJson(Map<String, dynamic> json) {
    final Object? rawPermisos = json['permisos'];
    return EmpleadoGestion(
      id: json['id'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      correo: json['correo'] as String,
      permisos: rawPermisos is List<dynamic>
          ? rawPermisos.whereType<String>().toList(growable: false)
          : const <String>[],
      activo: json['activo'] as bool? ?? true,
    );
  }

  final String id;
  final String usuario;
  final String nombreCompleto;
  final String correo;
  final List<String> permisos;
  final bool activo;
}

class ActividadEmpleadosFiltros {
  const ActividadEmpleadosFiltros({
    required this.fechaInicio,
    required this.fechaFin,
    this.empleadoId,
  });

  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? empleadoId;

  Map<String, String?> toQuery() {
    return <String, String?>{
      'inicio': formatJsonDate(fechaInicio),
      'fin': formatJsonDate(fechaFin),
      'empleadoId': empleadoId,
    };
  }
}

enum EstadoActividadEmpleado {
  cumplido,
  pendiente,
  sinRutaHoy;

  factory EstadoActividadEmpleado.fromWire(String? value) {
    return switch (value) {
      'CUMPLIDO' => EstadoActividadEmpleado.cumplido,
      'PENDIENTE' => EstadoActividadEmpleado.pendiente,
      _ => EstadoActividadEmpleado.sinRutaHoy,
    };
  }
}

class ActividadEmpleado {
  const ActividadEmpleado({
    required this.empleadoId,
    required this.usuario,
    required this.nombreCompleto,
    required this.correo,
    required this.activo,
    required this.estadoRuta,
    required this.porcentajeCumplimiento,
    required this.rutas,
    required this.resumen,
    this.ultimaActividad,
  });

  factory ActividadEmpleado.fromJson(Map<String, dynamic> json) {
    final Object? rawResumen = json['resumen'];
    return ActividadEmpleado(
      empleadoId: json['empleadoId'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      correo: json['correo'] as String,
      activo: json['activo'] as bool? ?? true,
      estadoRuta:
          EstadoActividadEmpleado.fromWire(json['estadoRuta'] as String?),
      porcentajeCumplimiento: math.max(
        0,
        math.min(100, parseJsonInt(json['porcentajeCumplimiento'])),
      ),
      rutas: parseJsonList(json['rutas'])
          .map(ActividadRutaEmpleado.fromJson)
          .toList(growable: false),
      resumen: rawResumen is Map<String, dynamic>
          ? ActividadEmpleadoResumen.fromJson(rawResumen)
          : const ActividadEmpleadoResumen.vacio(),
      ultimaActividad: parseJsonDateTime(json['ultimaActividad']),
    );
  }

  final String empleadoId;
  final String usuario;
  final String nombreCompleto;
  final String correo;
  final bool activo;
  final EstadoActividadEmpleado estadoRuta;
  final int porcentajeCumplimiento;
  final List<ActividadRutaEmpleado> rutas;
  final ActividadEmpleadoResumen resumen;
  final DateTime? ultimaActividad;
}

class ActividadEmpleadoResumen {
  const ActividadEmpleadoResumen({
    required this.totalCreditos,
    required this.creditosHoy,
    required this.creditosMes,
    required this.valorCreditosTotal,
    required this.recaudoHoy,
    required this.recaudoMes,
    required this.pagosHoy,
    required this.deberesHoy,
    required this.cumplidosHoy,
    required this.pendientesHoy,
    required this.atrasados,
  });

  const ActividadEmpleadoResumen.vacio()
      : totalCreditos = 0,
        creditosHoy = 0,
        creditosMes = 0,
        valorCreditosTotal = 0,
        recaudoHoy = 0,
        recaudoMes = 0,
        pagosHoy = 0,
        deberesHoy = 0,
        cumplidosHoy = 0,
        pendientesHoy = 0,
        atrasados = 0;

  factory ActividadEmpleadoResumen.fromJson(Map<String, dynamic> json) {
    return ActividadEmpleadoResumen(
      totalCreditos: parseJsonInt(json['totalCreditos']),
      creditosHoy: parseJsonInt(json['creditosHoy']),
      creditosMes: parseJsonInt(json['creditosMes']),
      valorCreditosTotal: parseJsonDouble(json['valorCreditosTotal']),
      recaudoHoy: parseJsonDouble(json['recaudoHoy']),
      recaudoMes: parseJsonDouble(json['recaudoMes']),
      pagosHoy: parseJsonInt(json['pagosHoy']),
      deberesHoy: parseJsonInt(json['deberesHoy']),
      cumplidosHoy: parseJsonInt(json['cumplidosHoy']),
      pendientesHoy: parseJsonInt(json['pendientesHoy']),
      atrasados: parseJsonInt(json['atrasados']),
    );
  }

  final int totalCreditos;
  final int creditosHoy;
  final int creditosMes;
  final double valorCreditosTotal;
  final double recaudoHoy;
  final double recaudoMes;
  final int pagosHoy;
  final int deberesHoy;
  final int cumplidosHoy;
  final int pendientesHoy;
  final int atrasados;
}

class ActividadRutaEmpleado {
  const ActividadRutaEmpleado({
    required this.rutaId,
    required this.nombre,
    required this.creditos,
    required this.clientes,
    required this.debenHoy,
    required this.cumplidosHoy,
    required this.pendientesHoy,
    required this.atrasados,
    required this.recaudadoHoy,
  });

  factory ActividadRutaEmpleado.fromJson(Map<String, dynamic> json) {
    return ActividadRutaEmpleado(
      rutaId: json['rutaId'] as String? ?? '',
      nombre: json['nombre'] as String? ?? 'Ruta',
      creditos: parseJsonInt(json['creditos']),
      clientes: parseJsonInt(json['clientes']),
      debenHoy: parseJsonInt(json['debenHoy']),
      cumplidosHoy: parseJsonInt(json['cumplidosHoy']),
      pendientesHoy: parseJsonInt(json['pendientesHoy']),
      atrasados: parseJsonInt(json['atrasados']),
      recaudadoHoy: parseJsonDouble(json['recaudadoHoy']),
    );
  }

  final String rutaId;
  final String nombre;
  final int creditos;
  final int clientes;
  final int debenHoy;
  final int cumplidosHoy;
  final int pendientesHoy;
  final int atrasados;
  final double recaudadoHoy;
}
