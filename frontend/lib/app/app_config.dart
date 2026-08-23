import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const String configured = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000/api/v1',
    );
    final String normalized =
        configured.trim().replaceFirst(RegExp(r'/+$'), '');
    final Uri? uri = Uri.tryParse(normalized);
    final bool loopback = uri != null &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1');

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) ||
        (kReleaseMode && uri.scheme != 'https')) {
      throw StateError(
        'API_BASE_URL debe ser una URL HTTPS valida sin credenciales, query ni fragmento',
      );
    }

    return AppConfig(apiBaseUrl: normalized);
  }

  final String apiBaseUrl;
}
