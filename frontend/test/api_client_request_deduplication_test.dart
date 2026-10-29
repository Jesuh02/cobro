import 'dart:async';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('comparte lecturas GET iguales mientras la respuesta esta en curso',
      () async {
    final Completer<http.Response> respuestaPendiente =
        Completer<http.Response>();
    int solicitudes = 0;
    final ApiClient client = ApiClient(
      baseUrl: 'https://cobro.test/api/v1',
      client: MockClient((http.Request request) {
        solicitudes++;
        return respuestaPendiente.future;
      }),
    );
    addTearDown(client.close);

    final Future<Map<String, dynamic>> primera = client.getObject('/catalogos');
    final Future<Map<String, dynamic>> segunda = client.getObject('/catalogos');

    await Future<void>.delayed(Duration.zero);

    expect(solicitudes, 1);

    respuestaPendiente.complete(http.Response('{"ok":true}', 200));

    expect(await primera, <String, dynamic>{'ok': true});
    expect(await segunda, <String, dynamic>{'ok': true});

    await client.getObject('/catalogos');

    expect(solicitudes, 2);
  });
}
