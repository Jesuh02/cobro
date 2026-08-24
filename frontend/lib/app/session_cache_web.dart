import 'dart:js_interop';

const String _sessionCacheKey = 'cobro.session.v1';

@JS('window.localStorage')
external _LocalStorage get _localStorage;

extension type _LocalStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void removeItem(JSString key);
  external void setItem(JSString key, JSString value);
}

Future<String?> loadCachedSessionPayload() async {
  try {
    return _localStorage.getItem(_sessionCacheKey.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

Future<void> saveCachedSessionPayload(String payload) async {
  try {
    _localStorage.setItem(_sessionCacheKey.toJS, payload.toJS);
  } catch (_) {
    return;
  }
}

Future<void> clearCachedSessionPayload() async {
  try {
    _localStorage.removeItem(_sessionCacheKey.toJS);
  } catch (_) {
    return;
  }
}
