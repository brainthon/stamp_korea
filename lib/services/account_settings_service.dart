import 'supabase_service.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = false,
    this.newStamps = false,
    this.wishlistMatches = false,
    this.exchangeUpdates = false,
    this.events = false,
  });
  final bool enabled, newStamps, wishlistMatches, exchangeUpdates, events;
  factory NotificationPreferences.fromMap(Map<String, dynamic> map) =>
      NotificationPreferences(
        enabled: map['enabled'] == true,
        newStamps: map['new_stamps'] == true,
        wishlistMatches: map['wishlist_matches'] == true,
        exchangeUpdates: map['exchange_updates'] == true,
        events: map['events'] == true,
      );
  NotificationPreferences copyWith({
    bool? enabled,
    bool? newStamps,
    bool? wishlistMatches,
    bool? exchangeUpdates,
    bool? events,
  }) => NotificationPreferences(
    enabled: enabled ?? this.enabled,
    newStamps: newStamps ?? this.newStamps,
    wishlistMatches: wishlistMatches ?? this.wishlistMatches,
    exchangeUpdates: exchangeUpdates ?? this.exchangeUpdates,
    events: events ?? this.events,
  );
  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'new_stamps': newStamps,
    'wishlist_matches': wishlistMatches,
    'exchange_updates': exchangeUpdates,
    'events': events,
  };
}

class AccountSettingsService {
  static void checkOwner(String owner) {
    if (!SupabaseService.isLoggedIn ||
        SupabaseService.currentUser?.id != owner) {
      throw StateError('계정이 변경되었습니다.');
    }
  }

  static Future<NotificationPreferences> fetch(String owner) async {
    checkOwner(owner);
    final row = await SupabaseService.client!
        .from('notification_preferences')
        .select()
        .eq('user_id', owner)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    checkOwner(owner);
    return row == null
        ? const NotificationPreferences()
        : NotificationPreferences.fromMap(row);
  }

  static Future<void> save(
    String owner,
    NotificationPreferences settings,
  ) async {
    checkOwner(owner);
    await SupabaseService.client!
        .from('notification_preferences')
        .upsert({
          'user_id': owner,
          ...settings.toMap(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('user_id')
        .single()
        .timeout(const Duration(seconds: 15));
    checkOwner(owner);
  }

  static Future<String> saveNickname(String owner, String nickname) async {
    checkOwner(owner);
    final result = await SupabaseService.client!
        .rpc('set_my_nickname', params: {'p_nickname': nickname.trim()})
        .timeout(const Duration(seconds: 15));
    checkOwner(owner);
    return result as String;
  }
}
