import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class HealthService {
  final ApiConfig _apiConfig;

  HealthService({ApiConfig? apiConfig}) : _apiConfig = apiConfig ?? ApiConfig();

  Future<Map<String, dynamic>> checkHealth() async {
    final response = await http.get(
      Uri.parse('${_apiConfig.baseUrl}/api/v1/health'),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend health check failed: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
