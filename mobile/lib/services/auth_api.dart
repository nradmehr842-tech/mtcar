import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApi {
  final String baseUrl;
  AuthApi(this.baseUrl);

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) => _post('/api/auth/login', {
        'username': username,
        'password': password,
      });

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String confirmPassword,
  }) => _post('/api/auth/register', {
        'username': username,
        'password': password,
        'confirmPassword': confirmPassword,
      });

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final r = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      decoded = {'error': r.body};
    }

    if (r.statusCode >= 300) {
      throw Exception(decoded['error'] ?? 'request_failed');
    }
    return decoded;
  }
}
