import 'package:flutter/services.dart';

class AlertBridge {
  static const channel = MethodChannel('mtcar/alerts');

  static Future<void> configure({
    required String trackerPhone,
    required String trackerPassword,
    required bool enabled,
    String carrierServiceNumber = '',
    String balanceCode = '',
  }) async {
    await channel.invokeMethod('saveSettings', {
      'trackerNumber': trackerPhone,
      'trackerPassword': trackerPassword,
      'enabled': enabled,
      'carrierServiceNumber': carrierServiceNumber,
      'balanceCode': balanceCode,
    });
  }

  static Future<void> requestPermissions() =>
      channel.invokeMethod('requestPermissions');

  static Future<void> sendStatusCheck() =>
      channel.invokeMethod('sendTrackerCommand', {'command': 'check'});

  static Future<void> requestSimBalance() =>
      channel.invokeMethod('sendTrackerCommand', {'command': 'balance'});

  static Future<void> enableExternalPowerAlarm() =>
      channel.invokeMethod('sendTrackerCommand', {'command': 'extpower_on'});

  static Future<void> enableVoiceMonitor() =>
      channel.invokeMethod('sendTrackerCommand', {'command': 'monitor_on'});

  static Future<void> restoreTrackerMode() =>
      channel.invokeMethod('sendTrackerCommand', {'command': 'tracker_mode'});

  static Future<void> armVehicle() =>
      channel.invokeMethod('sendTrackerCommand', {'command': 'arm'});

  static Future<void> disarmVehicle() =>
      channel.invokeMethod('sendTrackerCommand', {'command': 'disarm'});

  static Future<void> openTrackerDialer() =>
      channel.invokeMethod('openTrackerDialer');

  static Future<List<dynamic>> getLocalEvents() async {
    final result = await channel.invokeMethod<dynamic>('getEvents');
    return result is List ? List<dynamic>.from(result) : <dynamic>[];
  }

  static Future<void> clearLocalEvents() =>
      channel.invokeMethod('clearEvents');

  static Future<void> testCriticalAlarm() =>
      channel.invokeMethod('testCriticalAlarm');
}
