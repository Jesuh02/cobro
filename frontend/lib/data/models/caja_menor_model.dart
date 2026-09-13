import '../../core/utils/json_utils.dart';
import 'catalogo_model.dart';

class MovimientoCaja {
  const MovimientoCaja({
    required this.id,
    required this.cajaMenorId,
    required this.cajaMenor,
    required this.tipoMovimiento,
    required this.fechaMovimiento,
    required this.monto,
    required this.montoConNaturaleza,
    required this.motivo,
    this.cliente,
    this.clienteIdentificacion,
    this.usuario,
    this.referenciaTabla,
    this.referenciaId,
  });

  factory MovimientoCaja.fromJson(Map<String, dynamic> json) {
    final Object? usuario = json['usuario'];
    return MovimientoCaja(
      id: json['id'] as String,
      cajaMenorId: json['cajaMenorId'] as String? ?? '',
      cajaMenor: json['cajaMenor'] as String,
      tipoMovimiento: TipoMovimientoCaja.fromJson(
        json['tipoMovimiento'] as Map<String, dynamic>,
      ),
      fechaMovimiento: DateTime.parse(json['fechaMovimiento'] as String),
      monto: parseJsonDouble(json['monto']),
      montoConNaturaleza: parseJsonDouble(json['montoConNaturaleza']),
      motivo: json['motivo'] as String,
      cliente: json['cliente'] as String?,
      clienteIdentificacion: json['clienteIdentificacion'] as String?,
      usuario: usuario is Map<String, dynamic>
          ? UsuarioCatalogo.fromJson(usuario)
          : null,
      referenciaTabla: json['referenciaTabla'] as String?,
      referenciaId: json['referenciaId'] as String?,
    );
  }

  final String id;
  final String cajaMenorId;
  final String cajaMenor;
  final TipoMovimientoCaja tipoMovimiento;
  final DateTime fechaMovimiento;
  final double monto;
  final double montoConNaturaleza;
  final String motivo;
  final String? cliente;
  final String? clienteIdentificacion;
  final UsuarioCatalogo? usuario;
  final String? referenciaTabla;
  final String? referenciaId;

  bool get esPago => referenciaTabla == 'pago';
  bool get esAuditoria => referenciaTabla == 'auditoria_caja_menor';
  bool get esEditablePorAdmin => !esAuditoria;

  MovimientoCaja copyWith({
    String? cajaMenorId,
    String? cajaMenor,
    TipoMovimientoCaja? tipoMovimiento,
    DateTime? fechaMovimiento,
    double? monto,
    double? montoConNaturaleza,
    String? motivo,
  }) {
    return MovimientoCaja(
      id: id,
      cajaMenorId: cajaMenorId ?? this.cajaMenorId,
      cajaMenor: cajaMenor ?? this.cajaMenor,
      tipoMovimiento: tipoMovimiento ?? this.tipoMovimiento,
      fechaMovimiento: fechaMovimiento ?? this.fechaMovimiento,
      monto: monto ?? this.monto,
      montoConNaturaleza: montoConNaturaleza ?? this.montoConNaturaleza,
      motivo: motivo ?? this.motivo,
      cliente: cliente,
      clienteIdentificacion: clienteIdentificacion,
      usuario: usuario,
      referenciaTabla: referenciaTabla,
      referenciaId: referenciaId,
    );
  }

  String get motivoVisible {
    final String? clienteNombre =
        cliente?.trim().isEmpty ?? true ? null : cliente!.trim();

    if (referenciaTabla == 'credito_desembolso' && clienteNombre != null) {
      return 'Desembolso de credito para $clienteNombre';
    }

    return motivo;
  }
}
