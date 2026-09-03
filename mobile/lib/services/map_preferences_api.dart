import 'dart:convert';
import 'package:http/http.dart' as http;

class MapPreferencesApi {
  final String baseUrl;
  final String token;

  MapPreferencesApi(this.baseUrl, this.token);

  Map<String,String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<Map<String,dynamic>> load() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/preferences/maps'),
      headers: headers,
    );
    final body = jsonDecode(r.body) as Map<String,dynamic>;
    if (r.statusCode >= 300) throw Exception(body['error'] ?? r.body);
    return body;
  }

  Future<Map<String,dynamic>> save({
    required String mapProvider,
    required String navigationProvider,
    String mapStyle = 'standard',
  }) async {
    final r = await http.put(
      Uri.parse('$baseUrl/api/preferences/maps'),
      headers: headers,
      body: jsonEncode({
        'mapProvider': mapProvider,
        'navigationProvider': navigationProvider,
        'mapStyle': mapStyle,
      }),
    );

    final body = jsonDecode(r.body) as Map<String,dynamic>;
    if (r.statusCode >= 300) throw Exception(body['error'] ?? r.body);
    return body;
  }
}
