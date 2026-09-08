import 'package:dio/dio.dart';

enum ApiTransportFailure { network, timeout, unexpected }

class ApiException implements Exception {
  final int? statusCode;
  final String? code;
  final String? message;
  final Map<String, String> fieldErrors;
  final String? requestId;
  final ApiTransportFailure transportFailure;

  const ApiException({
    this.statusCode,
    this.code,
    this.message,
    this.fieldErrors = const {},
    this.requestId,
    this.transportFailure = ApiTransportFailure.unexpected,
  });

  factory ApiException.fromDio(DioException exception) {
    final data = exception.response?.data;
    final envelope = data is Map ? Map<String, dynamic>.from(data) : null;
    final errors = <String, String>{};
    final rawErrors = envelope?['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((key, value) {
        if (key is String && value is String) errors[key] = value;
      });
    }
    return ApiException(
      statusCode: exception.response?.statusCode,
      code: envelope?['code'] is String ? envelope!['code'] as String : null,
      message: envelope?['message'] is String
          ? envelope!['message'] as String
          : null,
      requestId: envelope?['requestId'] is String
          ? envelope!['requestId'] as String
          : null,
      fieldErrors: errors,
      transportFailure: switch (exception.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => ApiTransportFailure.timeout,
        DioExceptionType.connectionError => ApiTransportFailure.network,
        _ => ApiTransportFailure.unexpected,
      },
    );
  }
}
