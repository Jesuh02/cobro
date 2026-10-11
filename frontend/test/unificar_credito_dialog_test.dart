import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/papelera/presentation/dialogs/unificar_credito_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final PapeleraItem itemTest = PapeleraItem(
    id: 'pap-1',
    fecha: DateTime(2026, 10, 10, 10),
    tipo: 'CREDITO',
    cliente: const PapeleraCliente(
      id: 'cli-1',
      nombreCompleto: 'Juan Carlos Gomez',
      documento: '1098765432',
    ),
    credito: const PapeleraCredito(
      id: 'cre-pap',
      total: 200000,
      totalPagar: 240000,
      saldoPendiente: 150000,
      monedaCodigo: 'COP',
      frecuencia: 'DIARIO',
      tasaInteres: 20,
    ),
    eliminadoPor: const PapeleraEliminadoPor(
      id: 'u-1',
      usuario: 'admin',
      nombreCompleto: 'Admin General',
    ),
  );

  final CreditoRegistro creditoActivoTest = CreditoRegistro.fromJson(<String, dynamic>{
    'id': 'cre-act',
    'clienteId': 'cli-1',
    'cliente': 'Juan Carlos Gomez',
    'cedula': '1098765432',
    'rutaId': 'rut-1',
    'ruta': 'Ruta Centro',
    'monedaCodigo': 'COP',
    'frecuenciaPago': <String, dynamic>{
      'id': 1,
      'codigo': 'DIARIO',
      'nombre': 'Diario',
      'diasIntervalo': 1,
    },
    'estado': <String, dynamic>{
      'codigo': 'ACTIVO',
      'nombre': 'Activo',
    },
    'fechaInicio': '2026-10-01',
    'valorPrincipal': 100000,
    'porcentajeInteres': 20,
    'plazoDias': 30,
    'omitirDomingos': true,
    'valorTotal': 120000,
    'valorCuota': 4000,
    'totalAbonado': 0,
    'saldo': 120000,
    'numeroCuotas': 30,
    'cuotasRestantes': 30,
    'fechaMaxima': '2026-10-31',
  });

  testWidgets('muestra desglose financiero y selector de frecuencia', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    String? frecuenciaConfirmada;

    await tester.pumpWidget(
      MaterialApp(
        theme: CobroAppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  mostrarDialogoUnificarCreditoPapelera(
                    context: context,
                    item: itemTest,
                    creditoActivo: creditoActivoTest,
                    onConfirmarUnificar: (String f) async {
                      frecuenciaConfirmada = f;
                    },
                  );
                },
                child: const Text('Abrir'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Unificar y Refinanciar'), findsOneWidget);
    expect(find.text('Juan Carlos Gomez'), findsOneWidget);
    expect(find.text('Crédito Activo Actual'), findsOneWidget);
    expect(find.text('Deuda en Papelera'), findsOneWidget);
    expect(find.text('Nuevo Total Consolidado'), findsOneWidget);

    // Suma: 100.000 + 150.000 = 250.000
    expect(find.text(r'$250.000'), findsOneWidget);

    // Selector Diario / Semanal
    expect(find.text('Diario'), findsOneWidget);
    expect(find.text('Semanal'), findsOneWidget);

    // Cambiar a Semanal
    await tester.tap(find.text('Semanal'));
    await tester.pumpAndSettle();

    // Confirmar
    await tester.tap(find.text('Unificar y Restaurar'));
    await tester.pumpAndSettle();

    expect(frecuenciaConfirmada, 'SEMANAL');
  });

  testWidgets('cancela la unificacion sin ejecutar callback', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    bool callbackEjecutado = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: CobroAppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  mostrarDialogoUnificarCreditoPapelera(
                    context: context,
                    item: itemTest,
                    creditoActivo: creditoActivoTest,
                    onConfirmarUnificar: (String _) async {
                      callbackEjecutado = true;
                    },
                  );
                },
                child: const Text('Abrir'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(callbackEjecutado, false);
    expect(find.text('Unificar y Refinanciar'), findsNothing);
  });
}
