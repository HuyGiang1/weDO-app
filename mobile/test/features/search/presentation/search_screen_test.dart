import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';
import 'package:mobile/features/search/application/search_controller.dart'
    as search;
import 'package:mobile/features/search/data/search_api.dart';
import 'package:mobile/features/search/data/search_models.dart';
import 'package:mobile/features/search/presentation/search_screen.dart';

void main() {
  testWidgets('shows all five search categories within a phone-width layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dio = Dio();
    final gateway = _SearchGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(
          controller: search.SearchController(gateway),
          profileRepository: ProfileRepository(api: ProfileApi(dio)),
          groupRepository: GroupRepository(api: GroupApi(dio)),
          onOpenPerson: (_) {},
          onOpenGroup: (_) {},
          onOpenActivity: (_) {},
          onOpenConversation: (_) {},
        ),
      ),
    );

    for (final label in [
      'Tất cả',
      'Mọi người',
      'Nhóm',
      'Hoạt động',
      'Trò chuyện',
    ]) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final bounds = tester.getRect(finder);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(360));
    }
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));
    expect(gateway.queries, isEmpty);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));
    expect(gateway.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(gateway.queries, ['ab']);
  });
}

class _SearchGateway implements SearchGateway {
  final queries = <String>[];

  @override
  Future<SearchResponse> search(
    String query, {
    SearchCategory? category,
    int? page,
    int? size,
  }) async {
    queries.add(query);
    return SearchResponse(query: query);
  }
}
