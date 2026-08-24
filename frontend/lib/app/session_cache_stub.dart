String? _cachedSessionPayload;

Future<String?> loadCachedSessionPayload() async {
  return _cachedSessionPayload;
}

Future<void> saveCachedSessionPayload(String payload) async {
  _cachedSessionPayload = payload;
}

Future<void> clearCachedSessionPayload() async {
  _cachedSessionPayload = null;
}
