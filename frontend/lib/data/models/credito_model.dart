import '../../core/utils/json_utils.dart';
import 'catalogo_model.dart';

class CreditoRegistro {
  const CreditoRegistro({
    required this.id,
    required this.clienteId,
    required this.cliente,
    required this.rutaId,
    required this.ruta,
    required this.monedaCodigo,
    required this.frecuenciaPago,
    required this.estado,
    required this.fechaInicio,
    required this.valorPrincipal,
    required this.porcentajeInteres,
    required this.plazoDias,
    required this.omitirDomingos,
    required this.valorTotal,
    required this.valorCuota,
    required this.totalAbonado,
    required this.saldo,
    required this.numeroCuotas,
    required this.cuotasRestantes,
    required this.fechaMaxima,
    this.cedula,
    this.negocio,
    this.direccion,
    this.cajaMenorId,
    this.cajaMenor,
    this.refinanciacion,
    this.observacion,
    this.creadoEn,
    this.actualizadoEn,
  });

  factory CreditoRegistro.fromJson(Map<String, dynamic> json) {
    final Object? refinanciacion = json['refinanciacion'];
    return CreditoRegistro(
      id: json['id'] as String,
      clienteId: json['clienteId'] as String,
      cliente: json['cliente'] as String,
      cedula: json['cedula'] as String?,
      negocio: json['negocio'] as String?,
      direccion: json['direccion'] as String?,
      rutaId: json['rutaId'] as String? ?? '',
      ruta: json['ruta'] as String? ?? 'Sin ruta',
      cajaMenorId: json['cajaMenorId'] as String?,
      cajaMenor: json['cajaMenor'] as String?,
      monedaCodigo: json['monedaCodigo'] as String? ?? 'COP',
      frecuenciaPago: FrecuenciaPago.fromJson(
        json['frecuenciaPago'] as Map<String, dynamic>,
      ),
      estado: EstadoCreditoRegistro.fromJson(
        json['estado'] as Map<String, dynamic>,
      ),
      fechaInicio: DateTime.parse(json['fechaInicio'] as String),
      valorPrincipal: parseJsonDouble(json['valorPrincipal']),
      porcentajeInteres: parseJsonDouble(json['porcentajeInteres']),
      plazoDias: parseJsonInt(json['plazoDias']),
      omitirDomingos: json['omitirDomingos'] as bool? ?? true,
      valorTotal: parseJsonDouble(json['valorTotal']),
      valorCuota: parseJsonDouble(json['valorCuota']),
      totalAbonado: parseJsonDouble(json['totalAbonado']),
      saldo: parseJsonDouble(json['saldo']),
      numeroCuotas: parseJsonInt(json['numeroCuotas']),
      cuotasRestantes: parseJsonInt(json['cuotasRestantes']),
      fechaMaxima: DateTime.parse(json['fechaMaxima'] as String),
      refinanciacion: refinanciacion is Map<String, dynamic>
          ? CreditoRefinanciacion.fromJson(refinanciacion)
          : null,
      observacion: json['observacion'] as String?,
      creadoEn: parseJsonDateTime(json['creadoEn']),
      actualizadoEn: parseJsonDateTime(json['actualizadoEn']),
    );
  }

  final String id;
  final String clienteId;
  final String cliente;
  final String? cedula;
  final String? negocio;
  final String? direccion;
  final String rutaId;
  final String ruta;
  final String? cajaMenorId;
  final String? cajaMenor;
  final String monedaCodigo;
  final FrecuenciaPago frecuenciaPago;
  final EstadoCreditoRegistro estado;
  final DateTime fechaInicio;
  final double valorPrincipal;
  final double porcentajeInteres;
  final int plazoDias;
  final bool omitirDomingos;
  final double valorTotal;
  final double valorCuota;
  final double totalAbonado;
  final double saldo;
  final int numeroCuotas;
  final int cuotasRestantes;
  final DateTime fechaMaxima;
  final CreditoRefinanciacion? refinanciacion;
  final String? observacion;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  bool get pagado =>
      estado.codigo == 'PAGADO' || saldo <= 0.009 || cuotasRestantes <= 0;

  bool get activo => estado.codigo == 'ACTIVO';

  bool get inactivo => estado.codigo == 'PAGADO';

  DateTime? get fechaModificacionVisible {
    final DateTime? actualizado = actualizadoEn;
    if (actualizado == null) {
      return null;
    }

    final DateTime? creado = creadoEn;
    if (creado == null) {
      return actualizado;
    }

    if (actualizado.difference(creado).abs() <= const Duration(seconds: 1)) {
      return null;
    }

    return actualizado;
  }

  static const Object _sinCambio = Object();

  CreditoRegistro copyWith({
    String? clienteId,
    String? cliente,
    Object? cedula = _sinCambio,
    Object? negocio = _sinCambio,
    Object? direccion = _sinCambio,
    String? rutaId,
    String? ruta,
    Object? cajaMenorId = _sinCambio,
    Object? cajaMenor = _sinCambio,
    String? monedaCodigo,
    FrecuenciaPago? frecuenciaPago,
    EstadoCreditoRegistro? estado,
    DateTime? fechaInicio,
    double? valorPrincipal,
    double? porcentajeInteres,
    int? plazoDias,
    bool? omitirDomingos,
    double? valorTotal,
    double? valorCuota,
    double? totalAbonado,
    double? saldo,
    int? numeroCuotas,
    int? cuotasRestantes,
    DateTime? fechaMaxima,
    Object? refinanciacion = _sinCambio,
    Object? observacion = _sinCambio,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return CreditoRegistro(
      id: id,
      clienteId: clienteId ?? this.clienteId,
      cliente: cliente ?? this.cliente,
      cedula: identical(cedula, _sinCambio) ? this.cedula : cedula as String?,
      negocio:
          identical(negocio, _sinCambio) ? this.negocio : negocio as String?,
      direccion: identical(direccion, _sinCambio)
          ? this.direccion
          : direccion as String?,
      rutaId: rutaId ?? this.rutaId,
      ruta: ruta ?? this.ruta,
      cajaMenorId: identical(cajaMenorId, _sinCambio)
          ? this.cajaMenorId
          : cajaMenorId as String?,
      cajaMenor: identical(cajaMenor, _sinCambio)
          ? this.cajaMenor
          : cajaMenor as String?,
      monedaCodigo: monedaCodigo ?? this.monedaCodigo,
      frecuenciaPago: frecuenciaPago ?? this.frecuenciaPago,
      estado: estado ?? this.estado,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      valorPrincipal: valorPrincipal ?? this.valorPrincipal,
      porcentajeInteres: porcentajeInteres ?? this.porcentajeInteres,
      plazoDias: plazoDias ?? this.plazoDias,
      omitirDomingos: omitirDomingos ?? this.omitirDomingos,
      valorTotal: valorTotal ?? this.valorTotal,
      valorCuota: valorCuota ?? this.valorCuota,
      totalAbonado: totalAbonado ?? this.totalAbonado,
      saldo: saldo ?? this.saldo,
      numeroCuotas: numeroCuotas ?? this.numeroCuotas,
      cuotasRestantes: cuotasRestantes ?? this.cuotasRestantes,
      fechaMaxima: fechaMaxima ?? this.fechaMaxima,
      refinanciacion: identical(refinanciacion, _sinCambio)
          ? this.refinanciacion
          : refinanciacion as CreditoRefinanciacion?,
      observacion: identical(observacion, _sinCambio)
          ? this.observacion
          : observacion as String?,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }
}

class EstadoCreditoRegistro {
  const EstadoCreditoRegistro({required this.codigo, required this.nombre});

  factory EstadoCreditoRegistro.fromJson(Map<String, dynamic> json) {
    return EstadoCreditoRegistro(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );
  }

  final String codigo;
  final String nombre;
}

class CreditoRefinanciacion {
  const CreditoRefinanciacion({
    required this.fecha,
    required this.valorAnterior,
    required this.valorNuevo,
  });

  factory CreditoRefinanciacion.fromJson(Map<String, dynamic> json) {
    return CreditoRefinanciacion(
      fecha: DateTime.parse(json['fecha'] as String),
      valorAnterior: parseJsonDouble(json['valorAnterior']),
      valorNuevo: parseJsonDouble(json['valorNuevo']),
    );
  }

  final DateTime fecha;
  final double valorAnterior;
  final double valorNuevo;
}
