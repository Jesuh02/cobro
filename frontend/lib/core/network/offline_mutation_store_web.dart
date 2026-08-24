import 'dart:js_interop';

const String _offlineMutationKey = 'cobro.offlineMutations.v1';

@JS('window.localStorage')
external _LocalStorage get _localStorage;

extension type _LocalStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
}

Future<String?> loadOfflineMutationPayload() async {
  try {
    return _localStorage.getItem(_offlineMutationKey.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

Future<void> saveOfflineMutationPayload(String payload) async {
  try {
    _localStorage.setItem(_offlineMutationKey.toJS, payload.toJS);
  } catch (_) {
    return;
  }
}
