import 'account_settings_service.dart';
import 'supabase_service.dart';

class WishlistService {
  static Future<Set<String>> fetch(String owner) async {
    final result = <String>{};
    for (int offset = 0; ; offset += 500) {
      AccountSettingsService.checkOwner(owner);
      final rows = await SupabaseService.client!
          .from('user_wishlist')
          .select('stamp_id')
          .eq('user_id', owner)
          .order('stamp_id')
          .range(offset, offset + 499)
          .timeout(const Duration(seconds: 15));
      AccountSettingsService.checkOwner(owner);
      result.addAll(rows.map((row) => row['stamp_id'] as String));
      if (rows.length < 500) return result;
    }
  }

  static Future<void> importLocal(String owner, Set<String> ids) async {
    final values = ids.toList();
    for (int offset = 0; offset < values.length; offset += 500) {
      AccountSettingsService.checkOwner(owner);
      await SupabaseService.client!
          .rpc(
            'import_my_wishlist',
            params: {
              'p_ids': values.skip(offset).take(500).toList(),
              'p_owner': owner,
            },
          )
          .timeout(const Duration(seconds: 15));
      AccountSettingsService.checkOwner(owner);
    }
  }

  static Future<void> set(String owner, String id, bool wanted) async {
    AccountSettingsService.checkOwner(owner);
    final table = SupabaseService.client!.from('user_wishlist');
    if (wanted) {
      await table
          .upsert({
            'user_id': owner,
            'stamp_id': id,
          }, onConflict: 'user_id,stamp_id')
          .timeout(const Duration(seconds: 15));
    } else {
      await table
          .delete()
          .eq('user_id', owner)
          .eq('stamp_id', id)
          .timeout(const Duration(seconds: 15));
    }
    AccountSettingsService.checkOwner(owner);
  }
}
