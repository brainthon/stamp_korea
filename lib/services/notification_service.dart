import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'account_settings_service.dart';

class MemberNotification {
  MemberNotification(Map<String, dynamic> row, this.read)
    : id = row['id'] as String,
      kind = row['kind'] as String,
      title = row['title'] as String,
      body = row['body'] as String,
      date = DateTime.parse(row['created_at'] as String).toLocal();
  final String id, kind, title, body;
  final DateTime date;
  bool read;
  String get category => switch (kind) {
    'announcement' => '공지',
    'new_stamp' || 'wishlist' => '수집',
    'exchange' => '교환',
    _ => '혜택',
  };
}

class NotificationService {
  static final changes = ValueNotifier<int>(0);
  static Future<int> unread(String owner) async {
    AccountSettingsService.checkOwner(owner);
    final result = await SupabaseService.client!
        .rpc('my_unread_notification_count')
        .timeout(const Duration(seconds: 15));
    AccountSettingsService.checkOwner(owner);
    return (result as num).toInt();
  }

  static Future<List<MemberNotification>> fetch(
    String owner,
    String category,
    int offset,
  ) async {
    AccountSettingsService.checkOwner(owner);
    var query = SupabaseService.client!.from('member_notifications').select();
    final kinds = switch (category) {
      '공지' => ['announcement'],
      '수집' => ['new_stamp', 'wishlist'],
      '교환' => ['exchange'],
      '혜택' => ['event'],
      _ => <String>[],
    };
    if (kinds.isNotEmpty) query = query.inFilter('kind', kinds);
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + 24)
        .timeout(const Duration(seconds: 15));
    AccountSettingsService.checkOwner(owner);
    if (rows.isEmpty) return [];
    final reads = await SupabaseService.client!
        .from('member_notification_reads')
        .select('notification_id')
        .eq('user_id', owner)
        .inFilter('notification_id', rows.map((r) => r['id']).toList())
        .timeout(const Duration(seconds: 15));
    AccountSettingsService.checkOwner(owner);
    final ids = reads.map((r) => r['notification_id']).toSet();
    return rows
        .map((r) => MemberNotification(r, ids.contains(r['id'])))
        .toList();
  }

  static Future<void> markRead(String owner, String id) async {
    AccountSettingsService.checkOwner(owner);
    try {
      await SupabaseService.client!
          .from('member_notification_reads')
          .insert({'user_id': owner, 'notification_id': id})
          .timeout(const Duration(seconds: 15));
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
    AccountSettingsService.checkOwner(owner);
    changes.value++;
  }
}
