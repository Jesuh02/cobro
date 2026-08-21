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
      expect(find.text(r'$100.000'), findsWidgets);
      expect(find.text(r'-$100.000'), findsNothing);
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
    'permite buscar cliente por nombre o cedula al crear credito',
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
      final Finder selectorCliente = find.descendant(
        of: dialogo,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is TextField && widget.decoration?.labelText == 'Cliente',
        ),
      );
      expect(selectorCliente, findsOneWidget);

      await tester.tap(selectorCliente);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Cliente de prueba'), findsOneWidget);
      expect(find.text('Cliente filtrado'), findsOneWidget);

      await tester.enterText(selectorCliente, '987654');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Cliente filtrado'), findsOneWidget);
      expect(find.text('Cliente de prueba'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'muestra pagos decimales sin redondear',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final ApiClient apiClient = ApiClient(
        baseUrl: 'https://cobro.test/api/v1',
        client: MockClient(_responderApiPagosPrecisos),
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

      await tester.tap(find.text('Ruta'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text(r'$0,8'), findsWidgets);
      expect(find.text(r'$0,04'), findsWidgets);
      expect(find.text(r'$1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'muestra visor interno al exportar Excel de ruta',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final ApiClient apiClient = ApiClient(
        baseUrl: 'https://cobro.test/api/v1',
        client: MockClient(_responderApiExportacionExcel),
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

      await tester.tap(find.text('Ruta'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Exportar'));
      await tester.pumpAndSettle();

      expect(find.text('cobros-ruta-prueba.xlsx'), findsOneWidget);
      expect(find.text('Archivo guardado en Cloudflare R2'), findsNothing);
      expect(find.text('Cliente'), findsWidgets);
      expect(find.text('Cliente decimal'), findsWidgets);
      expect(find.text('0,04'), findsOneWidget);
      expect(find.text('Descargar'), findsOneWidget);
      expect(
        find.textContaining('pub-9f393625246c4018b5613be60b01bda1.r2.dev'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exporta caja menor sin enviar tipo cuando el filtro es todos',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      Uri? exportUri;
      final ApiClient apiClient = ApiClient(
        baseUrl: 'https://cobro.test/api/v1',
        client: MockClient((http.Request request) async {
          if (request.url.path.endsWith('/exportaciones/caja-menor')) {
            exportUri = request.url;
            return _jsonResponse(_exportacionExcelCajaMenor());
          }

          return _responderApiPagosPrecisos(request);
        }),
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

      await tester.tap(
        find.ancestor(
          of: find.text('Caja menor'),
          matching: find.byType(ListTile),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final Finder exportar = find.widgetWithText(OutlinedButton, 'Exportar');
      await tester.ensureVisible(exportar);
      await tester.tap(exportar);
      await tester.pumpAndSettle();

      expect(exportUri, isNotNull);
      expect(exportUri!.queryParameters.containsKey('tipo'), isFalse);
      expect(find.text('caja-menor-prueba.xlsx'), findsOneWidget);
      expect(find.text('Cliente caja menor'), findsOneWidget);
      expect(find.text('100200300'), findsOneWidget);
      expect(find.text('Monto con naturaleza'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'muestra cliente beneficiario en movimientos de caja',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final ApiClient apiClient = ApiClient(
        baseUrl: 'https://cobro.test/api/v1',
        client: MockClient(_responderApiMovimientosConCliente),
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

      await tester.tap(
        find.ancestor(
          of: find.text('Caja menor'),
          matching: find.byType(ListTile),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(
        find.text('Desembolso de credito para Cliente desembolso'),
        findsOneWidget,
      );
      expect(find.text('Desembolso de credito'), findsNothing);
      expect(
        find.textContaining('Cliente: Cliente desembolso'),
        findsOneWidget,
      );
      expect(find.textContaining('Identificacion: 123456789'), findsOneWidget);
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

Map<String, dynamic> _exportacionExcelCajaMenor() {
  return <String, dynamic>{
    'archivo': 'caja-menor-prueba.xlsx',
    'key': 'exportaciones/caja-menor/2026-08-19/caja-menor-prueba.xlsx',
    'url':
        'https://pub-9f393625246c4018b5613be60b01bda1.r2.dev/exportaciones/caja-menor/2026-08-19/caja-menor-prueba.xlsx',
    'filas': 1,
    'generadoEn': '2026-08-19T18:20:00.000Z',
    'vistaPrevia': <String, dynamic>{
      'columnas': <String>['Fecha', 'Cliente', 'Identificacion', 'Monto'],
      'filas': <List<Object>>[
        <Object>['2026-08-19', 'Cliente caja menor', '100200300', 0.04],
      ],
    },
  };
}

Future<http.Response> _responderApiMovimientosConCliente(
  http.Request request,
) async {
  final String path = request.url.path;

  if (path.endsWith('/caja-menor/movimientos')) {
    return _jsonResponse(<Map<String, dynamic>>[
      _movimientoCajaConCliente(),
    ]);
  }

  return _responderApiPagosPrecisos(request);
}

Map<String, dynamic> _movimientoCajaConCliente() {
  return <String, dynamic>{
    'id': 'movimiento-cliente',
    'cajaMenorId': 'caja-1',
    'cajaMenor': 'Caja principal',
    'cliente': 'Cliente desembolso',
    'clienteIdentificacion': '123456789',
    'tipoMovimiento': <String, dynamic>{
      'id': 1,
      'codigo': 'DESEMBOLSO_CREDITO',
      'nombre': 'Desembolso credito',
      'naturaleza': 'S',
    },
    'usuario': null,
    'fechaMovimiento': '2026-08-19',
    'monto': 100,
    'montoConNaturaleza': -100,
    'motivo': 'Desembolso de credito',
    'referenciaTabla': 'credito_desembolso',
    'referenciaId': '00000000-0000-0000-0000-000000000001',
    'creadoEn': '2026-08-19T18:30:00.000Z',
  };
}

Future<http.Response> _responderApiExportacionExcel(
  http.Request request,
) async {
  final String path = request.url.path;

  if (path.endsWith('/exportaciones/cobros-ruta')) {
    return _jsonResponse(<String, dynamic>{
      'archivo': 'cobros-ruta-prueba.xlsx',
      'key': 'exportaciones/cobros-ruta/2026-08-19/cobros-ruta-prueba.xlsx',
      'url':
          'https://pub-9f393625246c4018b5613be60b01bda1.r2.dev/exportaciones/cobros-ruta/2026-08-19/cobros-ruta-prueba.xlsx',
      'filas': 1,
      'generadoEn': '2026-08-19T18:10:00.000Z',
      'vistaPrevia': <String, dynamic>{
        'columnas': <String>['Cliente', 'Saldo proxima cuota'],
        'filas': <List<Object>>[
          <Object>['Cliente decimal', 0.04],
        ],
      },
    });
  }

  return _responderApiPagosPrecisos(request);
}

Future<http.Response> _responderApiPagosPrecisos(http.Request request) async {
  final String path = request.url.path;

  if (path.endsWith('/catalogos')) {
    return _jsonResponse(_catalogosCredito());
  }

  if (path.endsWith('/clientes')) {
    return _jsonResponse(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'cliente-decimal',
        'nombreCompleto': 'Cliente decimal',
        'cedula': '100',
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
          'cajaMenor': 0.8,
          'recaudado': 0.04,
          'gastos': 0,
          'creditos': 0,
          'presupuesto': 0.84,
        },
      ],
      'totales': <String, dynamic>{
        'cajaMenor': 0.8,
        'recaudado': 0.04,
        'gastos': 0,
        'creditos': 0,
        'presupuesto': 0.84,
      },
    });
  }

  if (path.endsWith('/cobros/ruta')) {
    return _jsonResponse(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'cobro-decimal',
        'cliente': 'Cliente decimal',
        'cedula': '100',
        'negocio': null,
        'rutaId': 'ruta-1',
        'ruta': 'Ruta decimal',
        'valorTotal': 0.8,
        'valorCuota': 0.04,
        'totalAbonado': 0,
        'saldo': 0.8,
        'numeroCuotas': 20,
        'cuotasRestantes': 20,
        'proximaCuotaId': 'cuota-decimal',
        'proximaNumeroCuota': 1,
        'proximaFechaPago': '2026-08-20',
        'proximoSaldoCuota': 0.04,
        'estadoCobro': 'PENDIENTE',
      },
    ]);
  }

  if (path.endsWith('/caja-menor/movimientos')) {
    return _jsonResponse(<dynamic>[]);
  }

  return _responderApi(request);
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
      <String, dynamic>{
        'id': 'cliente-2',
        'nombreCompleto': 'Cliente filtrado',
        'cedula': '987654',
        'nombreComercial': 'Tienda filtro',
        'correo': null,
        'telefono': '3001234567',
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
          'gastos': -100000,
          'creditos': 250000,
          'presupuesto': 850000,
        },
      ],
      'totales': <String, dynamic>{
        'cajaMenor': 700000,
        'recaudado': 500000,
        'gastos': -100000,
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
