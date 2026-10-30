import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../moments/data/moment_models.dart';
import '../../moments/data/moments_api.dart';
import 'recruitment_models.dart';

class CommunityPost {
  final RecruitmentView? recruitment;
  final String id, caption, visibility;
  final String? groupId, reaction;
  final MemoryAuthor author;
  final DateTime created;
  final List<MemoryMedia> media;
  final int reactions, comments;
  final MemoryPermissions permissions;
  CommunityPost(Json j)
    : recruitment = j['recruitment'] == null
          ? null
          : RecruitmentView(Map<String, dynamic>.from(j['recruitment'] as Map)),
      id = j['id'] as String,
      caption = j['caption'] as String,
      visibility = j['visibility'] as String,
      groupId = j['groupId'] as String?,
      reaction = j['myReaction'] as String?,
      author = MemoryAuthor.fromJson(
        Map<String, dynamic>.from(j['author'] as Map),
      ),
      created = DateTime.parse(j['createdAt'] as String),
      media = (j['media'] as List)
          .map((v) => MemoryMedia.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList(),
      reactions = (j['reactionCount'] as num).toInt(),
      comments = (j['commentCount'] as num).toInt(),
      permissions = MemoryPermissions.fromJson(
        Map<String, dynamic>.from(j['permissions'] as Map),
      );
}

const communityVisibility = {
  'PUBLIC': 'Công khai',
  'FRIENDS_OF_FRIENDS': 'Bạn của bạn bè',
  'FRIENDS': 'Bạn bè',
  'GROUP_ONLY': 'Trong nhóm',
};

/// Reuses R4's signed upload stream and image renderer; REST authorization stays
/// in Community rather than borrowing a private group or fake Activity.
class CommunityApi extends MomentsApi {
  CommunityApi(super.dio, {super.uploads});
  Future<T> call<T>(
    Future<Response> Function() request,
    T Function(Json) parse,
  ) async {
    try {
      return parse(Map<String, dynamic>.from((await request()).data as Map));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> command(Future<Response> Function() request) async {
    try {
      await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<String> viewer() =>
      call(() => dio.get('/api/v1/me'), (j) => j['id'] as String);
  Future<MemoryPage<CommunityPost>> posts(
    String mode, {
    String? author,
    String? before,
  }) => call(
    () => dio.get(
      '/api/v1/community/posts',
      queryParameters: {'feed': mode, 'authorId': ?author, 'before': ?before},
    ),
    (j) => MemoryPage.fromJson(j, CommunityPost.new),
  );
  Future<List<CommunityPost>> refreshPosts(String mode, List<String> ids, {String? author}) => call(
    () => dio.post('/api/v1/community/posts/refresh', data: {'feed': mode, 'authorId': ?author, 'ids': ids}),
    (j) => MemoryPage.fromJson(j, CommunityPost.new).items,
  );
  Future<CommunityPost> post(String id) =>
      call(() => dio.get('/api/v1/community/posts/$id'), CommunityPost.new);
  Future<CommunityPost> publish(
    String id,
    String caption,
    String visibility,
    String? group,
    List<String> keys,
  ) => call(
    () => dio.post(
      '/api/v1/community/posts',
      data: {
        'clientRequestId': id,
        'caption': caption,
        'visibility': visibility,
        'groupId': group,
        'mediaKeys': keys,
      },
    ),
    CommunityPost.new,
  );
  Future<CommunityPost> updatePost(
    CommunityPost p,
    String caption,
    String visibility,
    String? group,
  ) => call(
    () => dio.patch(
      '/api/v1/community/posts/${p.id}',
      data: {'caption': caption, 'visibility': visibility, 'groupId': group},
    ),
    CommunityPost.new,
  );
  Future<void> remove(String id) =>
      command(() => dio.delete('/api/v1/community/posts/$id'));
  Future<CommunityPost> reactionTo(String id, String? emoji) => call(
    () =>
        dio.put('/api/v1/community/posts/$id/reaction', data: {'emoji': emoji}),
    CommunityPost.new,
  );
  Future<MemoryPage<MemoryComment>> postComments(String id, {String? before}) =>
      call(
        () => dio.get(
          '/api/v1/community/posts/$id/comments',
          queryParameters: {'before': ?before},
        ),
        (j) => MemoryPage.fromJson(j, MemoryComment.fromJson),
      );
  Future<void> addPostComment(String id, String commandId, String text) =>
      command(
        () => dio.post(
          '/api/v1/community/posts/$id/comments',
          data: {'clientRequestId': commandId, 'content': text},
        ),
      );
  Future<void> removeComment(String id, String comment) => command(
    () => dio.delete('/api/v1/community/posts/$id/comments/$comment'),
  );
  Future<void> hide(String id) =>
      command(() => dio.put('/api/v1/community/posts/$id/hidden'));
  Future<void> report(String id, String reason) => command(
    () => dio.post(
      '/api/v1/community/posts/$id/reports',
      data: {'reason': reason},
    ),
  );
  @override
  Future<String> mediaUrl(String id) => call(
    () => dio.get('/api/v1/community/media/$id/access'),
    (j) => j['url'] as String,
  );
  Future<String> uploadPhoto(
    String viewer,
    XFile file, {
    void Function(int, int)? progress,
  }) async {
    final name = file.name.toLowerCase();
    final type = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : name.endsWith('.jpg') || name.endsWith('.jpeg')
        ? 'image/jpeg'
        : null;
    final size = await file.length();
    if (type == null || size <= 0 || size > 10 * 1024 * 1024) {
      throw const ApiException(
        statusCode: 400,
        message: 'Chọn ảnh JPG/PNG/WebP tối đa 10 MB.',
      );
    }
    return uploads.uploadStream(
      category: 'COMMUNITY_IMAGE',
      contextId: viewer,
      fileName: file.name,
      contentType: type,
      length: size,
      openRead: file.openRead,
      onSendProgress: progress,
    );
  }

  Future<List<(String, String)>> writableGroups() async {
    try {
      final j =
          (await dio.get(
                '/api/v1/groups',
                queryParameters: {'status': 'ACTIVE', 'size': 100},
              )).data
              as Map;
      return (j['items'] as List)
          .map((g) => (g['id'] as String, g['name'] as String))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
