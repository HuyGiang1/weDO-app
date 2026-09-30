import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/search/application/search_controller.dart';
import 'package:mobile/features/search/data/search_api.dart';
import 'package:mobile/features/search/data/search_models.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';

void main() {
  test(
    'does not call the API for queries shorter than two characters',
    () async {
      final gateway = _SearchGateway();
      final controller = SearchController(gateway);

      await controller.search(' x ', null);

      expect(gateway.calls, isEmpty);
      expect(controller.query, 'x');
      controller.dispose();
    },
  );

  test(
    'uses typed pagination and merges results without duplicate ids',
    () async {
      final gateway = _SearchGateway()
        ..responses.addAll([
          const SearchResponse(
            query: 'team',
            groups: SearchSection(
              items: [
                SearchGroup(
                  id: 'g1',
                  name: 'Team one',
                  status: GroupStatus.active,
                  avatarAvailable: false,
                ),
              ],
              hasMore: true,
            ),
          ),
          const SearchResponse(
            query: 'team',
            groups: SearchSection(
              items: [
                SearchGroup(
                  id: 'g1',
                  name: 'Team one',
                  status: GroupStatus.active,
                  avatarAvailable: false,
                ),
                SearchGroup(
                  id: 'g2',
                  name: 'Team two',
                  status: GroupStatus.archived,
                  avatarAvailable: false,
                ),
              ],
              hasMore: false,
            ),
          ),
        ]);
      final controller = SearchController(gateway);

      await controller.search('team', SearchCategory.groups);
      await controller.loadMore();

      expect(gateway.calls.map((call) => call.page), [0, 1]);
      expect(gateway.calls.every((call) => call.size == 20), isTrue);
      expect(controller.response!.groups!.items.map((group) => group.id), [
        'g1',
        'g2',
      ]);
      expect(controller.hasMore, isFalse);
      controller.dispose();
    },
  );

  test('ignores a late response from an older query', () async {
    final gateway = _PendingSearchGateway();
    final controller = SearchController(gateway);

    final oldRequest = controller.search('old query', null);
    final currentRequest = controller.search('current query', null);
    gateway.pending['current query']!.complete(
      const SearchResponse(query: 'current query'),
    );
    await currentRequest;
    gateway.pending['old query']!.complete(
      const SearchResponse(query: 'old query'),
    );
    await oldRequest;

    expect(controller.response?.query, 'current query');
    controller.dispose();
  });
}

class _SearchGateway implements SearchGateway {
  final calls = <_Call>[];
  final responses = <SearchResponse>[];

  @override
  Future<SearchResponse> search(
    String query, {
    SearchCategory? category,
    int? page,
    int? size,
  }) async {
    calls.add(_Call(query, category, page, size));
    return responses.removeAt(0);
  }
}

class _Call {
  final String query;
  final SearchCategory? category;
  final int? page;
  final int? size;
  const _Call(this.query, this.category, this.page, this.size);
}

class _PendingSearchGateway implements SearchGateway {
  final pending = <String, Completer<SearchResponse>>{};

  @override
  Future<SearchResponse> search(
    String query, {
    SearchCategory? category,
    int? page,
    int? size,
  }) {
    final completer = Completer<SearchResponse>();
    pending[query] = completer;
    return completer.future;
  }
}
