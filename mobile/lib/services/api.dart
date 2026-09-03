import 'dart:convert';
import 'package:http/http.dart' as http;

class FleetApi {
  final String baseUrl;
  final String token;

  FleetApi(this.baseUrl, this.token);

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<dynamic>> devices() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/devices'),
      headers: headers,
    );
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>?> position(int id) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/devices/$id/position'),
      headers: headers,
    );
    if (r.statusCode >= 300) throw Exception(r.body);
    final body = jsonDecode(r.body);
    return body == null ? null : Map<String, dynamic>.from(body);
  }

  Future<List<dynamic>> route(int id, DateTime from, DateTime to) async {
    final uri = Uri.parse('$baseUrl/api/devices/$id/route').replace(
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    final r = await http.get(uri, headers: headers);
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> engineStop(int id) =>
      _post('/api/devices/$id/engine-stop');

  Future<Map<String, dynamic>> engineResume(int id) =>
      _post('/api/devices/$id/engine-resume');

  Future<Map<String, dynamic>> _post(String path) async {
    final r = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: '{}',
    );
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) {
      throw Exception(decoded['message'] ?? decoded['error']);
    }
    return decoded;
  }
}
