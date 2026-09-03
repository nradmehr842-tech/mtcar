import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceModelsApi {
  final String baseUrl;
  final String token;

  DeviceModelsApi(this.baseUrl, this.token);

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<dynamic>> models() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/device-models'),
      headers: headers,
    );

    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> selectModel({
    required int deviceId,
    required int deviceModelId,
  }) async {
    final r = await http.patch(
      Uri.parse('$baseUrl/api/devices/$deviceId/model'),
      headers: headers,
      body: jsonEncode({'deviceModelId': deviceModelId}),
    );

    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) throw Exception(body['error'] ?? r.body);
    return body;
  }

  Future<Map<String, dynamic>> profile(int deviceId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/devices/$deviceId/profile'),
      headers: headers,
    );

    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) throw Exception(body['error'] ?? r.body);
    return body;
  }
}
