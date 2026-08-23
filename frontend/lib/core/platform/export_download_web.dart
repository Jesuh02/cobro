import 'dart:js_interop';

@JS('window.open')
external JSObject? _openWindow(
  JSString url,
  JSString target,
  JSString features,
);

Future<bool> abrirExportacionExcel(String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return false;
  }
  return _openWindow(
        uri.toString().toJS,
        '_blank'.toJS,
        'noopener,noreferrer'.toJS,
      ) !=
      null;
}
