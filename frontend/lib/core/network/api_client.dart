import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> query = const <String, String?>{},
  }) async {
    final response = await _client.get(_uri(path, query), headers: _headers);
    final body = _decode(response);

    if (body is! List<dynamic>) {
      throw const ApiException(
        statusCode: 500,
        message: 'Expected a list response from the API',
      );
    }

    return body;
  }

  Future<Map<String, dynamic>> getObject(String path) async {
    final response = await _client.get(_uri(path), headers: _headers);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postObject(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> patchObject(String path) async {
    final response = await _client.patch(_uri(path), headers: _headers);
    return _decodeObject(response);
  }

  void close() {
    _client.close();
  }

  Map<String, String> get _headers => <String, String>{
        'content-type': 'application/json',
        'accept': 'application/json',
        if (_authToken != null) 'authorization': 'Bearer $_authToken',
      };

  Uri _uri(
    String path, [
    Map<String, String?> query = const <String, String?>{},
  ]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final queryParameters = <String, String>{};

    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.trim().isNotEmpty) {
        queryParameters[entry.key] = value;
      }
    }

    return Uri.parse('$_baseUrl$cleanPath').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final body = _decode(response);

    if (body is! Map<String, dynamic>) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Expected an object response from the API',
      );
    }

    return body;
  }

  dynamic _decode(http.Response response) {
    final rawBody = response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return rawBody;
    }

    if (rawBody is Map<String, dynamic>) {
      final Object? message = rawBody['message'];
      throw ApiException(
        statusCode: response.statusCode,
        code: rawBody['code'] as String?,
        message: message is String
            ? message
            : message is List<dynamic>
                ? message.join(', ')
                : 'Request failed',
      );
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: 'Request failed',
    );
  }
}
