import '../../core/utils/json_utils.dart';

class Presupuesto {
  const Presupuesto({required this.items, required this.totales});

  factory Presupuesto.fromJson(Map<String, dynamic> json) {
    return Presupuesto(
      items: parseJsonList(json['items'])
          .map(PresupuestoItem.fromJson)
          .toList(growable: false),
      totales:
          PresupuestoTotales.fromJson(json['totales'] as Map<String, dynamic>),
    );
  }

  final List<PresupuestoItem> items;
  final PresupuestoTotales totales;
}

class PresupuestoItem {
  const PresupuestoItem({
    required this.cajaMenorId,
    required this.cajaMenorNombre,
    required this.monedaCodigo,
    required this.cajaMenor,
    required this.recaudado,
    required this.gastos,
    required this.creditos,
    required this.creditosRefinanciados,
    required this.clientesCreditos,
    required this.valorRefinanciado,
    required this.presupuesto,
  });

  factory PresupuestoItem.fromJson(Map<String, dynamic> json) {
    return PresupuestoItem(
      cajaMenorId: json['cajaMenorId'] as String? ?? '',
      cajaMenorNombre: json['cajaMenorNombre'] as String? ?? 'Caja menor',
      monedaCodigo: json['monedaCodigo'] as String,
      cajaMenor: parseJsonDouble(json['cajaMenor']),
      recaudado: parseJsonDouble(json['recaudado']),
      gastos: parseJsonDouble(json['gastos']).abs(),
      creditos: parseJsonDouble(json['creditos']),
      creditosRefinanciados: parseJsonInt(json['creditosRefinanciados']),
      clientesCreditos: parseJsonInt(json['clientesCreditos']),
      valorRefinanciado: parseJsonDouble(json['valorRefinanciado']),
      presupuesto: parseJsonDouble(json['presupuesto']),
    );
  }

  final String cajaMenorId;
  final String cajaMenorNombre;
  final String monedaCodigo;
  final double cajaMenor;
  final double recaudado;
  final double gastos;
  final double creditos;
  final int creditosRefinanciados;
  final int clientesCreditos;
  final double valorRefinanciado;
  final double presupuesto;
}

class PresupuestoTotales {
  const PresupuestoTotales({
    required this.cajaMenor,
    required this.recaudado,
    required this.gastos,
    required this.creditos,
    required this.creditosRefinanciados,
    required this.clientesCreditos,
    required this.valorRefinanciado,
    required this.presupuesto,
  });

  const PresupuestoTotales.vacio()
      : cajaMenor = 0,
        recaudado = 0,
        gastos = 0,
        creditos = 0,
        creditosRefinanciados = 0,
        clientesCreditos = 0,
        valorRefinanciado = 0,
        presupuesto = 0;

  factory PresupuestoTotales.fromJson(Map<String, dynamic> json) {
    return PresupuestoTotales(
      cajaMenor: parseJsonDouble(json['cajaMenor']),
      recaudado: parseJsonDouble(json['recaudado']),
      gastos: parseJsonDouble(json['gastos']).abs(),
      creditos: parseJsonDouble(json['creditos']),
      creditosRefinanciados: parseJsonInt(json['creditosRefinanciados']),
      clientesCreditos: parseJsonInt(json['clientesCreditos']),
      valorRefinanciado: parseJsonDouble(json['valorRefinanciado']),
      presupuesto: parseJsonDouble(json['presupuesto']),
    );
  }

  final double cajaMenor;
  final double recaudado;
  final double gastos;
  final double creditos;
  final int creditosRefinanciados;
  final int clientesCreditos;
  final double valorRefinanciado;
  final double presupuesto;
}
