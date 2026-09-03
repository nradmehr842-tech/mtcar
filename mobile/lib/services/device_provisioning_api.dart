import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceProvisioningApi {
  final String baseUrl;
  final String token;

  DeviceProvisioningApi(this.baseUrl, this.token);

  Future<Map<String, dynamic>> plan({
    required int deviceModelId,
    required String trackerPassword,
    required String apn,
    String? gprsUser,
    String? gprsPassword,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/device-models/$deviceModelId/provisioning-plan'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'trackerPassword': trackerPassword,
        'apn': apn,
        'gprsUser': gprsUser ?? '',
        'gprsPassword': gprsPassword ?? '',
      }),
    );

    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) throw Exception(body['error'] ?? r.body);
    return body;
  }
}
