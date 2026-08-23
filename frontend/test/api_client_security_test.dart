import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('solo adjunta tokens con estructura JWT valida', () async {
    String? authorization;
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      client: MockClient((http.Request request) async {
        authorization = request.headers['authorization'];
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);

    client.setAuthToken('cabecera.carga.firma');
    await client.getObject('/catalogos');

    expect(authorization, 'Bearer cabecera.carga.firma');
    expect(
      () => client.setAuthToken('cabecera.carga.firma\r\nX-Injected: true'),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => client.setAuthToken('token-sin-estructura-jwt'),
      throwsA(isA<ApiException>()),
    );
  });

  test('rechaza respuestas JSON malformadas sin exponer su contenido',
      () async {
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      client: MockClient(
        (_) async => http.Response('<html>detalle interno</html>', 502),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      client.getObject('/catalogos'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 502)
            .having(
              (error) => error.message,
              'message',
              isNot(contains('detalle interno')),
            ),
      ),
    );
  });
}
