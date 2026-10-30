import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';

class MediaUploadTarget {
  final String storageKey;
  final Uri uploadUrl;
  final DateTime expiresAt;
  final Map<String, String> requiredHeaders;

  const MediaUploadTarget({
    required this.storageKey,
    required this.uploadUrl,
    required this.expiresAt,
    required this.requiredHeaders,
  });

  factory MediaUploadTarget.fromJson(Map<String, dynamic> json) {
    final headers = json['requiredHeaders'];
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    final url = Uri.tryParse(json['uploadUrl'] as String? ?? '');
    final key = json['storageKey'];
    if (key is! String ||
        key.isEmpty ||
        url == null ||
        !url.hasScheme ||
        expiresAt == null ||
        headers is! Map) {
      throw const FormatException('Malformed upload target');
    }
    return MediaUploadTarget(
      storageKey: key,
      uploadUrl: url,
      expiresAt: expiresAt,
      requiredHeaders: headers.map((key, value) {
        if (key is! String || value is! String) {
          throw const FormatException('Malformed upload headers');
        }
        return MapEntry(key, value);
      }),
    );
  }
}

class MediaUploadService {
  static const maxImageBytes = 10 * 1024 * 1024;
  final Dio apiDio;
  final Dio directUploadDio;

  MediaUploadService({required this.apiDio, Dio? directUploadDio})
    : directUploadDio =
          directUploadDio ??
          Dio(
            BaseOptions(
              responseType: ResponseType.plain,
              headers: const {'Accept': '*/*'},
            ),
          );

  Future<String> uploadImage({
    required String category,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    String? contextId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    if (bytes.isEmpty) throw const MediaUploadException('invalid_file');
    try {
      final response = await apiDio.post<Map<String, dynamic>>(
        '/api/v1/uploads/presign',
        data: {
          'category': category,
          'fileName': fileName,
          'contentType': contentType,
          'fileSize': bytes.length,
          'contextId': ?contextId,
        },
      );
      final target = MediaUploadTarget.fromJson(response.data ?? const {});
      await directUploadDio.putUri<void>(
        target.uploadUrl,
        data: bytes,
        onSendProgress: onSendProgress,
        options: Options(
          headers: target.requiredHeaders,
          responseType: ResponseType.plain,
          contentType: target.requiredHeaders['Content-Type'],
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      return target.storageKey;
    } on DioException {
      throw const MediaUploadException('network_failure');
    } on FormatException {
      throw const MediaUploadException('invalid_upload_response');
    }
  }

  /// Reopenable stream: native videos are never buffered wholesale in Dart.
  Future<String> uploadStream({
    required String category,
    required String contextId,
    required String fileName,
    required String contentType,
    required int length,
    required Stream<List<int>> Function() openRead,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final response = await apiDio.post(
        '/api/v1/uploads/presign',
        data: {
          'category': category,
          'contextId': contextId,
          'fileName': fileName,
          'contentType': contentType,
          'fileSize': length,
        },
      );
      final target = MediaUploadTarget.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      await directUploadDio.putUri(
        target.uploadUrl,
        data: openRead(),
        onSendProgress: onSendProgress,
        options: Options(
          headers: {...target.requiredHeaders, 'Content-Length': length},
          contentType: target.requiredHeaders['Content-Type'],
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );
      return target.storageKey;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<String> authorizedReadUrl(String storageKey) async {
    try {
      final response = await apiDio.get<Map<String, dynamic>>(
        '/api/v1/media/access',
        queryParameters: {'storageKey': storageKey},
      );
      final url = response.data?['url'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException('Malformed media access response');
      }
      return url;
    } on DioException {
      throw const MediaUploadException('media_unavailable');
    } on FormatException {
      throw const MediaUploadException('media_unavailable');
    }
  }

  /// Re-authorize each original download. Never forward the session bearer to S3.
  Future<DownloadedMediaImage> downloadImage(String storageKey) async {
    final cancel = CancelToken();
    try {
      final url = await authorizedReadUrl(storageKey);
      final response = await directUploadDio.getUri<ResponseBody>(
        Uri.parse(url),
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status == 200,
        ),
      );
      final body = response.data;
      if (body == null || body.contentLength > maxImageBytes) {
        cancel.cancel();
        throw const MediaUploadException('invalid_file');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in body.stream) {
        if (bytes.length + chunk.length > maxImageBytes) {
          cancel.cancel();
          throw const MediaUploadException('invalid_file');
        }
        bytes.add(chunk);
      }
      return DownloadedMediaImage.fromBytes(bytes.takeBytes());
    } on DioException {
      throw const MediaUploadException('media_unavailable');
    }
  }
}

class DownloadedMediaImage {
  final Uint8List bytes;
  final String contentType;
  const DownloadedMediaImage._(this.bytes, this.contentType);

  factory DownloadedMediaImage.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > MediaUploadService.maxImageBytes) {
      throw const MediaUploadException('invalid_file');
    }
    bool matches(int offset, List<int> signature) =>
        bytes.length >= offset + signature.length &&
        signature.indexed.every((item) => bytes[offset + item.$1] == item.$2);
    final type = matches(0, [137, 80, 78, 71, 13, 10, 26, 10])
        ? 'image/png'
        : matches(0, [255, 216, 255])
        ? 'image/jpeg'
        : matches(0, [82, 73, 70, 70]) && matches(8, [87, 69, 66, 80])
        ? 'image/webp'
        : null;
    if (type == null) throw const MediaUploadException('invalid_file');
    return DownloadedMediaImage._(bytes, type);
  }
}

class MediaUploadException implements Exception {
  final String code;
  const MediaUploadException(this.code);
}
