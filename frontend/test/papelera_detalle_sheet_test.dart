import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/papelera/presentation/widgets/papelera_detalle_sheet.dart';
import 'package:cobro_app/features/papelera/presentation/widgets/papelera_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final PapeleraItem itemClientePrueba = PapeleraItem(
    id: 'pap-1',
    fecha: DateTime(2026, 10, 18, 14, 30),
    tipo: 'CLIENTE',
    motivo: 'Cliente inactivo por más de 6 meses',
    cliente: const PapeleraCliente(
      id: 'cli-101',
      nombreCompleto: 'Brain Root',
      documento: '1098234567',
      telefono: '3118901234',
      direccion: 'Carrera 7 # 45-20, Local 3',
      negocio: 'Tecnología & Accesorios',
    ),
    eliminadoPor: const PapeleraEliminadoPor(
      id: 'usr-1',
      usuario: 'admin_cobro',
      nombreCompleto: 'Admin Principal',
    ),
    ruta: const PapeleraRuta(
      id: 'rut-1',
      nombre: 'Ruta Norte',
    ),
  );

  final PapeleraItem itemCreditoPrueba = PapeleraItem(
    id: 'pap-2',
    fecha: DateTime(2026, 10, 19, 9, 15),
    tipo: 'CREDITO',
    motivo: 'Cancelación anticipada solicitada',
    cliente: const PapeleraCliente(
      id: 'cli-102',
      nombreCompleto: 'Lorena Gómez',
      documento: '52345678',
      telefono: '3157778899',
      direccion: 'Calle 12 # 4-50',
      negocio: 'Panadería La Espiga',
    ),
    credito: PapeleraCredito(
      id: 'cred-202',
      total: 1000000,
      totalPagar: 1200000,
      saldoPendiente: 450000,
      monedaCodigo: 'COP',
      frecuencia: 'DIARIO',
      tasaInteres: 20.0,
      fechaInicio: DateTime(2026, 9, 1),
      fechaFin: DateTime(2026, 10, 30),
    ),
    eliminadoPor: const PapeleraEliminadoPor(
      id: 'usr-2',
      usuario: 'supervisor_ruta',
      nombreCompleto: 'Laura Supervisora',
    ),
    ruta: const PapeleraRuta(
      id: 'rut-2',
      nombre: 'Ruta Centro',
    ),
  );

  Widget crearEntornoTest(Widget child) {
    return MaterialApp(
      theme: CobroAppTheme.light(),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets('PapeleraItemCard muestra datos y responde al toque de apertura', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    bool restaurado = false;
    bool eliminadoDef = false;

    await tester.pumpWidget(
      crearEntornoTest(
        PapeleraItemCard(
          item: itemClientePrueba,
          esAdministrador: true,
          onTap: () => tapped = true,
          onRestaurar: () => restaurado = true,
          onEliminarDefinitivo: () => eliminadoDef = true,
        ),
      ),
    );

    // Verificaciones visuales en la tarjeta
    expect(find.text('Brain Root'), findsOneWidget);
    expect(find.text('Tecnología & Accesorios'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('CC 1098234567'), findsOneWidget);
    expect(find.text('3118901234'), findsOneWidget);
    expect(find.text('Carrera 7 # 45-20, Local 3'), findsOneWidget);
    expect(find.text('Restaurar'), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);

    // Tap en la tarjeta completa
    await tester.tap(find.text('Brain Root'));
    await tester.pump();
    expect(tapped, isTrue);

    // Tap en botón restaurar
    await tester.tap(find.text('Restaurar'));
    await tester.pump();
    expect(restaurado, isTrue);

    // Tap en purgar
    await tester.tap(find.byIcon(Icons.delete_forever_rounded));
    await tester.pump();
    expect(eliminadoDef, isTrue);
  });

  testWidgets('PapeleraItemCard oculta botón purgar si no es administrador', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      crearEntornoTest(
        PapeleraItemCard(
          item: itemClientePrueba,
          esAdministrador: false,
          onRestaurar: () {},
          onEliminarDefinitivo: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.delete_forever_rounded), findsNothing);
  });

  testWidgets('PapeleraItemCard muestra banner de crédito suspendido si existe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      crearEntornoTest(
        PapeleraItemCard(
          item: itemCreditoPrueba,
          esAdministrador: true,
          onRestaurar: () {},
          onEliminarDefinitivo: () {},
        ),
      ),
    );

    expect(find.text('Lorena Gómez'), findsOneWidget);
    expect(find.text('Crédito'), findsOneWidget);
    expect(find.text('Crédito eliminado'), findsOneWidget);
    expect(find.textContaining('Monto:'), findsOneWidget);
    expect(find.textContaining('Saldo:'), findsOneWidget);
  });

  testWidgets('PapeleraItemCard no genera overflow en pantallas estrechas con todos los datos de contacto', (
    WidgetTester tester,
  ) async {
    final PapeleraItem itemLargo = PapeleraItem(
      id: 'pap-largo',
      fecha: DateTime(2026, 10, 20),
      tipo: 'CLIENTE',
      cliente: const PapeleraCliente(
        id: 'cli-999',
        nombreCompleto: 'Fernando Antonio De La Santisima Trinidad',
        documento: '109823456789',
        telefono: '311890123456',
        direccion: 'Avenida Principal Calle 100 con Carrera 50 Transversal 4',
        negocio: 'Supermercado y Variedades El Gran Manantial Central',
      ),
      eliminadoPor: const PapeleraEliminadoPor(
        id: 'usr-1',
        usuario: 'admin',
        nombreCompleto: 'Admin',
      ),
    );

    tester.view.physicalSize = const Size(280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      crearEntornoTest(
        PapeleraItemCard(
          item: itemLargo,
          esAdministrador: true,
          onRestaurar: () {},
          onEliminarDefinitivo: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('PapeleraDetalleSheet renderiza ficha completa y permite copiar datos', (
    WidgetTester tester,
  ) async {
    String copiadoEtiqueta = '';
    String copiadoValor = '';
    bool restaurado = false;
    bool purgado = false;

    await tester.pumpWidget(
      crearEntornoTest(
        PapeleraDetalleSheet(
          item: itemCreditoPrueba,
          esAdministrador: true,
          onRestaurar: () => restaurado = true,
          onEliminarDefinitivo: () => purgado = true,
          onCopiarDato: (String etiqueta, String valor) {
            copiadoEtiqueta = etiqueta;
            copiadoValor = valor;
          },
        ),
      ),
    );

    // Validar cabecera
    expect(find.text('Lorena Gómez'), findsOneWidget);
    expect(find.text('Crédito'), findsOneWidget);
    expect(find.text('CC 52345678'), findsOneWidget);

    // Validar auditoría
    expect(find.text('Registro de eliminación'), findsOneWidget);
    expect(find.text('Laura Supervisora'), findsOneWidget);
    expect(find.text('Ruta Centro'), findsOneWidget);

    // Validar copia de datos (Copia de documento o teléfono)
    final Finder copyDocFinder = find.byTooltip('Copiar Documento / Cédula');
    expect(copyDocFinder, findsOneWidget);
    await tester.ensureVisible(copyDocFinder);
    await tester.tap(copyDocFinder);
    await tester.pump();
    expect(copiadoEtiqueta, equals('Documento / Cédula'));
    expect(copiadoValor, equals('52345678'));

    // Botones de acción inferior
    final Finder btnRestaurar = find.widgetWithText(FilledButton, 'Restaurar');
    expect(btnRestaurar, findsOneWidget);
    await tester.ensureVisible(btnRestaurar);
    await tester.tap(btnRestaurar);
    await tester.pump();
    expect(restaurado, isTrue);

    final Finder btnPurgar = find.byTooltip('Purgar definitivamente');
    expect(btnPurgar, findsOneWidget);
    await tester.ensureVisible(btnPurgar);
    await tester.tap(btnPurgar);
    await tester.pump();
    expect(purgado, isTrue);
  });
}
