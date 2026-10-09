import 'package:shared_preferences/shared_preferences.dart';
import 'device_notification_dismissals.dart';
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

class NotificationPage {
  NotificationPage(this.items, this.nextOffset, this.hasMore);
  final List<MemberNotification> items;
  final int nextOffset;
  final bool hasMore;
}

class NotificationService {
  static final dismissed = DeviceNotificationDismissals(
    read: (owner) async {
      AccountSettingsService.checkOwner(owner);
      final prefs = await SharedPreferences.getInstance();
      AccountSettingsService.checkOwner(owner);
      return prefs.getStringList('hidden_notifications_device_v1_$owner') ?? [];
    },
    write: (owner, ids) async {
      AccountSettingsService.checkOwner(owner);
      final prefs = await SharedPreferences.getInstance();
      AccountSettingsService.checkOwner(owner);
      if (!await prefs.setStringList(
        'hidden_notifications_device_v1_$owner',
        ids,
      )) {
        throw StateError('기기에 저장하지 못했습니다.');
      }
      AccountSettingsService.checkOwner(owner);
    },
  );
  static Future<void> hide(
    String owner,
    String id, {
    bool hidden = true,
  }) async {
    AccountSettingsService.checkOwner(owner);
    await dismissed.setHidden(owner, id, hidden);
    AccountSettingsService.checkOwner(owner);
    changes.value++;
  }

  static final changes = ValueNotifier<int>(0);
  static Future<int> unread(String owner) async {
    AccountSettingsService.checkOwner(owner);
    final result = await SupabaseService.client!
        .rpc('my_unread_notification_count')
        .timeout(const Duration(seconds: 15));
    AccountSettingsService.checkOwner(owner);
    if ((result as num).toInt() == 0) return 0;
    final hidden = (await dismissed.ids(owner)).toList();
    var hiddenUnread = 0;
    for (var start = 0; start < hidden.length; start += 200) {
      final part = hidden.sublist(start, (start + 200).clamp(0, hidden.length));
      final visible = await SupabaseService.client!
          .from('member_notifications')
          .select('id')
          .inFilter('id', part)
          .timeout(const Duration(seconds: 15));
      AccountSettingsService.checkOwner(owner);
      if (visible.isEmpty) continue;
      final reads = await SupabaseService.client!
          .from('member_notification_reads')
          .select('notification_id')
          .eq('user_id', owner)
          .inFilter('notification_id', visible.map((r) => r['id']).toList())
          .timeout(const Duration(seconds: 15));
      AccountSettingsService.checkOwner(owner);
      final readIds = reads.map((r) => r['notification_id']).toSet();
      hiddenUnread += visible.where((r) => !readIds.contains(r['id'])).length;
    }
    AccountSettingsService.checkOwner(owner);
    return (result.toInt() - hiddenUnread).clamp(0, 2147483647);
  }

  static Future<NotificationPage> fetch(
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
    if (rows.isEmpty) return NotificationPage([], offset, false);
    final reads = await SupabaseService.client!
        .from('member_notification_reads')
        .select('notification_id')
        .eq('user_id', owner)
        .inFilter('notification_id', rows.map((r) => r['id']).toList())
        .timeout(const Duration(seconds: 15));
    AccountSettingsService.checkOwner(owner);
    final ids = reads.map((r) => r['notification_id']).toSet();
    final hidden = await dismissed.ids(owner);
    AccountSettingsService.checkOwner(owner);
    return NotificationPage(
      rows
          .where((r) => !hidden.contains(r['id']))
          .map((r) => MemberNotification(r, ids.contains(r['id'])))
          .toList(),
      offset + rows.length,
      rows.length == 25,
    );
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
