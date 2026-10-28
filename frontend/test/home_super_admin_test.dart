import 'dart:async';
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
    'navega a gestión de acceso, filtra y actualiza el estado localmente',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final Completer<http.Response> patchPendiente =
          Completer<http.Response>();
      http.Request? ultimaConsultaUsuarios;
      final ApiClient apiClient = ApiClient(
        baseUrl: 'https://cobro.test/api/v1',
        client: MockClient((http.Request request) async {
          final String path = request.url.path;
          if (request.method == 'POST' && path.endsWith('/auth/login')) {
            return _jsonResponse(<String, dynamic>{
              'token': 'cabecera.carga.firma',
              'usuario': <String, dynamic>{
                'id': _superAdminId,
                'usuario': 'super.admin',
                'nombreCompleto': 'Super Administrador',
                'correo': 'super@cobro.test',
                'roles': <String>['SUPER_ADMIN'],
                'esAdministrador': false,
                'esSuperAdmin': true,
                'permisos': <String>[],
                'activo': true,
              },
            });
          }
          if (request.method == 'GET' &&
              path.endsWith('/super-admin/organizaciones')) {
            return _jsonResponse(<Object>[_organizacionJson]);
          }
          if (request.method == 'GET' &&
              path.endsWith('/super-admin/usuarios')) {
            ultimaConsultaUsuarios = request;
            return _jsonResponse(<Object>[
              _usuarioJson(
                id: _superAdminId,
                usuario: 'super.admin',
                nombre: 'Super Administrador',
                roles: const <String>['SUPER_ADMIN'],
              ),
              _usuarioJson(
                id: _cobradorId,
                usuario: 'cobrador.uno',
                nombre: "Jesús D'Ávila",
                roles: const <String>['COBRADOR'],
              ),
            ]);
          }
          if (request.method == 'PATCH' &&
              path.endsWith('/super-admin/usuarios/$_cobradorId/estado')) {
            return patchPendiente.future;
          }
          return _jsonResponse(
            <String, dynamic>{'message': 'Ruta no simulada: $path'},
            statusCode: 404,
          );
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

      await tester.enterText(find.byType(TextField).at(0), 'super.admin');
      await tester.enterText(find.byType(TextField).at(1), 'Admin12345!');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      _descartarExcepcionesPrevias(tester);

      expect(
        find.byKey(
          const ValueKey<String>('super-admin-tab-instituciones'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SegmentedButton<int>>(
              find.byKey(
                const ValueKey<String>('super-admin-navigation'),
              ),
            )
            .selected,
        <int>{0},
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('super-admin-tab-acceso')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text("Jesús D'Ávila"), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<int>>(
              find.byKey(
                const ValueKey<String>('super-admin-navigation'),
              ),
            )
            .selected,
        <int>{1},
      );
      expect(ultimaConsultaUsuarios?.url.queryParameters, isEmpty);

      await tester.enterText(
        find.byKey(
          const ValueKey<String>('buscar-usuarios-super-admin'),
        ),
        'jesus',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(ultimaConsultaUsuarios?.url.queryParameters['q'], 'jesus');

      await tester.tap(
        find.byKey(
          const ValueKey<String>('estado-usuario-$_cobradorId'),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('metrica-usuarios-inactivos'),
          ),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      patchPendiente.complete(
        _jsonResponse(
          <String, dynamic>{
            ..._usuarioJson(
              id: _cobradorId,
              usuario: 'cobrador.uno',
              nombre: 'Cobrador Uno',
              roles: const <String>['COBRADOR'],
            ),
            'activo': false,
          },
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      final Switch estadoFinal = tester.widget<Switch>(
        find.byKey(
          const ValueKey<String>('estado-usuario-$_cobradorId'),
        ),
      );
      expect(estadoFinal.value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

void _descartarExcepcionesPrevias(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

const String _superAdminId = '11111111-1111-1111-1111-111111111111';
const String _cobradorId = '22222222-2222-2222-2222-222222222222';
const String _organizacionId = '33333333-3333-3333-3333-333333333333';

const Map<String, dynamic> _organizacionJson = <String, dynamic>{
  'id': _organizacionId,
  'nombre': 'Institución Uno',
  'telefono': null,
  'correo': 'contacto@institucion.test',
  'activo': true,
  'esSistema': false,
  'montoPlan': 0,
  'monedaPlan': 'COP',
  'accesoHasta': null,
  'suspendidaEn': null,
  'motivoSuspension': null,
  'suspendida': false,
  'diasRestantes': null,
  'usuariosTotal': 2,
  'usuariosActivos': 2,
  'administradores': <String>[],
};

Map<String, dynamic> _usuarioJson({
  required String id,
  required String usuario,
  required String nombre,
  required List<String> roles,
}) {
  return <String, dynamic>{
    'id': id,
    'usuario': usuario,
    'nombreCompleto': nombre,
    'nombres': nombre.split(' ').first,
    'apellidos': nombre.split(' ').skip(1).join(' '),
    'identificacion': '100200300',
    'correo': '$usuario@cobro.test',
    'telefono': null,
    'activo': true,
    'organizacionId': _organizacionId,
    'organizacionNombre': 'Institución Uno',
    'organizacionSuspendida': false,
    'roles': roles,
    'creadoEn': '2026-10-27T14:30:00.000Z',
  };
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}
