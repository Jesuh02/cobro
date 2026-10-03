class CobroMapTiles {
  const CobroMapTiles._();

  /// OpenStreetMap tile server — gratuito, sin API key requerida.
  /// Política de uso: https://operations.osmfoundation.org/policies/tiles/
  static const String routeLightUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String attribution = '© OpenStreetMap contributors';
}
