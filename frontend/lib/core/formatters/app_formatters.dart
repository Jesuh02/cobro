import 'dart:math' as math;

import '../../data/models/catalogo_model.dart';
import '../utils/json_utils.dart';
export '../utils/json_utils.dart';

DateTime fechaHoraColombia([DateTime? value]) {
  return (value ?? DateTime.now()).toUtc().subtract(const Duration(hours: 5));
}

String nombreCajaMenorPorDefecto([DateTime? value]) {
  final DateTime colombia = fechaHoraColombia(value);
  return '${colombia.day.toString().padLeft(2, '0')}/'
      '${colombia.month.toString().padLeft(2, '0')}/'
      '${colombia.year.toString().padLeft(4, '0')} '
      '${colombia.hour.toString().padLeft(2, '0')}:'
      '${colombia.minute.toString().padLeft(2, '0')}';
}

String formatDateLabel(DateTime? value) {
  if (value == null) {
    return '-';
  }

  const List<String> meses = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  return '${value.day.toString().padLeft(2, '0')} '
      '${meses[value.month - 1]} ${value.year}';
}

String formatDateTimeLabel(DateTime? value) {
  if (value == null) {
    return '-';
  }

  final DateTime local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year.toString().padLeft(4, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String formatExportCellText(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is num) {
    return formatNumber(value.toDouble()).replaceAll('.', ',');
  }
  return value.toString();
}

String formatCreditsCount(int value) {
  return value == 1 ? '1 credito' : '$value creditos';
}

double roundMoney(double value, [int decimales = 2]) {
  final num factor = math.pow(10, decimales);
  return (value * factor).round() / factor;
}

String formatMoney(double value) {
  final bool negativo = value < 0;
  final double valorRedondeado = roundMoney(value.abs(), 2);
  final String raw = preciseDecimal(valorRedondeado);
  final List<String> partes = raw.split('.');
  final String entero = partes.first;
  final StringBuffer buffer = StringBuffer();

  for (int i = 0; i < entero.length; i++) {
    final int desdeFinal = entero.length - i;
    buffer.write(entero[i]);
    if (desdeFinal > 1 && desdeFinal % 3 == 1) {
      buffer.write('.');
    }
  }

  final String decimales = partes.length == 2 ? ',${partes.last}' : '';
  return '${negativo ? '-' : ''}\$${buffer.toString()}$decimales';
}

String etiquetaFrecuencia(FrecuenciaPago? frecuencia) {
  switch (frecuencia?.codigo.toUpperCase()) {
    case 'DIARIO':
      return 'diarias';
    case 'SEMANAL':
      return 'semanales';
    case 'QUINCENAL':
      return 'quincenales';
    case 'MENSUAL':
      return 'mensuales';
    default:
      return 'cada ${frecuencia?.diasIntervalo ?? 1} días';
  }
}

String formatNumber(double value) {
  if (value == 0) {
    return '0';
  }

  return '${value < 0 ? '-' : ''}${preciseDecimal(value.abs())}';
}

double parseMontoInput(String value) {
  final double? parsed = parseNumero(value);
  if (parsed == null || parsed <= 0) {
    throw const FormatException('Ingresa un monto mayor que cero');
  }
  return parsed;
}

double parsePorcentajeInput(String value) {
  final double? parsed = parseNumero(value);
  if (parsed == null || parsed < 0) {
    throw const FormatException('Ingresa un porcentaje válido');
  }
  return parsed;
}

int parseEnteroPositivoInput(String value) {
  final double? parsed = parseNumero(value);
  if (parsed == null || parsed <= 0) {
    throw const FormatException('Ingresa un plazo mayor que cero');
  }
  return math.max(1, parsed.round());
}

String preciseDecimal(double value) {
  if (value == 0 || value.isNaN || value.isInfinite) {
    return '0';
  }

  final String raw = value.toString().toLowerCase();
  if (!raw.contains('e')) {
    return quitarCerosDecimales(raw);
  }

  return quitarCerosDecimales(expandirNotacionCientifica(raw));
}

String expandirNotacionCientifica(String raw) {
  final List<String> partes = raw.split('e');
  final String mantisa = partes.first;
  final int exponente = int.parse(partes.last);
  final int punto = mantisa.indexOf('.');
  final int posicionDecimal = punto == -1 ? mantisa.length : punto;
  final String digitos = mantisa.replaceAll('.', '');
  final int nuevaPosicion = posicionDecimal + exponente;

  if (nuevaPosicion <= 0) {
    final String ceros = ''.padLeft(-nuevaPosicion, '0');
    return '0.$ceros$digitos';
  }

  if (nuevaPosicion >= digitos.length) {
    final String ceros = ''.padLeft(nuevaPosicion - digitos.length, '0');
    return '$digitos$ceros';
  }

  return '${digitos.substring(0, nuevaPosicion)}.'
      '${digitos.substring(nuevaPosicion)}';
}

String quitarCerosDecimales(String value) {
  if (!value.contains('.')) {
    return value;
  }

  var limpio = value;
  while (limpio.endsWith('0')) {
    limpio = limpio.substring(0, limpio.length - 1);
  }
  if (limpio.endsWith('.')) {
    limpio = limpio.substring(0, limpio.length - 1);
  }
  return limpio.isEmpty ? '0' : limpio;
}

