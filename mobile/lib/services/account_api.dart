import 'dart:convert';
import 'package:http/http.dart' as http;

class AccountApi {
  final String baseUrl;
  String? token;

  AccountApi(this.baseUrl, {this.token});

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> account() => _get('/api/account');
  Future<Map<String, dynamic>> subscriptionStatus() => _get('/api/subscription/status');
  Future<Map<String, dynamic>> plan() => _get('/api/subscription/plan');

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _post('/api/account/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> checkoutAnnual() =>
      _post('/api/subscription/checkout', const {});

  Future<List<dynamic>> paymentHistory() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/subscription/payments'),
      headers: headers,
    );
    if (r.statusCode >= 300) {
      throw Exception(r.body);
    }
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) {
      throw Exception(body['error'] ?? r.body);
    }
    return body;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final r = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(data),
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) {
      throw Exception(body['error'] ?? r.body);
    }
    return body;
  }
}
