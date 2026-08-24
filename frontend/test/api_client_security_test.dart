import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/network/api_exception.dart';
import 'package:cobro_app/core/network/offline_mutation_queue.dart';
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

  test('encola mutaciones offline y las sincroniza al volver la conexion',
      () async {
    final OfflineMutationQueue queue = OfflineMutationQueue();
    await queue.clear();
    int requests = 0;
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      offlineQueue: queue,
      client: MockClient((http.Request request) async {
        requests++;
        if (requests == 1) {
          throw http.ClientException('failed to fetch', request.url);
        }
        return http.Response('{"ok":true}', 200);
      }),
    );
    addTearDown(client.close);

    client.setAuthToken('cabecera.carga.firma');

    await expectLater(
      client.postObject(
        '/clientes',
        <String, dynamic>{'nombreCompleto': 'Cliente Offline'},
        queueOffline: true,
      ),
      throwsA(
        isA<OfflineMutationQueuedException>().having(
          (OfflineMutationQueuedException error) => error.pendingCount,
          'pendingCount',
          1,
        ),
      ),
    );

    expect(await client.pendingOfflineActions(), 1);

    final result = await client.syncOfflineActions();

    expect(result.synced, 1);
    expect(result.pending, 0);
    expect(await client.pendingOfflineActions(), 0);
  });

  test('encola mutaciones si backend reporta base de datos no disponible',
      () async {
    final OfflineMutationQueue queue = OfflineMutationQueue();
    await queue.clear();
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      offlineQueue: queue,
      client: MockClient((http.Request request) async {
        return http.Response(
          '{"statusCode":503,"code":"DATABASE_UNAVAILABLE","message":"Sin base de datos"}',
          503,
        );
      }),
    );
    addTearDown(client.close);

    client.setAuthToken('cabecera.carga.firma');

    await expectLater(
      client.postObject(
        '/clientes',
        <String, dynamic>{'nombreCompleto': 'Cliente Offline'},
        queueOffline: true,
      ),
      throwsA(isA<OfflineMutationQueuedException>()),
    );

    expect(await client.pendingOfflineActions(), 1);
  });
}
