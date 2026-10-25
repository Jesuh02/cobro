import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/core/ui/page_layout.dart';
import 'package:cobro_app/features/caja_menor/presentation/caja_menor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget crearEntornoTest({
    required Widget child,
    Size tamanio = const Size(360, 780),
  }) {
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
      home: MediaQuery(
        data: MediaQueryData(size: tamanio),
        child: SizedBox(
          width: tamanio.width,
          height: tamanio.height,
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  testWidgets(
    'CajaMenorView acomoda 3 botones en 2 filas organizadas en movil cuando es admin o tiene permiso',
    (WidgetTester tester) async {
      bool cerrarPresionado = false;
      bool nuevaPresionado = false;
      bool movimientoPresionado = false;

      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        crearEntornoTest(
          tamanio: const Size(360, 780),
          child: CajaMenorView(
            movimientos: const [],
            hayCajaMenor: true,
            mostrandoCargaMovimientosCaja: false,
            cargandoMasMovimientosCaja: false,
            puedeCrearCajaMenor: true,
            puedeRegistrarFlujoCaja: true,
            puedeModificarMovimientos: true,
            puedeModificarCreditos: true,
            puedeEliminarCreditos: true,
            esAdministrador: false,
            guardando: false,
            onRefresh: () async {},
            onNearEnd: () {},
            onCerrarCajaMenor: () => cerrarPresionado = true,
            onCrearCajaMenor: () => nuevaPresionado = true,
            onMovimientoCaja: () => movimientoPresionado = true,
            onModificarMovimiento: (_) {},
            mostrarMensaje: (_, {bool esError = false}) {},
            buscarController: TextEditingController(),
            filtros: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder encabezado = find.byType(Encabezado);
      final Finder btnCerrar = find.descendant(
        of: encabezado,
        matching: find.widgetWithText(OutlinedButton, 'Cerrar caja'),
      );
      final Finder btnNueva = find.descendant(
        of: encabezado,
        matching: find.widgetWithText(OutlinedButton, 'Nueva caja menor'),
      );
      final Finder btnMovimiento = find.descendant(
        of: encabezado,
        matching: find.widgetWithText(FilledButton, 'Registrar movimiento'),
      );

      expect(btnCerrar, findsOneWidget);
      expect(btnNueva, findsOneWidget);
      expect(btnMovimiento, findsOneWidget);

      final Offset posCerrar = tester.getTopLeft(btnCerrar);
      final Offset posNueva = tester.getTopLeft(btnNueva);
      final Offset posMovimiento = tester.getTopLeft(btnMovimiento);

      // Fila 1: Cerrar caja y Nueva caja menor estan alineados horizontalmente
      expect(posCerrar.dy, equals(posNueva.dy));
      expect(posNueva.dx, greaterThan(posCerrar.dx));

      // Fila 2: Registrar movimiento esta debajo de los 2 botones
      expect(posMovimiento.dy, greaterThan(posCerrar.dy));

      // Anchos: Registrar movimiento ocupa el ancho completo disponible
      final Size sizeCerrar = tester.getSize(btnCerrar);
      final Size sizeNueva = tester.getSize(btnNueva);
      final Size sizeMovimiento = tester.getSize(btnMovimiento);

      expect(sizeCerrar.width, equals(sizeNueva.width));
      expect(sizeMovimiento.width, greaterThan(sizeCerrar.width));

      // Probar interactividad
      await tester.tap(btnCerrar);
      await tester.tap(btnNueva);
      await tester.tap(btnMovimiento);

      expect(cerrarPresionado, isTrue);
      expect(nuevaPresionado, isTrue);
      expect(movimientoPresionado, isTrue);
    },
  );

  testWidgets(
    'CajaMenorView acomoda los 3 botones en una sola fila en escritorio',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        crearEntornoTest(
          tamanio: const Size(1024, 768),
          child: CajaMenorView(
            movimientos: const [],
            hayCajaMenor: true,
            mostrandoCargaMovimientosCaja: false,
            cargandoMasMovimientosCaja: false,
            puedeCrearCajaMenor: true,
            puedeRegistrarFlujoCaja: true,
            puedeModificarMovimientos: true,
            puedeModificarCreditos: true,
            puedeEliminarCreditos: true,
            esAdministrador: true,
            guardando: false,
            onRefresh: () async {},
            onNearEnd: () {},
            onCerrarCajaMenor: () {},
            onCrearCajaMenor: () {},
            onMovimientoCaja: () {},
            onModificarMovimiento: (_) {},
            mostrarMensaje: (_, {bool esError = false}) {},
            buscarController: TextEditingController(),
            filtros: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder encabezado = find.byType(Encabezado);
      final Finder btnCerrar = find.descendant(
        of: encabezado,
        matching: find.widgetWithText(OutlinedButton, 'Cerrar caja'),
      );
      final Finder btnNueva = find.descendant(
        of: encabezado,
        matching: find.widgetWithText(OutlinedButton, 'Nueva caja menor'),
      );
      final Finder btnMovimiento = find.descendant(
        of: encabezado,
        matching: find.widgetWithText(FilledButton, 'Registrar movimiento'),
      );

      expect(btnCerrar, findsOneWidget);
      expect(btnNueva, findsOneWidget);
      expect(btnMovimiento, findsOneWidget);

      // En escritorio se usa Wrap alineado al final para permitir flujo responsive
      final Finder wrapAcciones = find.descendant(
        of: encabezado,
        matching: find.byType(Wrap),
      );
      expect(wrapAcciones, findsOneWidget);
    },
  );

  testWidgets(
    'CajaMenorView muestra solo Registrar movimiento en encabezado cuando el empleado no puede crear caja',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        crearEntornoTest(
          tamanio: const Size(360, 780),
          child: CajaMenorView(
            movimientos: const [],
            hayCajaMenor: true,
            mostrandoCargaMovimientosCaja: false,
            cargandoMasMovimientosCaja: false,
            puedeCrearCajaMenor: false,
            puedeRegistrarFlujoCaja: true,
            puedeModificarMovimientos: false,
            puedeModificarCreditos: false,
            puedeEliminarCreditos: false,
            esAdministrador: false,
            guardando: false,
            onRefresh: () async {},
            onNearEnd: () {},
            onCerrarCajaMenor: () {},
            onCrearCajaMenor: () {},
            onMovimientoCaja: () {},
            onModificarMovimiento: (_) {},
            mostrarMensaje: (_, {bool esError = false}) {},
            buscarController: TextEditingController(),
            filtros: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder encabezado = find.byType(Encabezado);
      expect(
        find.descendant(
          of: encabezado,
          matching: find.text('Cerrar caja'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: encabezado,
          matching: find.text('Nueva caja menor'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: encabezado,
          matching: find.text('Registrar movimiento'),
        ),
        findsOneWidget,
      );
    },
  );
}
