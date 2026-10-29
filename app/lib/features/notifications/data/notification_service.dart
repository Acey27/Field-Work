import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.params,
    required this.target,
    required this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      params: Map<String, dynamic>.from(
        json['params'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      target: json['target'] as String?,
      readAt: DateTime.tryParse('${json['read_at'] ?? ''}'),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }

  final String id;
  final String type;
  final Map<String, dynamic> params;
  final String? target;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;
}

/// The signed-in user's own notifications (CONTRACT.md sections 2.12, 4.15).
class NotificationService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AppNotification>> list({int limit = 50}) async {
    _requireConfigured();
    final value = await _client.rpc<List<dynamic>>(
      'get_my_notifications',
      params: {'p_limit': limit},
    );
    return value
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<int> unreadCount() async {
    final all = await list();
    return all.where((notification) => !notification.isRead).length;
  }

  Future<void> markRead(String id) async {
    _requireConfigured();
    await _client.rpc<Map<String, dynamic>>(
      'mark_notification_read',
      params: {'p_id': id},
    );
  }

  void _requireConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
  }
}
