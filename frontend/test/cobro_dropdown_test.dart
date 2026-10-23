import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/core/ui/cobro_dropdown.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:cobro_app/features/rutas/presentation/widgets/selector_medio_pago_buscable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget crearEntornoTest(Widget child, {Size tamano = const Size(360, 640)}) {
    return MaterialApp(
      theme: CobroAppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: tamano.width,
            height: tamano.height,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('CobroDropdownField adopta exactamente el ancho del campo cuando menuWidth es null', (
    WidgetTester tester,
  ) async {
    String? seleccionado = '1';
    final List<CobroDropdownItem<String>> items = <CobroDropdownItem<String>>[
      const CobroDropdownItem<String>(
        value: '1',
        label: 'Apertura',
        subtitle: 'Entrada de dinero a caja',
        icon: Icons.arrow_downward_rounded,
      ),
      const CobroDropdownItem<String>(
        value: '2',
        label: 'Desembolso de credito',
        subtitle: 'Salida de dinero de caja por prestamo',
        icon: Icons.arrow_upward_rounded,
      ),
    ];

    const double anchoContenedor = 260.0;

    await tester.pumpWidget(
      crearEntornoTest(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setTestState) {
            return Center(
              child: SizedBox(
                width: anchoContenedor,
                child: CobroDropdownField<String>(
                  labelText: 'Tipo de movimiento',
                  value: seleccionado,
                  items: items,
                  onChanged: (String? val) {
                    setTestState(() => seleccionado = val);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    // Inicialmente no está abierto el menú desplegable
    expect(find.text('Desembolso de credito'), findsNothing);

    // Tocar el campo para abrir
    await tester.tap(find.text('Apertura'));
    await tester.pumpAndSettle();

    // El menú ahora debe ser visible
    expect(find.text('Desembolso de credito'), findsOneWidget);

    // Buscar el RenderBox del menú desplegable dentro del Overlay
    final Finder materialMenus = find.byType(Material);
    // El último Material corresponde al menú del OverlayPortal
    final RenderBox menuRenderBox =
        tester.renderObject(materialMenus.last) as RenderBox;

    // Verificar que el ancho del menú coincida exactamente con el ancho del campo (260 px)
    expect(menuRenderBox.size.width, equals(anchoContenedor));

    // Seleccionar segundo item
    await tester.tap(find.text('Desembolso de credito'));
    await tester.pumpAndSettle();

    expect(seleccionado, equals('2'));
    expect(find.text('Desembolso de credito'), findsOneWidget);
  });

  testWidgets('SelectorMedioPagoBuscable no se desborda y respeta el ancho del diálogo', (
    WidgetTester tester,
  ) async {
    String medioSeleccionado = 'EFECTIVO';
    final List<MedioPago> medios = <MedioPago>[
      const MedioPago(codigo: 'EFECTIVO', nombre: 'Efectivo'),
      const MedioPago(codigo: 'TRANSFERENCIA', nombre: 'Transferencia'),
      const MedioPago(codigo: 'TARJETA', nombre: 'Tarjeta'),
      const MedioPago(codigo: 'BILLETERA', nombre: 'Billetera'),
    ];

    const double anchoDialogo = 280.0;

    await tester.pumpWidget(
      crearEntornoTest(
        Center(
          child: SizedBox(
            width: anchoDialogo,
            child: SelectorMedioPagoBuscable(
              mediosPago: medios,
              medioPagoCodigo: medioSeleccionado,
              enabled: true,
              onChanged: (String val) => medioSeleccionado = val,
            ),
          ),
        ),
      ),
    );

    // Abrir selector
    await tester.tap(find.text('Efectivo'));
    await tester.pumpAndSettle();

    // Validar opciones visibles
    expect(find.text('Transferencia'), findsOneWidget);
    expect(find.text('Tarjeta'), findsOneWidget);
    expect(find.text('Billetera'), findsOneWidget);

    // Obtener tamaño del menú en el Overlay
    final Finder materialMenus = find.byType(Material);
    final RenderBox menuRenderBox =
        tester.renderObject(materialMenus.last) as RenderBox;

    // El menú debe coincidir exactamente con los 280 px del campo y no sobrepasar
    expect(menuRenderBox.size.width, equals(anchoDialogo));

    // Seleccionar Billetera
    await tester.tap(find.text('Billetera'));
    await tester.pumpAndSettle();

    expect(medioSeleccionado, equals('BILLETERA'));
  });

  testWidgets('CobroDropdownField se abre hacia arriba cuando el espacio inferior es reducido', (
    WidgetTester tester,
  ) async {
    final List<CobroDropdownItem<String>> items = <CobroDropdownItem<String>>[
      const CobroDropdownItem<String>(value: 'A', label: 'Opción A'),
      const CobroDropdownItem<String>(value: 'B', label: 'Opción B'),
    ];

    // Colocar el campo en la parte inferior de una pantalla de 600 px (por ejemplo a y = 520)
    await tester.pumpWidget(
      MaterialApp(
        theme: CobroAppTheme.light(),
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(
                left: 20,
                bottom: 20,
                width: 300,
                child: CobroDropdownField<String>(
                  labelText: 'Campo inferior',
                  value: 'A',
                  items: items,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Tocar el campo
    await tester.tap(find.text('Opción A'));
    await tester.pumpAndSettle();

    expect(find.text('Opción B'), findsOneWidget);

    // Posición del menú desplegado
    final Finder materialMenus = find.byType(Material);
    final RenderBox menuBox =
        tester.renderObject(materialMenus.last) as RenderBox;
    final Offset menuPos = menuBox.localToGlobal(Offset.zero);

    // Posición del campo
    final Finder fieldFinder = find.byType(InputDecorator);
    final RenderBox fieldBox =
        tester.renderObject(fieldFinder) as RenderBox;
    final Offset fieldPos = fieldBox.localToGlobal(Offset.zero);

    // Dado que se encuentra al fondo, el menú debe desplegarse ARRIBA del campo (menuPos.dy < fieldPos.dy)
    expect(menuPos.dy, lessThan(fieldPos.dy));
  });
}
