class CobroMapTiles {
  const CobroMapTiles._();

  /// Token de Jawg Maps inyectado en compilación:
  ///   flutter run  --dart-define=JAWG_ACCESS_TOKEN=<tu_token>
  ///   flutter build web --dart-define=JAWG_ACCESS_TOKEN=<tu_token>
  ///
  /// Obtén tu token gratuito en: https://www.jawg.io/lab/access-tokens
  static const String _token = String.fromEnvironment('JAWG_ACCESS_TOKEN');

  /// Estilo claro: jawg-streets (similar a CartoDB Voyager).
  static String get routeLightUrlTemplate =>
      'https://tile.jawg.io/jawg-streets/{z}/{x}/{y}.png?access-token=$_token';

  /// Estilo oscuro: jawg-dark.
  static String get routeDarkUrlTemplate =>
      'https://tile.jawg.io/jawg-dark/{z}/{x}/{y}.png?access-token=$_token';

  static const String attribution =
      '© Jawg Maps © OpenStreetMap contributors';
}
