import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/caja_menor/presentation/widgets/filtros_caja_menor.dart';
import 'package:cobro_app/features/caja_menor/presentation/widgets/movimiento_caja_item.dart';
import 'package:cobro_app/features/caja_menor/presentation/widgets/movimiento_detalle_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final MovimientoCaja movimientoPrueba = MovimientoCaja(
    id: 'mov-100',
    cajaMenorId: 'caja-1',
    cajaMenor: 'Caja Principal Centro',
    tipoMovimiento: const TipoMovimientoCaja(
      codigo: 'PAGO',
      nombre: 'Recaudo de cuota',
      naturaleza: 'E',
    ),
    fechaMovimiento: DateTime(2026, 10, 15, 11, 42),
    monto: 50000,
    montoConNaturaleza: 50000,
    motivo: 'Pago cuota 3/20 credito diario',
    cliente: 'Lumian Lee',
    clienteIdentificacion: '111222333445',
    usuario: const UsuarioCatalogo(
      id: 'usr-1',
      nombreCompleto: 'Carlos Cobrador',
      usuario: 'carlos',
    ),
    referenciaTabla: 'pago',
    referenciaId: 'pago-777',
  );

  Widget crearEntornoTest(Widget child) {
    return MaterialApp(
      theme: CobroAppTheme.light(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('es', 'CO'),
        Locale('es'),
      ],
      locale: const Locale('es', 'CO'),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets('FiltrosCajaMenor renderiza SegmentedButton con Entradas y Salidas en una sola linea', (
    WidgetTester tester,
  ) async {
    FiltroMovimientoCaja filtroSeleccionado = FiltroMovimientoCaja.todos;

    await tester.pumpWidget(
      crearEntornoTest(
        FiltrosCajaMenor(
          cajas: const <CajaMenorCatalogo>[],
          cajaMenorFiltroId: null,
          onCajaChanged: (_) {},
          filtroMovimientoCaja: filtroSeleccionado,
          onFiltroMovimientoCajaChanged: (FiltroMovimientoCaja v) {
            filtroSeleccionado = v;
          },
          fechaCajaDesde: null,
          fechaCajaHasta: null,
          onSeleccionarFechaDesde: () {},
          onSeleccionarFechaHasta: () {},
          exportando: false,
          onExportar: () {},
          hayFiltrosCaja: false,
          onLimpiarFiltros: () {},
        ),
      ),
    );

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Entradas'), findsOneWidget);
    expect(find.text('Salidas'), findsOneWidget);

    await tester.tap(find.text('Entradas'));
    await tester.pump();
    expect(filtroSeleccionado, equals(FiltroMovimientoCaja.entradas));
  });

  testWidgets('FiltrosCajaMenor muestra boton unificado de rango de fechas y dispara callback', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool rangoTapped = false;
    bool exportTapped = false;
    bool limpiarTapped = false;

    await tester.pumpWidget(
      crearEntornoTest(
        FiltrosCajaMenor(
          cajas: const <CajaMenorCatalogo>[],
          cajaMenorFiltroId: null,
          onCajaChanged: (_) {},
          filtroMovimientoCaja: FiltroMovimientoCaja.todos,
          onFiltroMovimientoCajaChanged: (_) {},
          fechaCajaDesde: null,
          fechaCajaHasta: null,
          onSeleccionarRangoFechas: () => rangoTapped = true,
          exportando: false,
          onExportar: () => exportTapped = true,
          hayFiltrosCaja: true,
          onLimpiarFiltros: () => limpiarTapped = true,
        ),
      ),
    );

    // Debe mostrar 'Fechas' cuando no hay rango seleccionado
    expect(find.text('Fechas'), findsOneWidget);
    await tester.tap(find.text('Fechas'));
    await tester.pump();
    expect(rangoTapped, isTrue);

    // Exportar
    final Finder exportFinder = find.byTooltip('Exportar reporte');
    expect(exportFinder, findsOneWidget);
    await tester.tap(exportFinder);
    await tester.pump();
    expect(exportTapped, isTrue);

    // Limpiar filtros
    final Finder limpiarFinder = find.byTooltip('Limpiar filtros');
    expect(limpiarFinder, findsOneWidget);
    await tester.tap(limpiarFinder);
    await tester.pump();
    expect(limpiarTapped, isTrue);
  });

  testWidgets('FiltrosCajaMenor formatea correctamente etiqueta con rango activo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      crearEntornoTest(
        FiltrosCajaMenor(
          cajas: const <CajaMenorCatalogo>[],
          cajaMenorFiltroId: null,
          onCajaChanged: (_) {},
          filtroMovimientoCaja: FiltroMovimientoCaja.entradas,
          onFiltroMovimientoCajaChanged: (_) {},
          fechaCajaDesde: DateTime(2026, 10, 15),
          fechaCajaHasta: DateTime(2026, 10, 24),
          onSeleccionarRangoFechas: () {},
          exportando: false,
          onExportar: () {},
          hayFiltrosCaja: true,
          onLimpiarFiltros: () {},
        ),
      ),
    );

    expect(find.textContaining('15 oct'), findsOneWidget);
    expect(find.textContaining('24 oct'), findsOneWidget);
  });

  testWidgets('MovimientoCajaItem muestra datos formateados y responde al toque', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    bool modificado = false;

    await tester.pumpWidget(
      crearEntornoTest(
        MovimientoCajaItem(
          movimiento: movimientoPrueba,
          puedeModificar: true,
          onTap: () => tapped = true,
          onModificar: () => modificado = true,
        ),
      ),
    );

    expect(find.text('Pago cuota 3/20 credito diario'), findsOneWidget);
    expect(find.text('Lumian Lee (CC 111222333445)'), findsOneWidget);
    expect(find.textContaining('Caja Principal Centro'), findsOneWidget);

    await tester.tap(find.text('Pago cuota 3/20 credito diario'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(modificado, isFalse);
  });

  testWidgets('MovimientoDetalleSheet despliega informacion contable, cliente y permite copiar', (
    WidgetTester tester,
  ) async {
    bool modificado = false;
    String? datoCopiado;

    await tester.pumpWidget(
      crearEntornoTest(
        MovimientoDetalleSheet(
          movimiento: movimientoPrueba,
          puedeModificar: true,
          onModificar: () => modificado = true,
          onCopiarDato: (String etiqueta, String valor) {
            datoCopiado = '$etiqueta: $valor';
          },
        ),
      ),
    );

    expect(find.text('Entrada de caja'), findsOneWidget);
    expect(find.text('Recaudo de cuota'), findsOneWidget); // Badge de cabecera
    expect(find.text('Pago cuota 3/20 credito diario'), findsOneWidget);
    expect(find.text('Caja Principal Centro'), findsOneWidget);
    expect(find.text('Carlos Cobrador'), findsOneWidget);
    expect(find.text('Lumian Lee'), findsOneWidget);
    expect(find.text('CC 111222333445'), findsOneWidget);

    // Copiar documento de cliente
    final Finder botonCopiarDocumento = find.byTooltip('Copiar Documento / Cédula');
    expect(botonCopiarDocumento, findsOneWidget);
    await tester.ensureVisible(botonCopiarDocumento);
    await tester.tap(botonCopiarDocumento);
    await tester.pump();
    expect(datoCopiado, equals('Documento / Cédula: 111222333445'));

    // Modificar
    final Finder botonModificar = find.widgetWithText(FilledButton, 'Modificar');
    expect(botonModificar, findsOneWidget);
    await tester.ensureVisible(botonModificar);
    await tester.tap(botonModificar);
    await tester.pump();
    expect(modificado, isTrue);
  });

  test('MovimientoCaja.icono mapea correctamente segun la naturaleza y contexto', () {
    MovimientoCaja crear({
      required String codigo,
      required String nombre,
      required String naturaleza,
      String motivo = 'Operacion de prueba',
      String? referenciaTabla,
    }) {
      return MovimientoCaja(
        id: '1',
        cajaMenorId: 'caja-1',
        cajaMenor: 'Caja 1',
        tipoMovimiento: TipoMovimientoCaja(
          codigo: codigo,
          nombre: nombre,
          naturaleza: naturaleza,
        ),
        fechaMovimiento: DateTime(2026, 10, 25),
        monto: 10000,
        montoConNaturaleza: naturaleza == 'S' ? -10000 : 10000,
        motivo: motivo,
        referenciaTabla: referenciaTabla,
      );
    }

    // 1. Apertura
    expect(
      crear(codigo: 'APERTURA', nombre: 'Apertura', naturaleza: 'E', motivo: 'Apertura de caja').icono,
      equals(Icons.lock_open_rounded),
    );

    // 2. Desembolso Credito
    expect(
      crear(codigo: 'DESEMBOLSO_CREDITO', nombre: 'Desembolso de credito', naturaleza: 'S', motivo: 'Desembolso Credito').icono,
      equals(Icons.request_quote_rounded),
    );

    // 3. Recaudo / Pago
    expect(
      crear(codigo: 'RECAUDO', nombre: 'Recaudo', naturaleza: 'E', motivo: 'Pago cuota', referenciaTabla: 'pago').icono,
      equals(Icons.payments_rounded),
    );

    // 4. Gasto
    expect(
      crear(codigo: 'GASTO', nombre: 'Gasto', naturaleza: 'S', motivo: 'Gasto transporte').icono,
      equals(Icons.receipt_long_rounded),
    );

    // 5. Ajustes
    expect(
      crear(codigo: 'AJUSTE_ENTRADA', nombre: 'Ajuste de entrada', naturaleza: 'E').icono,
      equals(Icons.add_circle_outline_rounded),
    );
    expect(
      crear(codigo: 'AJUSTE_SALIDA', nombre: 'Ajuste de salida', naturaleza: 'S').icono,
      equals(Icons.remove_circle_outline_rounded),
    );

    // 6. Cierre
    expect(
      crear(codigo: 'CIERRE', nombre: 'Cierre', naturaleza: 'N', motivo: 'Cierre de caja').icono,
      equals(Icons.lock_clock_rounded),
    );

    // 7. Auditoria
    expect(
      crear(codigo: 'AUDITORIA', nombre: 'Auditoria', naturaleza: 'N', referenciaTabla: 'auditoria_caja_menor').icono,
      equals(Icons.history_rounded),
    );
  });

  testWidgets('MovimientoCajaItem renderiza icono de candado abierto para Apertura y request_quote para Desembolso', (
    WidgetTester tester,
  ) async {
    final MovimientoCaja apertura = MovimientoCaja(
      id: 'ap-1',
      cajaMenorId: 'caja-1',
      cajaMenor: 'Caja Principal',
      tipoMovimiento: const TipoMovimientoCaja(codigo: 'APERTURA', nombre: 'Apertura', naturaleza: 'E'),
      fechaMovimiento: DateTime(2026, 10, 24),
      monto: 10000,
      montoConNaturaleza: 10000,
      motivo: 'Apertura',
    );

    final MovimientoCaja desembolso = MovimientoCaja(
      id: 'des-1',
      cajaMenorId: 'caja-1',
      cajaMenor: 'Caja Principal',
      tipoMovimiento: const TipoMovimientoCaja(codigo: 'DESEMBOLSO_CREDITO', nombre: 'Desembolso de credito', naturaleza: 'S'),
      fechaMovimiento: DateTime(2026, 10, 23),
      monto: 100,
      montoConNaturaleza: -100,
      motivo: 'Desembolso Credito',
      referenciaTabla: 'credito_desembolso',
    );

    await tester.pumpWidget(
      crearEntornoTest(
        Column(
          children: [
            MovimientoCajaItem(movimiento: apertura, puedeModificar: false, onTap: () {}, onModificar: () {}),
            MovimientoCajaItem(movimiento: desembolso, puedeModificar: false, onTap: () {}, onModificar: () {}),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    expect(find.byIcon(Icons.request_quote_rounded), findsOneWidget);
  });
}
