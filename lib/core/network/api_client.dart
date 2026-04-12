import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final String apiKey;

  ApiClient({
    required this.baseUrl,
    required this.apiKey,
  });

  Future<http.Response> postJson(
      String path,
      Map<String, dynamic> body,
      ) async {
    final uri = Uri.parse('$baseUrl$path');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      },
      body: jsonEncode(body),
    );

    return response;
  }
}