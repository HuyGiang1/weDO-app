import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../media/data/media_upload_service.dart';
import '../../poll/data/poll_api.dart';
import 'moment_models.dart';

class MomentsApi {
  final Dio dio;
  final MediaUploadService uploads;
  MomentsApi(this.dio, {MediaUploadService? uploads})
    : uploads = uploads ?? MediaUploadService(apiDio: dio);
  static String commandId() => PollApi.newCommandId();
  Future<T> _call<T>(
    Future<Response> Function() call,
    T Function(Json) parse,
  ) async {
    try {
      final response = await call();
      return parse(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await dio.delete(path);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<MemoryPage<MomentPost>> feed(
    String group, {
    String? activity,
    String? before,
  }) => _call(
    () => dio.get(
      '/api/v1/groups/$group/moments',
      queryParameters: {'activityId': ?activity, 'before': ?before},
    ),
    (j) => MemoryPage.fromJson(j, MomentPost.fromJson),
  );
  Future<MomentPost> get(String id) =>
      _call(() => dio.get('/api/v1/moments/$id'), MomentPost.fromJson);
  Future<MomentPost> create(
    String group,
    String command,
    String caption,
    List<String> keys, {
    String? activity,
  }) => _call(
    () => dio.post(
      '/api/v1/groups/$group/moments',
      data: {
        'clientRequestId': command,
        'caption': caption,
        'mediaKeys': keys,
        'activityId': activity,
      },
    ),
    MomentPost.fromJson,
  );
  Future<MomentPost> edit(MomentPost post, String caption, String? activity) =>
      _call(
        () => dio.patch(
          '/api/v1/moments/${post.id}',
          data: {'caption': caption, 'activityId': activity},
        ),
        MomentPost.fromJson,
      );
  Future<void> delete(String id) => _delete('/api/v1/moments/$id');
  Future<MomentPost> react(String id, String? emoji) => _call(
    () => dio.put('/api/v1/moments/$id/reaction', data: {'emoji': emoji}),
    MomentPost.fromJson,
  );
  Future<MemoryPage<MemoryComment>> comments(String id, {String? before}) =>
      _call(
        () => dio.get(
          '/api/v1/moments/$id/comments',
          queryParameters: {'before': ?before},
        ),
        (j) => MemoryPage.fromJson(j, MemoryComment.fromJson),
      );
  Future<MemoryComment> comment(String id, String command, String text) =>
      _call(
        () => dio.post(
          '/api/v1/moments/$id/comments',
          data: {'clientRequestId': command, 'content': text},
        ),
        MemoryComment.fromJson,
      );
  Future<void> deleteComment(String id, String comment) =>
      _delete('/api/v1/moments/$id/comments/$comment');
  Future<MemoryPage<MemoryAlbum>> albums(
    String group, {
    String? activity,
    String? before,
  }) => _call(
    () => dio.get(
      '/api/v1/groups/$group/albums',
      queryParameters: {'activityId': ?activity, 'before': ?before},
    ),
    (j) => MemoryPage.fromJson(j, MemoryAlbum.fromJson),
  );
  Future<MemoryAlbum> album(String id) =>
      _call(() => dio.get('/api/v1/albums/$id'), MemoryAlbum.fromJson);
  Future<MemoryAlbum> saveAlbum(
    String group,
    String id,
    String name,
    String description, {
    String? activity,
    bool update = false,
  }) => _call(
    () => dio.request(
      '/api/v1/groups/$group/albums',
      data: {
        'clientRequestId': id,
        'activityId': activity,
        'name': name,
        'description': description,
      },
      options: Options(method: update ? 'PATCH' : 'POST'),
    ),
    MemoryAlbum.fromJson,
  );
  Future<void> deleteAlbum(String id) => _delete('/api/v1/albums/$id');
  Future<MemoryPage<MemoryMedia>> albumMedia(String id, {String? before}) =>
      _call(
        () => dio.get(
          '/api/v1/albums/$id/media',
          queryParameters: {'before': ?before},
        ),
        (j) => MemoryPage.fromJson(j, MemoryMedia.fromJson),
      );
  Future<MemoryAlbum> addItems(String album, List<String> media) => _call(
    () => dio.put('/api/v1/albums/$album/media', data: {'mediaIds': media}),
    MemoryAlbum.fromJson,
  );
  Future<MemoryAlbum> removeItem(String album, String media) => _call(
    () => dio.delete('/api/v1/albums/$album/media/$media'),
    MemoryAlbum.fromJson,
  );
  Future<String> mediaUrl(String id) => _call(
    () => dio.get('/api/v1/moment-media/$id/access'),
    (j) => j['url'] as String,
  );
  Future<String> upload(
    String group,
    XFile file, {
    void Function(int, int)? progress,
  }) async {
    final name = file.name.toLowerCase();
    final type = name.endsWith('.mp4')
        ? 'video/mp4'
        : name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : name.endsWith('.jpg') || name.endsWith('.jpeg')
        ? 'image/jpeg'
        : null;
    final length = await file.length();
    if (type == null ||
        length <= 0 ||
        length > (type.startsWith('video') ? 50 : 10) * 1024 * 1024) {
      throw const ApiException(
        statusCode: 400,
        message: 'Ảnh JPG/PNG/WebP tối đa 10 MB; video MP4 tối đa 50 MB.',
      );
    }
    return uploads.uploadStream(
      category: type.startsWith('video') ? 'MOMENT_VIDEO' : 'MOMENT_IMAGE',
      contextId: group,
      fileName: file.name,
      contentType: type,
      length: length,
      openRead: file.openRead,
      onSendProgress: progress,
    );
  }
}
