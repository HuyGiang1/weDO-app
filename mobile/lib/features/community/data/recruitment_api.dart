import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../activity/data/activity_api.dart';
import '../../moments/data/moment_models.dart';
import 'community_api.dart';

class RecruitmentApi extends CommunityApi {
  RecruitmentApi(super.dio);
  Future<List<Json>> list(Future<Response> Function() call) async {
    try {
      return ((await call()).data as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Json>> options() =>
      list(() => dio.get('/api/v1/community/recruitment-options'));
  Future<List<(String, String)>> activities(String group) async {
    final result = <(String, String)>[];
    int index = 0;
    while (true) {
      final page = await ActivityApi(dio).list(group, page: index++, size: 100);
      for (final a in page.items) {
        if (!['CANCELLED', 'COMPLETED'].contains(a.status.name.toUpperCase())) {
          result.add((a.id, a.title));
        }
      }
      if (!page.hasNext) break;
    }
    return result;
  }

  Future<CommunityPost> createRecruitment(Json data) => call(
    () => dio.post('/api/v1/community/recruitments', data: data),
    CommunityPost.new,
  );
  Future<MemoryPage<CommunityPost>> discover({
    String keyword = '',
    String tag = '',
    String location = '',
    DateTime? from,
    DateTime? to,
    String? before,
  }) => call(
    () => dio.get(
      '/api/v1/community/recruitments',
      queryParameters: {
        'keyword': keyword,
        'tag': tag,
        'location': location,
        'from': ?from?.toUtc().toIso8601String(),
        'to': ?to?.toUtc().toIso8601String(),
        'before': ?before,
      },
    ),
    (j) => MemoryPage.fromJson(j, CommunityPost.new),
  );
  Future<void> join(String post) =>
      command(() => dio.post('/api/v1/community/recruitments/$post/join'));
  Future<void> cancelRequest(String post) =>
      command(() => dio.post('/api/v1/community/recruitments/$post/cancel'));
  Future<void> closeRecruitment(String post) =>
      command(() => dio.post('/api/v1/community/recruitments/$post/close'));
  Future<List<Json>> requests(String post) =>
      list(() => dio.get('/api/v1/community/recruitments/$post/requests'));
  Future<void> resolve(String post, String request, bool approve) => command(
    () => dio.post(
      '/api/v1/community/recruitments/$post/requests/$request/${approve ? 'approve' : 'reject'}',
    ),
  );
}
