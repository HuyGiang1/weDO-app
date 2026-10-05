import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'home_models.dart';

abstract interface class HomeGateway {
  Future<HomeResponse> load();
}

class HomeApi implements HomeGateway {
  final Dio dio;
  HomeApi(this.dio);

  @override
  Future<HomeResponse> load() async {
    try {
      final response = await dio.get('/api/v1/home');
      if (response.data is! Map) {
        throw const FormatException('Expected home response object');
      }
      return HomeResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

class HomeRepository implements HomeGateway {
  final HomeApi api;
  HomeRepository(this.api);

  @override
  Future<HomeResponse> load() => api.load();
}
