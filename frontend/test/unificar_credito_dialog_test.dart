import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/papelera/presentation/dialogs/unificar_credito_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final PapeleraItem itemPapeleraDiario = PapeleraItem(
    id: 'pap-1',
    fecha: DateTime(2026, 10, 10, 10),
    tipo: 'CREDITO',
    cliente: const PapeleraCliente(
      id: 'cli-1',
      nombreCompleto: 'ClienteCredito Test',
      documento: '1098765432',
    ),
    credito: const PapeleraCredito(
      id: 'cre-pap',
      total: 2000,
      totalPagar: 2400,
      saldoPendiente: 2400,
      monedaCodigo: 'USD',
      frecuencia: 'DIARIO',
      tasaInteres: 20,
    ),
    eliminadoPor: const PapeleraEliminadoPor(
      id: 'u-1',
      usuario: 'admin',
      nombreCompleto: 'Admin General',
    ),
  );

  final CreditoRegistro creditoActivoQuincenal =
      CreditoRegistro.fromJson(<String, dynamic>{
    'id': 'cre-act',
    'clienteId': 'cli-1',
    'cliente': 'ClienteCredito Test',
    'cedula': '1098765432',
    'rutaId': 'rut-1',
    'ruta': 'Ruta Centro',
    'monedaCodigo': 'USD',
    'frecuenciaPago': <String, dynamic>{
      'id': 2,
      'codigo': 'QUINCENAL',
      'nombre': 'Quincenal',
      'diasIntervalo': 15,
    },
    'estado': <String, dynamic>{
      'codigo': 'ACTIVO',
      'nombre': 'Activo',
    },
    'fechaInicio': '2026-10-01',
    'valorPrincipal': 1000,
    'porcentajeInteres': 20,
    'plazoDias': 30,
    'omitirDomingos': true,
    'valorTotal': 1200,
    'valorCuota': 600,
    'totalAbonado': 0,
    'saldo': 1200,
    'numeroCuotas': 2,
    'cuotasRestantes': 2,
    'fechaMaxima': '2026-10-31',
  });

  final CreditoRegistro creditoActivoDiario =
      CreditoRegistro.fromJson(<String, dynamic>{
    'id': 'cre-act-2',
    'clienteId': 'cli-1',
    'cliente': 'ClienteCredito Test',
    'cedula': '1098765432',
    'rutaId': 'rut-1',
    'ruta': 'Ruta Centro',
    'monedaCodigo': 'USD',
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
    'valorPrincipal': 1000,
    'porcentajeInteres': 20,
    'plazoDias': 30,
    'omitirDomingos': true,
    'valorTotal': 1200,
    'valorCuota': 40,
    'totalAbonado': 0,
    'saldo': 1200,
    'numeroCuotas': 30,
    'cuotasRestantes': 30,
    'fechaMaxima': '2026-10-31',
  });

  testWidgets(
      'muestra selector de frecuencia solo si difieren y no muestra mensaje de Opcion B',
      (WidgetTester tester) async {
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
                    item: itemPapeleraDiario,
                    creditoActivo: creditoActivoQuincenal,
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
    expect(find.text('ClienteCredito Test'), findsOneWidget);
    expect(find.text('Crédito Activo Actual'), findsOneWidget);
    expect(find.text('Deuda en Papelera'), findsOneWidget);
    expect(find.text('Nuevo Total Consolidado'), findsOneWidget);

    // Suma: 1.000 + 2.400 = 3.400
    expect(find.text(r'$3.400'), findsOneWidget);

    // Como creditoActivo es QUINCENAL y papelera es DIARIO, debe salir el selector
    expect(find.text('Frecuencia de cobro resultante:'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);

    // Las opciones deben ser Quincenal y Diario (no Semanal ni opciones arbitrarias)
    expect(find.text('Quincenal'), findsOneWidget);
    expect(find.text('Diario'), findsOneWidget);
    expect(find.text('Semanal'), findsNothing);

    // No debe existir ningún texto con "Opción B"
    expect(find.textContaining('Opción B'), findsNothing);
    expect(find.textContaining('Opcion B'), findsNothing);

    // Cambiar a Diario
    await tester.tap(find.text('Diario'));
    await tester.pumpAndSettle();

    // Confirmar
    await tester.tap(find.text('Unificar y Restaurar'));
    await tester.pumpAndSettle();

    expect(frecuenciaConfirmada, 'DIARIO');
  });

  testWidgets(
      'oculta el selector de frecuencia cuando ambas frecuencias son iguales',
      (WidgetTester tester) async {
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
                    item: itemPapeleraDiario,
                    creditoActivo: creditoActivoDiario,
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

    // Como ambos son DIARIO, NO debe salir el selector
    expect(find.text('Frecuencia de cobro resultante:'), findsNothing);
    expect(find.byType(SegmentedButton<String>), findsNothing);

    // Confirmar unificación directa
    await tester.tap(find.text('Unificar y Restaurar'));
    await tester.pumpAndSettle();

    expect(frecuenciaConfirmada, 'DIARIO');
  });

  testWidgets('cancela la unificacion sin ejecutar callback',
      (WidgetTester tester) async {
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
                    item: itemPapeleraDiario,
                    creditoActivo: creditoActivoQuincenal,
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
