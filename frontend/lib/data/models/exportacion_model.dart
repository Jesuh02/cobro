import '../../core/utils/json_utils.dart';

class ExportacionExcel {
  const ExportacionExcel({
    required this.archivo,
    required this.key,
    required this.url,
    required this.filas,
    required this.generadoEn,
    required this.vistaPrevia,
  });

  factory ExportacionExcel.fromJson(Map<String, dynamic> json) {
    return ExportacionExcel(
      archivo: json['archivo'] as String,
      key: json['key'] as String? ?? '',
      url: json['url'] as String,
      filas: parseJsonInt(json['filas']),
      generadoEn: parseJsonDateTime(json['generadoEn']),
      vistaPrevia: ExportacionVistaPrevia.fromJson(json['vistaPrevia']),
    );
  }

  final String archivo;
  final String key;
  final String url;
  final int filas;
  final DateTime? generadoEn;
  final ExportacionVistaPrevia vistaPrevia;
}

class ExportacionVistaPrevia {
  const ExportacionVistaPrevia({
    required this.columnas,
    required this.filas,
  });

  factory ExportacionVistaPrevia.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const ExportacionVistaPrevia(
        columnas: <String>[],
        filas: <List<Object?>>[],
      );
    }

    final Object? columnasRaw = json['columnas'];
    final Object? filasRaw = json['filas'];

    return ExportacionVistaPrevia(
      columnas: columnasRaw is List<dynamic>
          ? columnasRaw.map((Object? value) => value.toString()).toList()
          : const <String>[],
      filas: filasRaw is List<dynamic>
          ? filasRaw
              .whereType<List<dynamic>>()
              .map((List<dynamic> fila) => List<Object?>.from(fila))
              .toList()
          : const <List<Object?>>[],
    );
  }

  final List<String> columnas;
  final List<List<Object?>> filas;
}

