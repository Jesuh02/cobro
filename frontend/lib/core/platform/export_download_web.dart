import 'dart:js_interop';

@JS('window.open')
external JSObject? _openWindow(JSString url, JSString target);

Future<bool> abrirExportacionExcel(String url) async {
  _openWindow(url.toJS, '_blank'.toJS);
  return true;
}
