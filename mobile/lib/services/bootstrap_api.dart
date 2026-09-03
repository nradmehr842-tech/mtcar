import 'dart:convert';
import 'package:http/http.dart' as http;

class AppBootstrap {
  final DateTime serverTime;
  final Map<String, dynamic> user;
  final Map<String, dynamic> subscription;
  final List<dynamic> devices;
  final Map<String, dynamic> config;

  AppBootstrap({
    required this.serverTime,
    required this.user,
    required this.subscription,
    required this.devices,
    required this.config,
  });

  dynamic value(String key, [dynamic fallback]) {
    final node = config[key];
    if (node is Map<String, dynamic>) {
      return node['value'] ?? fallback;
    }
    return fallback;
  }
}

class BootstrapApi {
  final String baseUrl;
  final String token;

  BootstrapApi(this.baseUrl, this.token);

  Future<AppBootstrap> load() async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/app/bootstrap'),
      headers: {
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-cache',
      },
    );

    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) {
      throw Exception(body['error'] ?? r.body);
    }

    return AppBootstrap(
      serverTime: DateTime.parse(body['serverTime'] as String),
      user: Map<String, dynamic>.from(body['user'] as Map),
      subscription: Map<String, dynamic>.from(body['subscription'] as Map),
      devices: List<dynamic>.from(body['devices'] as List),
      config: Map<String, dynamic>.from(body['config'] as Map),
    );
  }
}
