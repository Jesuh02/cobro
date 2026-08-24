class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.statusCode,
    this.code,
  });

  final String message;
  final int statusCode;
  final String? code;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, code: $code, message: $message)';
  }
}

class OfflineMutationQueuedException implements Exception {
  const OfflineMutationQueuedException({
    required this.pendingCount,
    this.message = 'Accion guardada. Se sincronizara cuando vuelva internet.',
  });

  final int pendingCount;
  final String message;

  @override
  String toString() {
    return 'OfflineMutationQueuedException(pendingCount: $pendingCount, message: $message)';
  }
}
