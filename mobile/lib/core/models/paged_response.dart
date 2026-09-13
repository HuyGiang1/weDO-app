/// Reusable generic pagination response wrapper aligning with Spring Data's PagedResponse DTO.
class PagedResponse<T> {
  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;

  const PagedResponse({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get isFirstPage => page == 0;
  bool get isLastPage => !hasNext;

  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Expected List for items in PagedResponse');
    }
    final items = rawItems
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Expected Map for item in PagedResponse');
          }
          return itemParser(Map<String, dynamic>.from(item));
        })
        .toList();

    return PagedResponse(
      items: items,
      page: _asInt(json['page'], 'page'),
      size: _asInt(json['size'], 'size'),
      totalElements: _asInt(json['totalElements'], 'totalElements'),
      totalPages: _asInt(json['totalPages'], 'totalPages'),
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }

  static int _asInt(dynamic value, String fieldName) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('Expected number for $fieldName in PagedResponse');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PagedResponse<T> &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          size == other.size &&
          totalElements == other.totalElements &&
          totalPages == other.totalPages &&
          hasNext == other.hasNext &&
          _listEquals(items, other.items);

  @override
  int get hashCode =>
      page.hashCode ^
      size.hashCode ^
      totalElements.hashCode ^
      totalPages.hashCode ^
      hasNext.hashCode ^
      items.length.hashCode;

  static bool _listEquals<E>(List<E> a, List<E> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
