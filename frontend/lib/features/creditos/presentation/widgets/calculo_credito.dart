import 'dart:math' as math;

import '../../../../core/formatters/app_formatters.dart';

class CalculoCredito {
  const CalculoCredito({
    required this.valorPrincipal,
    required this.porcentajeInteres,
    required this.valorInteres,
    required this.valorTotal,
    required this.numeroCuotas,
    required this.valorCuota,
    required this.fechaMaxima,
    required this.domingosOmitidos,
  });

  factory CalculoCredito.desdeFormulario({
    required String valor,
    required String interes,
    required String plazo,
    required DateTime fechaInicio,
    required int diasIntervalo,
    required bool omitirDomingos,
  }) {
    final double valorPrincipal = math.max(0.0, parseNumero(valor) ?? 0);
    final double porcentajeInteres = math.max(
      0.0,
      parseNumero(interes) ?? 0,
    );
    final int plazoDias = math.max(1, (parseNumero(plazo) ?? 1).round());
    final int intervalo = math.max(1, diasIntervalo);
    final int numeroCuotas = math.max(1, (plazoDias / intervalo).ceil());
    final double valorTotal = roundMoney(
      valorPrincipal + valorPrincipal * (porcentajeInteres / 100),
      2,
    );
    final double valorInteres = roundMoney(
      valorTotal - valorPrincipal,
      2,
    );
    final double valorCuota =
        numeroCuotas > 0 ? roundMoney(valorTotal / numeroCuotas, 2) : 0.0;
    DateTime cursor = DateTime(
      fechaInicio.year,
      fechaInicio.month,
      fechaInicio.day,
    );
    int domingosOmitidos = 0;

    for (int cuota = 0; cuota < numeroCuotas; cuota++) {
      if (intervalo == 1 && omitirDomingos) {
        do {
          cursor = cursor.add(const Duration(days: 1));
          if (cursor.weekday == DateTime.sunday) {
            domingosOmitidos++;
          }
        } while (cursor.weekday == DateTime.sunday);
      } else {
        cursor = cursor.add(Duration(days: intervalo));
      }
    }

    return CalculoCredito(
      valorPrincipal: valorPrincipal,
      porcentajeInteres: porcentajeInteres,
      valorInteres: valorInteres,
      valorTotal: valorTotal,
      numeroCuotas: numeroCuotas,
      valorCuota: valorCuota,
      fechaMaxima: cursor,
      domingosOmitidos: domingosOmitidos,
    );
  }

  final double valorPrincipal;
  final double porcentajeInteres;
  final double valorInteres;
  final double valorTotal;
  final int numeroCuotas;
  final double valorCuota;
  final DateTime fechaMaxima;
  final int domingosOmitidos;
}
