import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/features/creditos/presentation/widgets/filtros_credito.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets(
    'FiltrosCredito renderiza SegmentedButton con Todos, Activos e Inactivos sin quiebre de texto en movil',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FiltroEstadoCredito filtroSeleccionado = FiltroEstadoCredito.todos;

      await tester.pumpWidget(
        crearEntornoTest(
          FiltrosCredito(
            filtroCredito: filtroSeleccionado,
            onFiltroCreditoChanged: (FiltroEstadoCredito v) {
              filtroSeleccionado = v;
            },
            fechaCreditoDesde: null,
            fechaCreditoHasta: null,
            onSeleccionarRangoFechas: () {},
            exportando: false,
            onExportar: () {},
            hayFiltrosCredito: false,
            onLimpiarFiltros: () {},
          ),
        ),
      );

      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Activos'), findsOneWidget);
      expect(find.text('Inactivos'), findsOneWidget);

      // Cambiar a Inactivos
      await tester.tap(find.text('Inactivos'));
      await tester.pump();
      expect(filtroSeleccionado, equals(FiltroEstadoCredito.inactivos));

      // Cambiar a Activos
      await tester.tap(find.text('Activos'));
      await tester.pump();
      expect(filtroSeleccionado, equals(FiltroEstadoCredito.activos));
    },
  );

  testWidgets(
    'FiltrosCredito muestra boton unificado de rango de fechas y dispara callbacks de exportar y limpiar',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool rangoTapped = false;
      bool exportTapped = false;
      bool limpiarTapped = false;

      await tester.pumpWidget(
        crearEntornoTest(
          FiltrosCredito(
            filtroCredito: FiltroEstadoCredito.activos,
            onFiltroCreditoChanged: (_) {},
            fechaCreditoDesde: null,
            fechaCreditoHasta: null,
            onSeleccionarRangoFechas: () => rangoTapped = true,
            exportando: false,
            onExportar: () => exportTapped = true,
            hayFiltrosCredito: true,
            onLimpiarFiltros: () => limpiarTapped = true,
          ),
        ),
      );

      // Rango de fechas
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
    },
  );

  testWidgets(
    'FiltrosCredito formatea correctamente etiqueta con rango activo',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        crearEntornoTest(
          FiltrosCredito(
            filtroCredito: FiltroEstadoCredito.activos,
            onFiltroCreditoChanged: (_) {},
            fechaCreditoDesde: DateTime(2026, 10, 1),
            fechaCreditoHasta: DateTime(2026, 10, 24),
            onSeleccionarRangoFechas: () {},
            exportando: false,
            onExportar: () {},
            hayFiltrosCredito: true,
            onLimpiarFiltros: () {},
          ),
        ),
      );

      expect(find.textContaining('1 oct'), findsOneWidget);
      expect(find.textContaining('24 oct'), findsOneWidget);
    },
  );
}
