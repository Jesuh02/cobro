import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'offline_mutation.dart';
import 'offline_mutation_queue.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    OfflineMutationQueue? offlineQueue,
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client(),
        _offlineQueue = offlineQueue ?? OfflineMutationQueue();

  final String _baseUrl;
  final http.Client _client;
  final OfflineMutationQueue _offlineQueue;
  String? _authToken;
  bool _syncingOffline = false;
  static const Duration _requestTimeout = Duration(seconds: 25);

  void setAuthToken(String? token) {
    if (token != null &&
        (token.length > 2048 ||
            !RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$')
                .hasMatch(token))) {
      throw const ApiException(
        statusCode: 401,
        message: 'El servidor entrego una sesion invalida',
      );
    }
    _authToken = token;
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> query = const <String, String?>{},
  }) async {
    final response = await _client
        .get(_uri(path, query), headers: _headers)
        .timeout(_requestTimeout);
    final body = _decode(response);

    if (body is! List<dynamic>) {
      throw const ApiException(
        statusCode: 500,
        message: 'Expected a list response from the API',
      );
    }

    return body;
  }

  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, String?> query = const <String, String?>{},
  }) async {
    final response = await _client
        .get(_uri(path, query), headers: _headers)
        .timeout(_requestTimeout);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postObject(
    String path,
    Map<String, dynamic> body, {
    bool queueOffline = false,
  }) async {
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      return _decodeObject(response);
    } catch (error) {
      await _queueIfOffline(
        enabled: queueOffline,
        error: error,
        method: 'POST',
        path: path,
        body: body,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> patchObject(
    String path,
    Map<String, dynamic>? body, {
    bool queueOffline = false,
  }) async {
    try {
      final response = await _client
          .patch(
            _uri(path),
            headers: _headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _decodeObject(response);
    } catch (error) {
      await _queueIfOffline(
        enabled: queueOffline,
        error: error,
        method: 'PATCH',
        path: path,
        body: body,
      );
      rethrow;
    }
  }

  Future<List<dynamic>> patchList(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await _client
        .patch(
          _uri(path),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_requestTimeout);
    final decoded = _decode(response);

    if (decoded is! List<dynamic>) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Expected a list response from the API',
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> deleteObject(
    String path, {
    bool queueOffline = false,
  }) async {
    try {
      final response = await _client
          .delete(_uri(path), headers: _headers)
          .timeout(_requestTimeout);
      return _decodeObject(response);
    } catch (error) {
      await _queueIfOffline(
        enabled: queueOffline,
        error: error,
        method: 'DELETE',
        path: path,
      );
      rethrow;
    }
  }

  Future<int> pendingOfflineActions() {
    return _offlineQueue.count();
  }

  Future<OfflineSyncResult> syncOfflineActions() async {
    if (_syncingOffline || _authToken == null) {
      return OfflineSyncResult(
        synced: 0,
        pending: await _offlineQueue.count(),
      );
    }

    _syncingOffline = true;
    int synced = 0;
    Object? blockedBy;

    try {
      while (true) {
        final List<OfflineMutation> mutations = await _offlineQueue.load();
        if (mutations.isEmpty) {
          return OfflineSyncResult(synced: synced, pending: 0);
        }

        final OfflineMutation mutation = mutations.first;
        try {
          await _sendQueuedMutation(mutation);
          await _offlineQueue.remove(mutation.id);
          synced++;
        } catch (error) {
          blockedBy = error;
          await _offlineQueue.replace(
            mutation.copyWith(
              attempts: mutation.attempts + 1,
              lastError: _publicSyncError(error),
            ),
          );
          break;
        }
      }

      return OfflineSyncResult(
        synced: synced,
        pending: await _offlineQueue.count(),
        blockedBy: blockedBy,
      );
    } finally {
      _syncingOffline = false;
    }
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
    dynamic rawBody;
    try {
      rawBody = response.bodyBytes.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'El servidor entrego una respuesta invalida',
      );
    }

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

  Future<void> _queueIfOffline({
    required bool enabled,
    required Object error,
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    if (!enabled || !_isQueueableOfflineError(error)) {
      return;
    }

    await _offlineQueue.enqueue(
      method: method,
      path: path,
      body: body,
    );

    throw OfflineMutationQueuedException(
      pendingCount: await _offlineQueue.count(),
    );
  }

  Future<void> _sendQueuedMutation(OfflineMutation mutation) async {
    final http.Response response;
    final Uri requestUri = _uri(mutation.path);
    final Object? body =
        mutation.body == null ? null : jsonEncode(mutation.body);

    switch (mutation.method) {
      case 'POST':
        response = await _client
            .post(requestUri, headers: _headers, body: body)
            .timeout(_requestTimeout);
        break;
      case 'PATCH':
        response = await _client
            .patch(requestUri, headers: _headers, body: body)
            .timeout(_requestTimeout);
        break;
      case 'DELETE':
        response = await _client
            .delete(requestUri, headers: _headers)
            .timeout(_requestTimeout);
        break;
      default:
        throw ApiException(
          statusCode: 500,
          message: 'Metodo offline no soportado: ${mutation.method}',
        );
    }

    _decode(response);
  }

  bool _isConnectivityError(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return true;
    }

    final String detail = error.toString().toLowerCase();
    return detail.contains('connection refused') ||
        detail.contains('failed to fetch') ||
        detail.contains('xmlhttprequest error') ||
        detail.contains('socketexception') ||
        detail.contains('networkerror') ||
        detail.contains('network error');
  }

  bool _isQueueableOfflineError(Object error) {
    if (_isConnectivityError(error)) {
      return true;
    }

    if (error is ApiException) {
      return error.code == 'DATABASE_UNAVAILABLE' ||
          error.statusCode == 502 ||
          error.statusCode == 503 ||
          error.statusCode == 504;
    }

    return false;
  }

  String _publicSyncError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    if (_isConnectivityError(error)) {
      return 'Sin conexion con la API';
    }

    return 'No se pudo sincronizar la accion';
  }
}
