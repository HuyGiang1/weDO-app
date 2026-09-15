import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/data/models/auth_models.dart';
import 'profile_models.dart';

class ProfileApi {
  final Dio dio;

  ProfileApi(this.dio);

  Future<CurrentUser> updateProfile(UpdateProfileRequest request) async {
    try {
      final response = await dio.patch(
        '/api/v1/me/profile',
        data: request.toJson(),
      );
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object');
      return CurrentUser.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<CurrentUser> updateUsername(UpdateUsernameRequest request) async {
    try {
      final response = await dio.patch(
        '/api/v1/me/username',
        data: request.toJson(),
      );
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object');
      return CurrentUser.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PublicUserProfile> getPublicProfile(String userId) async {
    try {
      final response = await dio.get('/api/v1/users/$userId');
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object');
      return PublicUserProfile.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
