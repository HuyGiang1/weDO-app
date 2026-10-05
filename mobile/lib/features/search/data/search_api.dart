import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'search_models.dart';

class SearchApi {
  final Dio dio;
  SearchApi(this.dio);

  Future<SearchResponse> search(
    String query, {
    SearchCategory? category,
    int? page,
    int? size,
  }) async {
    try {
      final parameters = <String, dynamic>{'q': query};
      if (category != null) {
        parameters['type'] = category.wireValue;
        parameters['page'] = page ?? 0;
        parameters['size'] = size ?? 20;
      }
      final response = await dio.get(
        '/api/v1/search',
        queryParameters: parameters,
      );
      if (response.data is! Map) {
        throw const FormatException('Expected search response object');
      }
      return SearchResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

abstract interface class SearchGateway {
  Future<SearchResponse> search(
    String query, {
    SearchCategory? category,
    int? page,
    int? size,
  });
}

class SearchRepository implements SearchGateway {
  final SearchApi api;
  SearchRepository(this.api);

  @override
  Future<SearchResponse> search(
    String query, {
    SearchCategory? category,
    int? page,
    int? size,
  }) => api.search(query, category: category, page: page, size: size);
}
