import '../../moments/data/moment_models.dart';
import 'community_api.dart';

const reportReasons = {
  'SPAM': 'Nội dung rác',
  'HARASSMENT': 'Quấy rối',
  'INAPPROPRIATE_CONTENT': 'Nội dung không phù hợp',
  'SCAM': 'Lừa đảo',
  'OTHER': 'Lý do khác',
};
const reviewStatuses = {
  'OPEN': 'Chờ xử lý',
  'REVIEWED': 'Đã xử lý',
  'DISMISSED': 'Đã bác bỏ',
};
const reviewTypes = {
  'POST': 'Bài viết',
  'COMMENT': 'Bình luận',
  'USER': 'Người dùng',
};
const reviewActions = {
  'REMOVE': 'Gỡ nội dung',
  'RESTORE': 'Khôi phục nội dung',
  'DISMISS': 'Bác bỏ báo cáo',
  'RESOLVE': 'Hoàn tất xem xét',
};

class ModerationApi extends CommunityApi {
  ModerationApi(super.dio);
  Future<Json> access() =>
      call(() => dio.get('/api/v1/moderation/access'), (j) => j);
  Future<Json> queue({
    String? status,
    String? reason,
    String? type,
    String? before,
  }) => call(
    () => dio.get(
      '/api/v1/moderation/reports',
      queryParameters: {
        'status': ?status,
        'reason': ?reason,
        'type': ?type,
        'before': ?before,
      },
    ),
    (j) => j,
  );
  Future<Json> review(String id) =>
      call(() => dio.get('/api/v1/moderation/reports/$id'), (j) => j);
  Future<Json> decide(
    String id,
    String commandId,
    String action,
    String reason,
  ) => call(
    () => dio.post(
      '/api/v1/moderation/reports/$id/actions',
      data: {'clientRequestId': commandId, 'action': action, 'reason': reason},
    ),
    (j) => j,
  );
  Future<void> reportUser(String id, String reason) => command(
    () => dio.post('/api/v1/users/$id/reports', data: {'reason': reason}),
  );
  Future<void> reportComment(String id, String reason) => command(
    () => dio.post(
      '/api/v1/community/comments/$id/reports',
      data: {'reason': reason},
    ),
  );
  Future<void> block(String id) =>
      command(() => dio.post('/api/v1/users/$id/block'));
  Future<void> unblock(String id) =>
      command(() => dio.delete('/api/v1/users/$id/block'));
  Future<Json> blocked({int page = 0}) => call(
    () => dio.get(
      '/api/v1/me/blocked-users',
      queryParameters: {'page': page, 'size': 20},
    ),
    (j) => j,
  );
  Future<Json> hidden({String? before}) => call(
    () => dio.get(
      '/api/v1/community/hidden-posts',
      queryParameters: {'before': ?before},
    ),
    (j) => j,
  );
  Future<void> unhide(String id) =>
      command(() => dio.delete('/api/v1/community/posts/$id/hidden'));
}

/// Review-only media access is scoped to an authorized report; never a public bypass.
class ModerationEvidenceApi extends ModerationApi {
  final String reportId;
  ModerationEvidenceApi(super.dio, this.reportId);
  @override
  Future<String> mediaUrl(String id) => call(
    () => dio.get('/api/v1/moderation/reports/$reportId/media/$id/access'),
    (j) => j['url'] as String,
  );
}
