class OfflineMutation {
  const OfflineMutation({
    required this.id,
    required this.method,
    required this.path,
    required this.body,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  OfflineMutation copyWith({
    int? attempts,
    String? lastError,
  }) {
    return OfflineMutation(
      id: id,
      method: method,
      path: path,
      body: body,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'method': method,
      'path': path,
      if (body != null) 'body': body,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
      if (lastError != null) 'lastError': lastError,
    };
  }

  static OfflineMutation fromJson(Map<String, dynamic> json) {
    return OfflineMutation(
      id: json['id'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      body: json['body'] is Map<String, dynamic>
          ? json['body'] as Map<String, dynamic>
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: json['attempts'] is int ? json['attempts'] as int : 0,
      lastError: json['lastError'] as String?,
    );
  }
}

class OfflineSyncResult {
  const OfflineSyncResult({
    required this.synced,
    required this.pending,
    this.blockedBy,
  });

  final int synced;
  final int pending;
  final Object? blockedBy;
}
