import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/caja_menor/presentation/widgets/filtros_caja_menor.dart';
import 'package:cobro_app/features/caja_menor/presentation/widgets/movimiento_caja_item.dart';
import 'package:cobro_app/features/caja_menor/presentation/widgets/movimiento_detalle_sheet.dart';
import 'package:flutter/material.dart';
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
}
