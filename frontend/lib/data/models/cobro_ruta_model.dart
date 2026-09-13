import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/utils/json_utils.dart';

enum EstadoCobro {
  alDia,
  pendiente,
  atrasado,
  pagado;

  factory EstadoCobro.fromWire(String value) {
    return switch (value) {
      'AL_DIA' => EstadoCobro.alDia,
      'PENDIENTE' => EstadoCobro.pendiente,
      'ATRASADO' => EstadoCobro.atrasado,
      'PAGADO' => EstadoCobro.pagado,
      _ => EstadoCobro.pendiente,
    };
  }

  String get etiqueta {
    return switch (this) {
      EstadoCobro.alDia => 'Al día',
      EstadoCobro.pendiente => 'Debe hoy',
      EstadoCobro.atrasado => 'Atrasado',
      EstadoCobro.pagado => 'Pagado',
    };
  }

  Color get color {
    return switch (this) {
      EstadoCobro.alDia => CobroAppTheme.success,
      EstadoCobro.pendiente => CobroAppTheme.warning,
      EstadoCobro.atrasado => CobroAppTheme.danger,
      EstadoCobro.pagado => CobroAppTheme.primary,
    };
  }
}

class CobroRuta {
  const CobroRuta({
    required this.id,
    required this.clienteId,
    required this.cliente,
    required this.rutaId,
    required this.ruta,
    required this.valorTotal,
    required this.valorCuota,
    required this.totalAbonado,
    required this.saldo,
    required this.numeroCuotas,
    required this.cuotasRestantes,
    required this.estadoCobro,
    required this.proximoSaldoCuota,
    this.cedula,
    this.negocio,
    this.direccion,
    this.latitude,
    this.longitude,
    this.proximaCuotaId,
    this.proximaNumeroCuota,
    this.proximaFechaPago,
  });

  factory CobroRuta.fromJson(Map<String, dynamic> json) {
    return CobroRuta(
      id: json['id'] as String,
      clienteId: json['clienteId'] as String? ?? json['id'] as String,
      cliente: json['cliente'] as String,
      cedula: json['cedula'] as String?,
      negocio: json['negocio'] as String?,
      direccion: json['direccion'] as String?,
      latitude: parseJsonDoubleNullable(json['latitud']),
      longitude: parseJsonDoubleNullable(json['longitud']),
      rutaId: json['rutaId'] as String? ?? '',
      ruta: json['ruta'] as String? ?? 'Sin ruta',
      valorTotal: parseJsonDouble(json['valorTotal']),
      valorCuota: parseJsonDouble(json['valorCuota']),
      totalAbonado: parseJsonDouble(json['totalAbonado']),
      saldo: parseJsonDouble(json['saldo']),
      numeroCuotas: parseJsonInt(json['numeroCuotas']),
      cuotasRestantes: parseJsonInt(json['cuotasRestantes']),
      proximaCuotaId: json['proximaCuotaId'] as String?,
      proximaNumeroCuota: parseJsonIntNullable(json['proximaNumeroCuota']),
      proximaFechaPago: parseJsonDateTime(json['proximaFechaPago']),
      proximoSaldoCuota: parseJsonDouble(json['proximoSaldoCuota']),
      estadoCobro: EstadoCobro.fromWire(json['estadoCobro'] as String),
    );
  }

  static const Object _sinCambio = Object();

  CobroRuta copyWith({
    String? direccion,
    double? latitude,
    double? longitude,
    double? totalAbonado,
    double? saldo,
    int? cuotasRestantes,
    Object? proximaCuotaId = _sinCambio,
    Object? proximaNumeroCuota = _sinCambio,
    Object? proximaFechaPago = _sinCambio,
    double? proximoSaldoCuota,
    EstadoCobro? estadoCobro,
  }) {
    return CobroRuta(
      id: id,
      clienteId: clienteId,
      cliente: cliente,
      cedula: cedula,
      negocio: negocio,
      direccion: direccion ?? this.direccion,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rutaId: rutaId,
      ruta: ruta,
      valorTotal: valorTotal,
      valorCuota: valorCuota,
      totalAbonado: totalAbonado ?? this.totalAbonado,
      saldo: saldo ?? this.saldo,
      numeroCuotas: numeroCuotas,
      cuotasRestantes: cuotasRestantes ?? this.cuotasRestantes,
      proximaCuotaId: identical(proximaCuotaId, _sinCambio)
          ? this.proximaCuotaId
          : proximaCuotaId as String?,
      proximaNumeroCuota: identical(proximaNumeroCuota, _sinCambio)
          ? this.proximaNumeroCuota
          : proximaNumeroCuota as int?,
      proximaFechaPago: identical(proximaFechaPago, _sinCambio)
          ? this.proximaFechaPago
          : proximaFechaPago as DateTime?,
      proximoSaldoCuota: proximoSaldoCuota ?? this.proximoSaldoCuota,
      estadoCobro: estadoCobro ?? this.estadoCobro,
    );
  }

  final String id;
  final String clienteId;
  final String cliente;
  final String? cedula;
  final String? negocio;
  final String? direccion;
  final double? latitude;
  final double? longitude;
  final String rutaId;
  final String ruta;
  final double valorTotal;
  final double valorCuota;
  final double totalAbonado;
  final double saldo;
  final int numeroCuotas;
  final int cuotasRestantes;
  final String? proximaCuotaId;
  final int? proximaNumeroCuota;
  final DateTime? proximaFechaPago;
  final double proximoSaldoCuota;
  final EstadoCobro estadoCobro;

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
