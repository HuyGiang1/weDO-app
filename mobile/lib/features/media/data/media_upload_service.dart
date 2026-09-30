import 'dart:typed_data';

import 'package:dio/dio.dart';

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

  Future<String> authorizedReadUrl(String storageKey) async {
    try {
      final response = await apiDio.get<Map<String, dynamic>>(
        '/api/v1/media/access',
        queryParameters: {'storageKey': storageKey},
      );
      final url = response.data?['url'];
      if (url is! String || Uri.tryParse(url)?.hasScheme != true) {
        throw const FormatException('Malformed media access response');
      }
      return url;
    } on DioException {
      throw const MediaUploadException('media_unavailable');
    }
  }
}

class MediaUploadException implements Exception {
  final String code;
  const MediaUploadException(this.code);
}
