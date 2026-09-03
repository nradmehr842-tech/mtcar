import 'dart:convert';
import 'package:http/http.dart' as http;

class SupportApi {
  final String baseUrl;
  final String token;

  SupportApi(this.baseUrl, this.token);

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<dynamic>> tickets() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/support/tickets'),
      headers: headers,
    );
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> ticket(int id) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/support/tickets/$id'),
      headers: headers,
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) throw Exception(body['error'] ?? r.body);
    return body;
  }

  Future<Map<String, dynamic>> createTicket({
    required String subject,
    required String message,
    String category = 'general',
    String priority = 'normal',
    int? organizationId,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/support/tickets'),
      headers: headers,
      body: jsonEncode({
        'subject': subject,
        'message': message,
        'category': category,
        'priority': priority,
        if (organizationId != null) 'organizationId': organizationId,
      }),
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) throw Exception(body['error'] ?? r.body);
    return body;
  }

  Future<Map<String, dynamic>> sendMessage({
    required int ticketId,
    required String message,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/support/tickets/$ticketId/messages'),
      headers: headers,
      body: jsonEncode({'message': message}),
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) throw Exception(body['error'] ?? r.body);
    return body;
  }
}
