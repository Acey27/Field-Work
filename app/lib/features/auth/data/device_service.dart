import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _deviceKey = 'device_uuid';
  final _uuid = const Uuid();

  Future<String> deviceUuid() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceKey);
    if (existing != null) return existing;
    final created = _uuid.v4();
    await preferences.setString(_deviceKey, created);
    return created;
  }

  Future<String> register({String label = 'Primary device'}) async {
    final response = await Supabase.instance.client.rpc<Map<String, dynamic>>(
      'register_device',
      params: {'p_device_uuid': await deviceUuid(), 'p_label': label},
    );
    return response['status'] as String;
  }

  Future<Map<String, dynamic>> context() async {
    final response = await Supabase.instance.client.rpc<Map<String, dynamic>>(
      'get_my_context',
      params: {'p_device_uuid': await deviceUuid()},
    );
    return response;
  }
}
