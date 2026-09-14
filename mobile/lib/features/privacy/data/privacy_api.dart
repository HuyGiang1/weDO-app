import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'privacy_models.dart';

class PrivacyApi {
  final Dio dio;
  PrivacyApi(this.dio);

  Future<PrivacySettings> getPrivacySettings() async {
    try {
      final response = await dio.get('/api/v1/me/privacy');
      return _parse(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PrivacySettings> updatePrivacySettings(
    UpdatePrivacySettingsRequest request,
  ) async {
    try {
      final response = await dio.patch(
        '/api/v1/me/privacy',
        data: request.toJson(),
      );
      return _parse(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  PrivacySettings _parse(dynamic data) {
    if (data is! Map) throw const FormatException('Expected JSON object');
    return PrivacySettings.fromJson(Map<String, dynamic>.from(data));
  }
}
