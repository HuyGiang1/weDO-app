import 'package:flutter/foundation.dart';

import '../data/search_api.dart';
import '../data/search_models.dart';

class SearchController extends ChangeNotifier {
  static const int pageSize = 20;

  final SearchGateway repository;
  SearchController(this.repository);

  String query = '';
  SearchCategory? category;
  SearchResponse? response;
  Object? error;
  bool loading = false;
  bool loadingMore = false;
  int _page = 0;
  int _generation = 0;
  bool _disposed = false;

  bool get hasMore => response?.section(category)?.hasMore ?? false;

  void prepare(String value, SearchCategory? selectedCategory) {
    _generation++;
    query = value.trim();
    category = selectedCategory;
    response = null;
    error = null;
    loading = false;
    loadingMore = false;
    _page = 0;
    notifyListeners();
  }

  Future<void> search(String value, SearchCategory? selectedCategory) async {
    prepare(value, selectedCategory);
    final generation = _generation;
    if (query.length < 2) return;
    loading = true;
    notifyListeners();
    try {
      final result = await repository.search(
        query,
        category: category,
        page: category == null ? null : 0,
        size: category == null ? null : pageSize,
      );
      if (!_isCurrent(generation)) return;
      response = result;
    } catch (exception) {
      if (!_isCurrent(generation)) return;
      error = exception;
    } finally {
      if (_isCurrent(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final selected = category;
    if (selected == null ||
        loading ||
        loadingMore ||
        !hasMore ||
        query.length < 2) {
      return;
    }
    final generation = _generation;
    loadingMore = true;
    notifyListeners();
    final nextPage = _page + 1;
    try {
      final result = await repository.search(
        query,
        category: selected,
        page: nextPage,
        size: pageSize,
      );
      if (!_isCurrent(generation)) return;
      response = _merge(response!, result, selected);
      _page = nextPage;
    } catch (exception) {
      if (_isCurrent(generation)) error = exception;
    } finally {
      if (_isCurrent(generation)) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  SearchResponse _merge(
    SearchResponse current,
    SearchResponse incoming,
    SearchCategory selected,
  ) => switch (selected) {
    SearchCategory.people => SearchResponse(
      query: current.query,
      people: SearchSection<SearchPerson>(
        items: _mergeItems(
          current.people!,
          incoming.people!,
          (item) => item.id,
        ),
        hasMore: incoming.people!.hasMore,
      ),
    ),
    SearchCategory.groups => SearchResponse(
      query: current.query,
      groups: SearchSection<SearchGroup>(
        items: _mergeItems(
          current.groups!,
          incoming.groups!,
          (item) => item.id,
        ),
        hasMore: incoming.groups!.hasMore,
      ),
    ),
    SearchCategory.activities => SearchResponse(
      query: current.query,
      activities: SearchSection<SearchActivity>(
        items: _mergeItems(
          current.activities!,
          incoming.activities!,
          (item) => item.id,
        ),
        hasMore: incoming.activities!.hasMore,
      ),
    ),
    SearchCategory.conversations => SearchResponse(
      query: current.query,
      conversations: SearchSection<SearchConversation>(
        items: _mergeItems(
          current.conversations!,
          incoming.conversations!,
          (item) => item.id,
        ),
        hasMore: incoming.conversations!.hasMore,
      ),
    ),
  };

  List<T> _mergeItems<T>(
    SearchSection<T> current,
    SearchSection<T> incoming,
    String Function(T) idOf,
  ) {
    final seen = <String>{};
    final merged = <T>[];
    for (final item in [...current.items, ...incoming.items]) {
      if (seen.add(idOf(item))) merged.add(item);
    }
    return merged;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
