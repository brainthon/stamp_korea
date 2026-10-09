import 'auth_flow.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stamp.dart';
import '../models/official_stamp.dart';

class UserProfile {
  final String id;
  final String email;
  final String nickname;
  final String? avatarUrl;
  final String collectorLevel;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatarUrl,
    this.collectorLevel = '새싹 수집가',
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      nickname: map['nickname']?.toString() ?? '우표 수집가',
      avatarUrl: map['avatar_url']?.toString(),
      collectorLevel: map['collector_level']?.toString() ?? '새싹 수집가',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SupabaseService {
  static const String defaultUrl = String.fromEnvironment('SUPABASE_URL');
  // 정식 Supabase anon public key
  static const String defaultKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static String get redirectUrl => authRedirectUrl(web: kIsWeb, base: Uri.base);
  static String? pendingAuthError;
  static String describeAuthError(Object error) =>
      authFailureMessage(error is AuthException ? error.code : null);
  static String? takeAuthError() {
    final message = pendingAuthError;
    pendingAuthError = null;
    return message;
  }

  static bool _isInitialized = false;
  static bool recoveryPending = false;
  static bool get isInitialized => _isInitialized;

  /// Supabase 클라이언트 초기화
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    pendingAuthError = kIsWeb ? authCallbackFailure(Uri.base) : null;
    try {
      const url = defaultUrl;
      const key = defaultKey;

      if (url.isNotEmpty && key.isNotEmpty) {
        await Supabase.initialize(
          url: url.trim(),
          publishableKey: key.trim(),
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
        _isInitialized = true;
        Supabase.instance.client.auth.onAuthStateChange.listen(
          (state) {
            if (state.event == AuthChangeEvent.signedIn) {
              pendingAuthError = null;
            }
            if (state.event == AuthChangeEvent.passwordRecovery) {
              recoveryPending = true;
            }
            if (state.event == AuthChangeEvent.signedOut) {
              recoveryPending = false;
            }
          },
          onError: (Object error) {
            pendingAuthError = describeAuthError(error);
            recoveryPending = false;
          },
        );
        return true;
      }
    } catch (_) {
      _isInitialized = false;
    }
    return false;
  }

  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    return Supabase.instance.client;
  }

  // ==================== [ 마스터 우표 카탈로그 클라우드 동기화 ] ====================

  /// 수파베이스 클라우드에서 마스터 우표 목록 가져오기
  static Future<List<Stamp>?> fetchMasterStamps() async {
    final sb = client;
    if (sb == null) return null;

    try {
      const pageSize = 1000;
      final official = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += pageSize) {
        final page = await sb
            .from('official_stamp_catalog')
            .select('data')
            .eq('source_verified', true)
            .order('id')
            .range(offset, offset + pageSize - 1);
        official.addAll(page.map((row) => Map<String, dynamic>.from(row)));
        if (page.length < pageSize) break;
      }
      if (official.isNotEmpty) {
        return official
            .map(
              (row) =>
                  OfficialStamp(
                    Map<String, dynamic>.from(row['data'] as Map),
                  ).toStamp(),
            )
            .toList();
      }
      final response = await sb
          .from('stamps')
          .select()
          .order('issue_year', ascending: true);
      final list =
          (response as List).map((row) {
            final map = row as Map<String, dynamic>;
            final vol = (map['issue_volume'] as num?)?.toInt() ?? 1000000;
            final rarityStr = map['rarity']?.toString().toLowerCase() ?? '';
            RarityTier tier = RarityTier.fromVolume(vol);
            if (rarityStr == 'ssr' || rarityStr == '국보급') tier = RarityTier.ssr;
            if (rarityStr == 'sr' || rarityStr == '명품급') tier = RarityTier.sr;
            if (rarityStr == 'r' || rarityStr == '우수품') tier = RarityTier.r;
            if (rarityStr == 'n' || rarityStr == '일반품') tier = RarityTier.n;

            final rawColors =
                (map['primary_colors'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                ['#111827', '#D97706'];
            final rawKeywords =
                (map['keywords'] as List?)?.map((e) => e.toString()).toList() ??
                [map['name']?.toString() ?? ''];

            return Stamp(
              id: map['id']?.toString() ?? '',
              name: map['name']?.toString() ?? '대한민국 우표',
              englishName:
                  map['english_name']?.toString() ?? 'Korean Postage Stamp',
              issueYear: (map['issue_year'] as num?)?.toInt() ?? 1988,
              issueDate: map['issue_date']?.toString() ?? '1988-01-01',
              issueVolume: vol,
              faceValue: map['face_value']?.toString() ?? '80원',
              category: map['category']?.toString() ?? '기념우표',
              theme: map['theme']?.toString() ?? '역사/인물',
              designer: map['designer']?.toString() ?? '우정사업본부',
              printer: map['printer']?.toString() ?? '한국조폐공사',
              rarity: tier,
              estimatedValue: map['estimated_value']?.toString() ?? '시세 확인 필요',
              description: map['description']?.toString() ?? '',
              historicalStory: map['historical_story']?.toString() ?? '',
              perforation: map['perforation']?.toString() ?? '13 x 13½',
              sizeMm: map['size_mm']?.toString() ?? '26 x 36 mm',
              primaryColors: rawColors,
              keywords: rawKeywords,
              visualSignature: 'sig_${map['id']}',
              imageUrl: map['image_url']?.toString(),
              illustrationSvgPlaceholder: 'vintage_crest',
            );
          }).toList();

      return list;
    } catch (_) {
      return null;
    }
  }

  // ==================== [ 회원 인증 및 소셜 로그인 ] ====================

  /// 현재 로그인된 사용자
  static User? get currentUser => client?.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  /// 인증 상태 변화 감지 스트림
  static Stream<AuthState>? get authStateChanges =>
      client?.auth.onAuthStateChange;

  /// 구글 계정으로 간편 로그인/회원가입
  static Future<bool> signInWithGoogle() async {
    final sb = client;
    if (sb == null) throw Exception('수파베이스 서비스가 연결되지 않았습니다.');
    await _requireProvider('google');

    return await sb.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  /// 카카오 계정으로 간편 로그인/회원가입
  static Future<bool> signInWithKakao() async {
    final sb = client;
    if (sb == null) throw Exception('수파베이스 서비스가 연결되지 않았습니다.');
    await _requireProvider('kakao');

    return await sb.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: redirectUrl,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  /// 기존 회원 ID에 인증 수단을 연결한다. 일반 로그인과 구분한다.
  static Future<bool> linkLoginIdentity(OAuthProvider provider) async {
    if (provider != OAuthProvider.kakao && provider != OAuthProvider.google) {
      throw const AuthException(
        'Unsupported identity',
        code: 'validation_failed',
      );
    }
    final sb = client;
    final owner = currentUser?.id;
    if (sb == null || owner == null) {
      throw const AuthException('Sign in required', code: 'session_not_found');
    }
    await _requireProvider(provider.name);
    if (currentUser?.id != owner) {
      throw const AuthException('Account changed', code: 'session_not_found');
    }
    return sb.auth.linkIdentity(
      provider,
      redirectTo: redirectUrl,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      queryParams:
          provider == OAuthProvider.google
              ? const {'prompt': 'select_account'}
              : const {'prompt': 'login'},
    );
  }

  static Future<Map<String, bool>> loginProviders() async {
    final response = await http
        .get(
          Uri.parse('${defaultUrl.trim()}/auth/v1/settings'),
          headers: {'apikey': defaultKey.trim()},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Auth settings unavailable');
    }
    final settings = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      for (final provider in ['kakao', 'google'])
        provider: authProviderEnabled(settings, provider),
    };
  }

  /// 이메일 회원가입
  static Future<void> _requireProvider(String provider) async {
    final response = await http
        .get(
          Uri.parse('${defaultUrl.trim()}/auth/v1/settings'),
          headers: {'apikey': defaultKey.trim()},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const AuthException(
        'Auth settings unavailable',
        code: 'auth_settings_unavailable',
      );
    }
    bool enabled;
    try {
      enabled = authProviderEnabled(
        jsonDecode(response.body) as Map<String, dynamic>,
        provider,
      );
    } catch (_) {
      throw const AuthException(
        'Auth settings unavailable',
        code: 'auth_settings_unavailable',
      );
    }
    if (!enabled) {
      throw AuthException(
        'Provider not configured',
        code: 'provider_disabled_$provider',
      );
    }
  }

  static Future<void> resendConfirmation(String email) async {
    final sb = client;
    if (sb == null) throw StateError('Auth not configured');
    await sb.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: redirectUrl,
    );
  }

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final sb = client;
    if (sb == null) throw Exception('수파베이스 서비스가 연결되지 않았습니다.');

    final response = await sb.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'nickname': nickname.trim()},
      emailRedirectTo: redirectUrl,
    );

    return response;
  }

  /// 이메일 로그인
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final sb = client;
    if (sb == null) throw Exception('수파베이스 서비스가 연결되지 않았습니다.');

    final response = await sb.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    return response;
  }

  /// 로그아웃
  static Future<void> signOut() async {
    final sb = client;
    if (sb != null) {
      await sb.auth.signOut(scope: SignOutScope.local);
    }
  }

  /// 비밀번호 재설정 이메일 발송
  static Future<void> resetPassword(String email) async {
    final sb = client;
    if (sb != null) {
      await sb.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectUrl,
      );
    }
  }

  /// 사용자 프로필 정보 조회
  static Future<UserProfile?> fetchProfile() async {
    final sb = client;
    final user = currentUser;
    if (sb == null || user == null) return null;

    try {
      final data =
          await sb.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data != null) {
        return UserProfile.fromMap(data);
      }

      final fallbackNick =
          user.userMetadata?['nickname']?.toString() ??
          user.userMetadata?['name']?.toString() ??
          user.userMetadata?['full_name']?.toString() ??
          user.email?.split('@').first ??
          '우표 수집가';

      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        nickname: fallbackNick,
        avatarUrl: user.userMetadata?['avatar_url']?.toString(),
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        nickname:
            user.userMetadata?['nickname']?.toString() ??
            user.userMetadata?['name']?.toString() ??
            user.userMetadata?['full_name']?.toString() ??
            '우표 수집가',
        avatarUrl: user.userMetadata?['avatar_url']?.toString(),
        createdAt: DateTime.now(),
      );
    }
  }

  // ==================== [ 저장소 및 사진 업로드 ] ====================

  /// Private object path; signed URLs are only temporary display values.
  static Future<String> uploadStampPhoto(
    Uint8List bytes,
    String stampId,
  ) async {
    final sb = client!;
    final owner = currentUser!.id;
    final path = '$owner/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await sb.storage
        .from('stamp-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return path;
  }

  static Future<String> photoUrl(String path) =>
      client!.storage.from('stamp-photos').createSignedUrl(path, 3600);

  static Future<List<CollectionItem>?> fetchCollections() async {
    final sb = client;
    final owner = currentUser?.id;
    if (sb == null || owner == null) return null;
    final rows = await sb
        .from('user_collections')
        .select()
        .eq('user_id', owner)
        .order('acquired_date', ascending: false)
        .timeout(const Duration(seconds: 15));
    return Future.wait(
      rows.map((row) async {
        final map = Map<String, dynamic>.from(row);
        final path = map['user_image_path'] as String?;
        if (path != null && path.startsWith('$owner/')) {
          map['user_image_url'] = await photoUrl(
            path,
          ).timeout(const Duration(seconds: 15));
        }
        return CollectionItem.fromMap(map);
      }),
    );
  }

  static Future<void> saveCollection(CollectionItem item) async {
    final owner = currentUser!.id;
    final map = item.toMap()..['user_id'] = owner;
    // Never persist expiring signed URLs or inline photos to the database.
    map['user_image_url'] = null;
    await client!.from('user_collections').upsert(map);
  }

  static Future<void> deleteCollection(String id) async {
    final owner = currentUser!.id;
    await client!
        .from('user_collections')
        .delete()
        .eq('id', id)
        .eq('user_id', owner);
  }
}
