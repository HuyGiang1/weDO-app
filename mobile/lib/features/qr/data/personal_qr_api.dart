import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../profile/data/profile_models.dart';
import 'personal_qr.dart';

class PersonalQrApi {
  final Dio dio;

  PersonalQrApi(this.dio);

  Future<PersonalQr> getPersonalQr() async {
    try {
      final response = await dio.get('/api/v1/me/qr');
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object');
      return PersonalQr.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PublicUserProfile> resolveQr(String deepLink) async {
    try {
      final response = await dio.post(
        '/api/v1/users/qr/resolve',
        data: <String, Object?>{'deepLink': deepLink.trim()},
      );
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object');
      return PublicUserProfile.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
