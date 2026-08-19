import 'dart:convert';

import 'package:cobro_app/app/app_theme.dart';
import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/features/dashboard/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'muestra Inicio en movil y permite compactar el menu de escritorio',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final ApiClient apiClient = ApiClient(
        baseUrl: 'https://cobro.test/api/v1',
        client: MockClient(_responderApi),
      );
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: CobroAppTheme.light(),
          home: HomePage(
            apiBaseUrl: 'https://cobro.test/api/v1',
            apiClient: apiClient,
            themeMode: ThemeMode.light,
            onThemeModeChanged: (_) {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'admin');
      await tester.enterText(find.byType(TextField).at(1), 'Admin12345!');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Gestión de Presupuesto'), findsOneWidget);
      expect(find.text('TOTAL PRESUPUESTO'), findsOneWidget);
      expect(find.text('Inicio'), findsWidgets);
      expect(find.text('Ruta'), findsOneWidget);
      expect(find.text('Credito'), findsOneWidget);
      expect(find.text('Caja menor'), findsWidgets);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(find.text('Navegacion'), findsNothing);

      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('Navegacion'), findsOneWidget);
      expect(
        find.byIcon(Icons.keyboard_double_arrow_left_rounded),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.menu_rounded), findsNothing);

      await tester.tap(
        find.byIcon(Icons.keyboard_double_arrow_left_rounded),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.menu_open_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'calcula y muestra el resumen animado del credito en movil',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final ApiClient apiClient = ApiClient(
        baseUrl: 'https://cobro.test/api/v1',
        client: MockClient(_responderApiCredito),
      );
      addTearDown(apiClient.close);
      expect(Catalogos.fromJson(_catalogosCredito()).cajasMenores, isNotEmpty);

      await tester.pumpWidget(
        MaterialApp(
          theme: CobroAppTheme.light(),
          home: HomePage(
            apiBaseUrl: 'https://cobro.test/api/v1',
            apiClient: apiClient,
            themeMode: ThemeMode.light,
            onThemeModeChanged: (_) {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'admin');
      await tester.enterText(find.byType(TextField).at(1), 'Admin12345!');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      tester.takeException();

      await tester.tap(find.text('Credito'));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();

      expect(find.text('Nuevo crédito'), findsOneWidget);

      final Finder dialogo = find.byType(AlertDialog);
      final Finder valorPrincipal = find.descendant(
        of: dialogo,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Valor principal',
        ),
      );
      expect(valorPrincipal, findsOneWidget);
      await tester.enterText(valorPrincipal, '200');
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: dialogo,
          matching: find.text('Así se calcula el crédito'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialogo,
          matching: find.text(r'$240 ÷ 30 cuotas = $8 por cuota'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialogo,
          matching: find.textContaining('30 cuotas diarias'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: dialogo,
          matching: find.textContaining('Se omiten'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'muestra alerta superior cuando el prestamo supera la caja menor',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final ApiClient apiClient = ApiClient(
        baseUrl: 'https://cobro.test/api/v1',
        client: MockClient(_responderApiCredito),
      );
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: CobroAppTheme.light(),
          home: HomePage(
            apiBaseUrl: 'https://cobro.test/api/v1',
            apiClient: apiClient,
            themeMode: ThemeMode.light,
            onThemeModeChanged: (_) {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'admin');
      await tester.enterText(find.byType(TextField).at(1), 'Admin12345!');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      tester.takeException();

      await tester.tap(find.text('Credito'));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();

      final Finder dialogo = find.byType(AlertDialog);
      final Finder valorPrincipal = find.descendant(
        of: dialogo,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Valor principal',
        ),
      );
      await tester.enterText(valorPrincipal, '900000');
      await tester.pump(const Duration(milliseconds: 300));

      final Finder crearCredito = find.descendant(
        of: dialogo,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Text && (widget.data?.startsWith('Crear cr') ?? false),
        ),
      );
      await tester.ensureVisible(crearCredito);
      await tester.tap(crearCredito);
      await tester.pump(const Duration(milliseconds: 300));

      final Finder alerta = find.text(
        'Caja menor insuficiente. El prestamo supera el dinero disponible.',
      );
      expect(alerta, findsOneWidget);
      expect(find.text('Revisa la caja menor'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.getTopLeft(alerta).dy, lessThan(100));
      expect(tester.takeException(), isNull);
    },
  );
}

Future<http.Response> _responderApiCredito(http.Request request) async {
  final String path = request.url.path;

  if (path.endsWith('/catalogos')) {
    return _jsonResponse(_catalogosCredito());
  }

  if (path.endsWith('/clientes')) {
    return _jsonResponse(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'cliente-1',
        'nombreCompleto': 'Cliente de prueba',
        'cedula': '123456',
        'nombreComercial': null,
        'correo': null,
        'telefono': null,
        'estado': <String, dynamic>{'nombre': 'Activo'},
      },
    ]);
  }

  if (path.endsWith('/presupuesto')) {
    return _jsonResponse(<String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'cajaMenorId': 'caja-1',
          'monedaCodigo': 'COP',
          'cajaMenor': 700000,
          'recaudado': 500000,
          'gastos': 100000,
          'creditos': 250000,
          'presupuesto': 850000,
        },
      ],
      'totales': <String, dynamic>{
        'cajaMenor': 700000,
        'recaudado': 500000,
        'gastos': 100000,
        'creditos': 250000,
        'presupuesto': 850000,
      },
    });
  }

  return _responderApi(request);
}

Map<String, dynamic> _catalogosCredito() {
  return <String, dynamic>{
    'monedas': <Map<String, dynamic>>[
      <String, dynamic>{'codigo': 'COP', 'nombre': 'Peso colombiano'},
    ],
    'frecuenciasPago': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'codigo': 'DIARIO',
        'nombre': 'Diario',
        'diasIntervalo': 1,
      },
    ],
    'mediosPago': <dynamic>[],
    'tiposMovimientoCaja': <dynamic>[],
    'rutas': <dynamic>[],
    'cajasMenores': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'caja-1',
        'nombre': 'Caja principal',
        'activa': true,
        'monedaCodigo': 'COP',
      },
    ],
    'usuarios': <dynamic>[],
  };
}

Future<http.Response> _responderApi(http.Request request) async {
  final String path = request.url.path;

  if (request.method == 'POST' && path.endsWith('/auth/login')) {
    return _jsonResponse(<String, dynamic>{
      'token': 'token-de-prueba',
      'usuario': <String, dynamic>{
        'id': 'usuario-1',
        'usuario': 'admin',
        'nombreCompleto': 'Administrador de prueba',
        'correo': 'admin@cobro.test',
        'roles': <String>['ADMIN'],
        'esAdministrador': true,
      },
    });
  }

  if (path.endsWith('/catalogos')) {
    return _jsonResponse(<String, dynamic>{
      'monedas': <dynamic>[],
      'frecuenciasPago': <dynamic>[],
      'mediosPago': <dynamic>[],
      'tiposMovimientoCaja': <dynamic>[],
      'rutas': <dynamic>[],
      'cajasMenores': <dynamic>[],
      'usuarios': <dynamic>[],
    });
  }

  if (path.endsWith('/presupuesto')) {
    return _jsonResponse(<String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'monedaCodigo': 'COP',
          'cajaMenor': 700000,
          'recaudado': 500000,
          'gastos': 100000,
          'creditos': 250000,
          'presupuesto': 850000,
        },
      ],
      'totales': <String, dynamic>{
        'cajaMenor': 700000,
        'recaudado': 500000,
        'gastos': 100000,
        'creditos': 250000,
        'presupuesto': 850000,
      },
    });
  }

  if (path.endsWith('/clientes') ||
      path.endsWith('/cobros/ruta') ||
      path.endsWith('/caja-menor/movimientos')) {
    return _jsonResponse(<dynamic>[]);
  }

  return _jsonResponse(
    <String, dynamic>{'message': 'Ruta no simulada: $path'},
    statusCode: 404,
  );
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: <String, String>{'content-type': 'application/json'},
  );
}
