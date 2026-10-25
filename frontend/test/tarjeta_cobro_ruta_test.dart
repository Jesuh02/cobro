import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/rutas/presentation/widgets/tarjeta_cobro_ruta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final CobroRuta cobroPrueba = CobroRuta(
    id: 'cobro-101',
    clienteId: 'cli-101',
    cliente: 'Jesus Navarroz',
    cedula: '111222333555',
    rutaId: 'ruta-1',
    ruta: 'Ruta Pedro',
    negocio: 'Tienda Central',
    valorTotal: 3600,
    valorCuota: 102.86,
    totalAbonado: 102.85,
    saldo: 3497.15,
    numeroCuotas: 35,
    cuotasRestantes: 34,
    estadoCobro: EstadoCobro.atrasado,
    proximoSaldoCuota: 102.86,
    proximaCuotaId: 'cuota-34',
    proximaNumeroCuota: 2,
    proximaFechaPago: DateTime(2026, 10, 24),
  );

  Widget crearEntornoTest(Widget child) {
    return MaterialApp(
      theme: CobroAppTheme.light(),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets(
      'TarjetaCobroRuta es compacta, muestra 4 métricas, no incluye Guardar casa y responde a Registrar pago',
      (WidgetTester tester) async {
    bool pagoRegistrado = false;

    await tester.pumpWidget(
      crearEntornoTest(
        TarjetaCobroRuta(
          cobro: cobroPrueba,
          pagoEnProceso: false,
          pagoAplicadoInstantaneo: false,
          onRegistrarPago: () => pagoRegistrado = true,
        ),
      ),
    );

    // Cliente y estado
    expect(find.text('Jesus Navarroz'), findsOneWidget);
    expect(find.textContaining('111222333555'), findsOneWidget);
    expect(find.textContaining('Ruta Pedro'), findsOneWidget);
    expect(find.text('Atrasado'), findsOneWidget);

    // 4 Métricas clave
    expect(find.text('Cuota'), findsOneWidget);
    expect(find.text('Saldo'), findsOneWidget);
    expect(find.text('Restantes'), findsOneWidget);
    expect(find.text('34 / 35'), findsOneWidget);
    expect(find.text('Próxima'), findsOneWidget);

    // NO debe existir botón "Guardar casa" ni texto repetido de abonado
    expect(find.text('Guardar casa'), findsNothing);
    expect(find.text('Actualizar casa'), findsNothing);
    expect(find.textContaining('abonado de'), findsNothing);

    // Botón de pago
    final Finder botonPago = find.text('Registrar pago');
    expect(botonPago, findsOneWidget);
    await tester.tap(botonPago);
    expect(pagoRegistrado, isTrue);
  });
}
