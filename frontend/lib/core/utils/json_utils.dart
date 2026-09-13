List<Map<String, dynamic>> parseJsonList(Object? value) {
  if (value is! List<dynamic>) {
    return const <Map<String, dynamic>>[];
  }
  return value.whereType<Map<String, dynamic>>().toList(growable: false);
}

double? parseNumero(String value) {
  final String normalized =
      value.trim().replaceAll(RegExp(r'[^0-9,.-]'), '').replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  final double? parsed = double.tryParse(normalized);
  if (parsed == null || parsed.isNaN || parsed.isInfinite) {
    return null;
  }
  return parsed;
}

double parseJsonDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return parseNumero(value) ?? 0;
  }
  return 0;
}

double? parseJsonDoubleNullable(Object? value) {
  if (value == null) {
    return null;
  }
  final double? parsed = value is num
      ? value.toDouble()
      : value is String
          ? parseNumero(value)
          : null;
  return parsed?.isFinite ?? false ? parsed : null;
}

int parseJsonInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

int? parseJsonIntNullable(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? parseJsonDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String formatJsonDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String formatJsonDateTimeUtc(DateTime value) {
  return value.toUtc().toIso8601String();
}

