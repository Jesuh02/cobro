import '../../core/utils/json_utils.dart';

class PaginaDatos<T> {
  const PaginaDatos({
    required this.items,
    required this.hasMore,
    this.nextOffset,
  });

  factory PaginaDatos.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemBuilder,
  ) {
    return PaginaDatos<T>(
      items: parseJsonList(json['items']).map(itemBuilder).toList(growable: false),
      hasMore: json['hasMore'] as bool? ?? false,
      nextOffset: parseJsonIntNullable(json['nextOffset']),
    );
  }

  final List<T> items;
  final bool hasMore;
  final int? nextOffset;
}
