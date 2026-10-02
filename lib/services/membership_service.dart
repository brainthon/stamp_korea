import '../models/membership.dart';
import 'supabase_service.dart';

class MembershipService {
  static Future<Membership> fetch() async {
    final client = SupabaseService.client;
    if (client == null || SupabaseService.currentUser == null) {
      return const Membership(
        effectivePlan: 'free',
        subscriptionStatus: 'inactive',
      );
    }
    final json = await client
        .rpc('get_my_membership')
        .timeout(const Duration(seconds: 15));
    return Membership.fromJson(Map<String, dynamic>.from(json));
  }
}
