import 'dart:convert';
import 'package:http/http.dart' as http;

class SimApi {
  final String baseUrl;
  final String token;

  SimApi(this.baseUrl, this.token);

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> status(int deviceId) =>
      _get('/api/devices/$deviceId/sim/status');

  Future<Map<String, dynamic>> refresh(int deviceId) =>
      _post('/api/devices/$deviceId/sim/refresh', const {});

  Future<Map<String, dynamic>> internetPackages(int deviceId) =>
      _get('/api/devices/$deviceId/sim/internet-packages');

  Future<Map<String, dynamic>> topup({
    required int deviceId,
    required int amountRial,
  }) => _post('/api/devices/$deviceId/sim/topup', {
    'amountRial': amountRial,
  });

  Future<Map<String, dynamic>> buyInternetPackage({
    required int deviceId,
    required String packageId,
    String? packageName,
  }) => _post('/api/devices/$deviceId/sim/buy-package', {
    'packageId': packageId,
    if (packageName != null) 'packageName': packageName,
  });

  Future<List<dynamic>> purchases(int deviceId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/devices/$deviceId/sim/purchases'),
      headers: headers,
    );
    if (r.statusCode >= 300) throw Exception(r.body);
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
