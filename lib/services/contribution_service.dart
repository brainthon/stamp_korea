import 'account_settings_service.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

Uint8List prepareContribution(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('사진을 읽지 못했어요.');
  final sized =
      decoded.width > 1000 || decoded.height > 1000
          ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 1000 : null,
            height: decoded.height > decoded.width ? 1000 : null,
          )
          : decoded;
  final result = Uint8List.fromList(img.encodeJpg(sized, quality: 80));
  if (result.length > 1048576) throw StateError('사진 용량이 너무 커요.');
  return result;
}

class ContributionService {
  static const bucket = 'recognition-contributions';
  static SupabaseClient get client => SupabaseService.client!;
  static bool get isAdmin =>
      client.auth.currentUser?.appMetadata['stamp_admin'] == true;
  static Future<void> submit(
    Uint8List photo,
    String stampId,
    bool training, {
    String? recognitionId,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('로그인이 필요해요.');
    final bytes = await compute(prepareContribution, photo);
    AccountSettingsService.checkOwner(user.id);
    final random = Random.secure();
    final hex = List.generate(32, (_) => random.nextInt(16).toRadixString(16));
    hex[12] = '4';
    hex[16] = (8 + random.nextInt(4)).toRadixString(16);
    final h = hex.join();
    final id =
        '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
    final path = '${user.id}/$id.jpg';
    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    try {
      AccountSettingsService.checkOwner(user.id);
      await client.from('photo_contributions').insert({
        'recognition_run_id': recognitionId,
        'id': id,
        'user_id': user.id,
        'stamp_id': stampId,
        'image_path': path,
        'reference_consent': true,
        'training_consent': training,
        'consent_version': '2026-09-30-v1',
      });
    } catch (_) {
      try {
        await client.storage.from(bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> withdraw(Map<String, dynamic> row) async {
    await client.from('photo_contributions').delete().eq('id', row['id']);
    await client.storage.from(bucket).remove([row['image_path'] as String]);
  }
}
