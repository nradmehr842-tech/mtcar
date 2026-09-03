import 'dart:convert';
import 'package:http/http.dart' as http;

class EventsApi {
  final String baseUrl;
  final String token;

  EventsApi(this.baseUrl, this.token);

  Future<List<dynamic>> events(int deviceId, {int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/api/devices/$deviceId/events').replace(
      queryParameters: {'limit': '$limit'},
    );
    final r = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }
}
