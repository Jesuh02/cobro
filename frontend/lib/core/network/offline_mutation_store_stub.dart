String? _offlineMutationPayload;

Future<String?> loadOfflineMutationPayload() async {
  return _offlineMutationPayload;
}

Future<void> saveOfflineMutationPayload(String payload) async {
  _offlineMutationPayload = payload;
}
