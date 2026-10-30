import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads only model/OS labels, never a device identifier. Android is the native
/// mobile target currently present in this repository.
class DeviceContextService {
  static const _channel = MethodChannel('parku/analytics_device_context');
  Future<Map<String, dynamic>>? _context;

  Future<Map<String, dynamic>> read() => _context ??= _read();

  Future<Map<String, dynamic>> _read() async {
    final fallback = <String, dynamic>{
      'device_model': 'unknown',
      'device_brand': 'unknown',
      'os_name': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'os_version': 'unknown',
      'device_info_available': false,
    };
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return fallback;
    }
    try {
      final data = await _channel
          .invokeMapMethod<String, dynamic>('read')
          .timeout(const Duration(seconds: 1));
      if (data == null) return fallback;
      String label(String key) {
        final value = data[key];
        return value is String && value.trim().isNotEmpty
            ? value.trim()
            : 'unknown';
      }

      final model = label('device_model');
      final version = label('os_version');
      return {
        'device_model': model,
        'device_brand': label('device_brand'),
        'os_name': 'android',
        'os_version': version,
        if (data['os_api_level'] is int) 'os_api_level': data['os_api_level'],
        'device_info_available': model != 'unknown' && version != 'unknown',
      };
    } catch (_) {
      // Telemetry still queues successfully on unsupported or older builds.
      return fallback;
    }
  }
}
