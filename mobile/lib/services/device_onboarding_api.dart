import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceOnboardingApi {
  final String baseUrl;
  final String token;

  DeviceOnboardingApi(this.baseUrl, this.token);

  Future<Map<String, dynamic>> create({
    required String imei,
    required String trackerSimPhone,
    required String vehicleName,
    required String vehicleType,
    String? trackerSimOperator,
    int? deviceModelId,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/devices'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'imei': imei,
        'trackerSimPhone': trackerSimPhone,
        'vehicleName': vehicleName,
        'vehicleType': vehicleType,
        if (trackerSimOperator != null)
          'trackerSimOperator': trackerSimOperator,
        if (deviceModelId != null) 'deviceModelId': deviceModelId,
      }),
    );

    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 300) {
      throw Exception(body['error'] ?? r.body);
    }
    return body;
  }
}
