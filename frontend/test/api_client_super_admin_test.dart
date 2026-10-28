import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const String usuarioId = '11111111-1111-1111-1111-111111111111';
  const String organizacionId = '22222222-2222-2222-2222-222222222222';
  const Map<String, dynamic> usuarioJson = <String, dynamic>{
    'id': usuarioId,
    'usuario': 'ana.admin',
    'nombreCompleto': 'Ana Admin',
    'nombres': 'Ana',
    'apellidos': 'Admin',
    'identificacion': '1000123456',
    'correo': 'ana@example.com',
    'telefono': null,
    'activo': true,
    'organizacionId': organizacionId,
    'organizacionNombre': 'Institución Demo',
    'organizacionSuspendida': false,
    'roles': <String>['ADMINISTRADOR'],
    'creadoEn': '2026-10-27T14:30:00.000Z',
  };

  test('lista usuarios enviando únicamente los filtros definidos', () async {
    late http.Request capturedRequest;
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      client: MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode(<Object>[usuarioJson])),
          200,
        );
      }),
    );
    addTearDown(client.close);

    final List<UsuarioSuperAdminItem> usuarios =
        await client.getUsuariosSuperAdmin(
      organizacionId: organizacionId,
      q: 'Ana Admin',
      activo: false,
    );

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/api/v1/super-admin/usuarios');
    expect(capturedRequest.url.queryParameters, <String, String>{
      'organizacionId': organizacionId,
      'q': 'Ana Admin',
      'activo': 'false',
    });
    expect(usuarios, hasLength(1));
    expect(usuarios.single.esAdministrador, isTrue);
  });

  test('omite filtros nulos o vacíos del listado', () async {
    late http.Request capturedRequest;
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      client: MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(client.close);

    await client.getUsuariosSuperAdmin(q: '   ');

    expect(capturedRequest.url.queryParameters, isEmpty);
  });

  test('actualiza el estado y deserializa la respuesta', () async {
    late http.Request capturedRequest;
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      client: MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, dynamic>{...usuarioJson, 'activo': false}),
          ),
          200,
        );
      }),
    );
    addTearDown(client.close);

    final UsuarioSuperAdminItem actualizado =
        await client.actualizarEstadoUsuarioSuperAdmin(
      usuarioId,
      activo: false,
    );

    expect(capturedRequest.method, 'PATCH');
    expect(
      capturedRequest.url.path,
      '/api/v1/super-admin/usuarios/$usuarioId/estado',
    );
    expect(
      jsonDecode(capturedRequest.body),
      <String, dynamic>{'activo': false},
    );
    expect(actualizado.activo, isFalse);
    expect(actualizado.id, usuarioId);
  });
}
