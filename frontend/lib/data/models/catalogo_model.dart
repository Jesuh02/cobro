import '../../core/utils/json_utils.dart';

class Catalogos {
  const Catalogos({
    required this.monedas,
    required this.frecuenciasPago,
    required this.mediosPago,
    required this.tiposMovimientoCaja,
    required this.rutas,
    required this.cajasMenores,
    required this.usuarios,
  });

  factory Catalogos.fromJson(Map<String, dynamic> json) {
    return Catalogos(
      monedas: parseJsonList(json['monedas'])
          .map(Moneda.fromJson)
          .toList(growable: false),
      frecuenciasPago: parseJsonList(json['frecuenciasPago'])
          .map(FrecuenciaPago.fromJson)
          .toList(growable: false),
      mediosPago: parseJsonList(json['mediosPago'])
          .map(MedioPago.fromJson)
          .toList(growable: false),
      tiposMovimientoCaja: parseJsonList(json['tiposMovimientoCaja'])
          .map(TipoMovimientoCaja.fromJson)
          .toList(growable: false),
      rutas: parseJsonList(json['rutas'])
          .map(RutaCatalogo.fromJson)
          .toList(growable: false),
      cajasMenores: parseJsonList(json['cajasMenores'])
          .map(CajaMenorCatalogo.fromJson)
          .toList(growable: false),
      usuarios: parseJsonList(json['usuarios'])
          .map(UsuarioCatalogo.fromJson)
          .toList(growable: false),
    );
  }

  final List<Moneda> monedas;
  final List<FrecuenciaPago> frecuenciasPago;
  final List<MedioPago> mediosPago;
  final List<TipoMovimientoCaja> tiposMovimientoCaja;
  final List<RutaCatalogo> rutas;
  final List<CajaMenorCatalogo> cajasMenores;
  final List<UsuarioCatalogo> usuarios;

  Catalogos copyWith({
    List<Moneda>? monedas,
    List<FrecuenciaPago>? frecuenciasPago,
    List<MedioPago>? mediosPago,
    List<TipoMovimientoCaja>? tiposMovimientoCaja,
    List<RutaCatalogo>? rutas,
    List<CajaMenorCatalogo>? cajasMenores,
    List<UsuarioCatalogo>? usuarios,
  }) {
    return Catalogos(
      monedas: monedas ?? this.monedas,
      frecuenciasPago: frecuenciasPago ?? this.frecuenciasPago,
      mediosPago: mediosPago ?? this.mediosPago,
      tiposMovimientoCaja: tiposMovimientoCaja ?? this.tiposMovimientoCaja,
      rutas: rutas ?? this.rutas,
      cajasMenores: cajasMenores ?? this.cajasMenores,
      usuarios: usuarios ?? this.usuarios,
    );
  }

  List<RutaCatalogo> get rutasAbiertas => rutas
      .where((RutaCatalogo ruta) => ruta.estadoCodigo == 'ABIERTA')
      .toList(growable: false);

  List<CajaMenorCatalogo> get cajasMenoresActivas => cajasMenores
      .where((CajaMenorCatalogo caja) => caja.estaAbierta)
      .toList(growable: false);
}

class UsuarioCatalogo {
  const UsuarioCatalogo({
    required this.id,
    required this.nombreCompleto,
    this.usuario = '',
  });

  factory UsuarioCatalogo.fromJson(Map<String, dynamic> json) {
    return UsuarioCatalogo(
      id: json['id'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      usuario: (json['usuario'] as String?) ?? '',
    );
  }

  final String id;
  final String nombreCompleto;
  final String usuario;
}

class Moneda {
  const Moneda({required this.codigo, required this.nombre});

  factory Moneda.fromJson(Map<String, dynamic> json) {
    return Moneda(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );
  }

  final String codigo;
  final String nombre;
}

class FrecuenciaPago {
  const FrecuenciaPago({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.diasIntervalo,
  });

  factory FrecuenciaPago.fromJson(Map<String, dynamic> json) {
    return FrecuenciaPago(
      id: parseJsonInt(json['id']),
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      diasIntervalo: parseJsonInt(json['diasIntervalo']),
    );
  }

  final int id;
  final String codigo;
  final String nombre;
  final int diasIntervalo;
}

class MedioPago {
  const MedioPago({required this.codigo, required this.nombre});

  factory MedioPago.fromJson(Map<String, dynamic> json) {
    return MedioPago(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );
  }

  final String codigo;
  final String nombre;
}

class TipoMovimientoCaja {
  const TipoMovimientoCaja({
    required this.codigo,
    required this.nombre,
    required this.naturaleza,
  });

  factory TipoMovimientoCaja.fromJson(Map<String, dynamic> json) {
    return TipoMovimientoCaja(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      naturaleza: json['naturaleza'] as String,
    );
  }

  final String codigo;
  final String nombre;
  final String naturaleza;
}

class RutaCatalogo {
  const RutaCatalogo({
    required this.id,
    required this.nombre,
    required this.estadoCodigo,
  });

  factory RutaCatalogo.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> estado = json['estado'] as Map<String, dynamic>;
    return RutaCatalogo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      estadoCodigo: estado['codigo'] as String,
    );
  }

  final String id;
  final String nombre;
  final String estadoCodigo;
}

class CajaMenorCatalogo {
  const CajaMenorCatalogo({
    required this.id,
    required this.nombre,
    required this.activa,
    required this.monedaCodigo,
    this.fechaApertura,
    this.fechaCierre,
    this.responsable,
  });

  factory CajaMenorCatalogo.fromJson(Map<String, dynamic> json) {
    return CajaMenorCatalogo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      activa: json['activa'] as bool,
      monedaCodigo: (json['monedaCodigo'] as String?) ?? 'COP',
      fechaApertura: parseJsonDateTime(json['fechaApertura']),
      fechaCierre: parseJsonDateTime(json['fechaCierre']),
      responsable: json['responsable'] is Map<String, dynamic>
          ? UsuarioCatalogo.fromJson(
              json['responsable'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String id;
  final String nombre;
  final bool activa;
  final String monedaCodigo;
  final DateTime? fechaApertura;
  final DateTime? fechaCierre;
  final UsuarioCatalogo? responsable;

  bool get estaAbierta {
    if (!activa) {
      return false;
    }
    if (fechaCierre != null && !fechaCierre!.isAfter(DateTime.now())) {
      return false;
    }
    return true;
  }
}

