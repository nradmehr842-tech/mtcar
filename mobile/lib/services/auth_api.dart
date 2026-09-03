import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApi {
  final String baseUrl;
  AuthApi(this.baseUrl);

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) => _post('/api/auth/login', {
        'phone': phone,
        'password': password,
      });

  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
  }) => _post('/api/auth/register', {
        'phone': phone,
        'password': password,
      });

  Future<Map<String, dynamic>> verifyPhone({
    required String phone,
    required dynamic challengeId,
    required String code,
  }) => _post('/api/auth/verify-phone', {
        'phone': phone,
        'challengeId': challengeId,
        'code': code,
      });

  Future<Map<String, dynamic>> forgotPasswordRequest({
    required String phone,
  }) => _post('/api/auth/forgot-password/request', {
        'phone': phone,
      });

  Future<Map<String, dynamic>> forgotPasswordConfirm({
    required String phone,
    required dynamic challengeId,
    required String code,
    required String newPassword,
  }) => _post('/api/auth/forgot-password/confirm', {
        'phone': phone,
        'challengeId': challengeId,
        'code': code,
        'newPassword': newPassword,
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
