import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/rutas/presentation/dialogs/pago_ruta_dialogs.dart';
import 'package:cobro_app/features/rutas/presentation/widgets/selector_medio_pago_buscable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final CobroRuta cobroEjemplo = CobroRuta(
    id: 'cobro-1',
    clienteId: 'cli-1',
    cliente: 'Carlos Cobro',
    cedula: '1234567890',
    rutaId: 'ruta-1',
    ruta: 'Ruta Principal',
    valorTotal: 120000,
    valorCuota: 20000,
    totalAbonado: 20000,
    saldo: 100000,
    numeroCuotas: 6,
    cuotasRestantes: 5,
    estadoCobro: EstadoCobro.alDia,
    proximoSaldoCuota: 20000,
    proximaCuotaId: 'cuota-1',
    proximaNumeroCuota: 2,
    proximaFechaPago: DateTime(2026, 10, 20),
  );

  final List<MedioPago> mediosPago = const <MedioPago>[
    MedioPago(codigo: 'EFECTIVO', nombre: 'Efectivo'),
    MedioPago(codigo: 'TRANSFERENCIA', nombre: 'Transferencia'),
  ];

  final CajaMenorCatalogo cajaPrincipal = CajaMenorCatalogo(
    id: 'caja-1',
    nombre: 'Caja Principal',
    activa: true,
    monedaCodigo: 'COP',
    fechaApertura: DateTime(2026, 10, 18, 8),
    fechaCierre: DateTime(2026, 10, 18, 20),
  );

  final CajaMenorCatalogo cajaSecundaria = CajaMenorCatalogo(
    id: 'caja-2',
    nombre: 'Caja Auxiliar',
    activa: true,
    monedaCodigo: 'COP',
    fechaApertura: DateTime(2026, 10, 18, 9),
    fechaCierre: DateTime(2026, 10, 18, 20),
  );

  Widget testApp({required Widget child}) {
    return MaterialApp(
      theme: CobroAppTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('no abre dialogo y muestra mensaje si no hay caja menor activa',
      (WidgetTester tester) async {
    String? mensajeMostrado;

    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () {
              mostrarDialogoRegistrarPago(
                context: context,
                cobro: cobroEjemplo,
                puedeAgregarCuota: true,
                mediosPago: mediosPago,
                cajasMenores: const <CajaMenorCatalogo>[],
                cobrosRuta: <CobroRuta>[cobroEjemplo],
                cuotasEnPago: const <String>{},
                rutaFiltroId: null,
                mostrarMensaje: (String msg) => mensajeMostrado = msg,
                mensajeError: (Object e) => e.toString(),
                onRegistrarPagos: (List<PagoRutaSolicitud> p) async {},
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(mensajeMostrado, 'No tienes una caja menor activa para registrar pagos');
    expect(find.byType(PagoRutaSheet), findsNothing);
  });

  testWidgets('muestra caja activa y asocia cajaMenorId en la solicitud de pago',
      (WidgetTester tester) async {
    List<PagoRutaSolicitud>? pagosRegistrados;

    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () {
              mostrarDialogoRegistrarPago(
                context: context,
                cobro: cobroEjemplo,
                puedeAgregarCuota: true,
                mediosPago: mediosPago,
                cajasMenores: <CajaMenorCatalogo>[cajaPrincipal],
                cobrosRuta: <CobroRuta>[cobroEjemplo],
                cuotasEnPago: const <String>{},
                rutaFiltroId: null,
                mostrarMensaje: (_) {},
                mensajeError: (Object e) => e.toString(),
                onRegistrarPagos: (List<PagoRutaSolicitud> p) async {
                  pagosRegistrados = p;
                },
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(PagoRutaSheet), findsOneWidget);
    expect(find.text('Caja Principal'), findsOneWidget);
    expect(find.text('Abierta'), findsOneWidget);

    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(pagosRegistrados, isNotNull);
    expect(pagosRegistrados!.length, 1);
    expect(pagosRegistrados!.first.cuotaId, 'cuota-1');
    expect(pagosRegistrados!.first.cajaMenorId, 'caja-1');
  });

  testWidgets('muestra selector desplegable si hay multiples cajas activas',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () {
              mostrarDialogoRegistrarPago(
                context: context,
                cobro: cobroEjemplo,
                puedeAgregarCuota: true,
                mediosPago: mediosPago,
                cajasMenores: <CajaMenorCatalogo>[cajaPrincipal, cajaSecundaria],
                cobrosRuta: <CobroRuta>[cobroEjemplo],
                cuotasEnPago: const <String>{},
                rutaFiltroId: null,
                mostrarMensaje: (_) {},
                mensajeError: (Object e) => e.toString(),
                onRegistrarPagos: (_) async {},
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(PagoRutaSheet), findsOneWidget);
    expect(find.text('Caja menor destino'), findsOneWidget);
    expect(find.text('Caja Principal'), findsOneWidget);
  });

  testWidgets(
      'muestra ruta debajo de la cedula, permite cerrar el buscador de clientes y muestra Medio de pagos y detalles',
      (WidgetTester tester) async {
    final CobroRuta otroCobro = CobroRuta(
      id: 'cobro-2',
      clienteId: 'cli-2',
      cliente: 'Maria Gomez',
      cedula: '987654321',
      rutaId: 'ruta-1',
      ruta: 'Ruta Principal',
      valorTotal: 50000,
      valorCuota: 10000,
      totalAbonado: 0,
      saldo: 50000,
      numeroCuotas: 5,
      cuotasRestantes: 5,
      estadoCobro: EstadoCobro.alDia,
      proximoSaldoCuota: 10000,
      proximaCuotaId: 'cuota-2',
      proximaNumeroCuota: 1,
      proximaFechaPago: DateTime(2026, 10, 21),
    );

    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () {
              mostrarDialogoRegistrarPago(
                context: context,
                cobro: cobroEjemplo,
                puedeAgregarCuota: true,
                mediosPago: mediosPago,
                cajasMenores: <CajaMenorCatalogo>[cajaPrincipal],
                cobrosRuta: <CobroRuta>[cobroEjemplo, otroCobro],
                cuotasEnPago: const <String>{},
                rutaFiltroId: null,
                mostrarMensaje: (_) {},
                mensajeError: (Object e) => e.toString(),
                onRegistrarPagos: (_) async {},
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // 1. Cédula y ruta visualizadas
    expect(find.text('CC 1234567890'), findsOneWidget);
    expect(find.text('Ruta Principal'), findsOneWidget);

    // Botón rápido de Cuota sí existe, pero Liquidar fue eliminado
    expect(find.textContaining('Cuota:'), findsWidgets);
    expect(find.textContaining('Liquidar'), findsNothing);

    // 3. Título de sección "Medio de pagos y detalles" sin etiqueta duplicada "Medio de pago"
    expect(find.text('Medio de pagos y detalles'), findsOneWidget);
    expect(find.text('Medio de pago'), findsNothing);

    // 2. Abrir selector de clientes y cerrarlo sin añadir usando únicamente el botón de la esquina
    expect(find.text('Agregar otro cobro a este recibo'), findsOneWidget);
    await tester.tap(find.text('Agregar otro cobro a este recibo'));
    await tester.pumpAndSettle();

    // El buscador ahora es visible con su botón Cerrar en la esquina superior
    expect(find.text('Maria Gomez'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);

    // Cerrar el selector con el botón Cerrar de la esquina
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    // Se cerró la lista y vuelve a mostrar el botón para agregar
    expect(find.text('Agregar otro cobro a este recibo'), findsOneWidget);
    expect(find.text('Maria Gomez'), findsNothing);
  });
}
