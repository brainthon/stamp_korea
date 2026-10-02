import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/account_settings_service.dart';
import '../services/supabase_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  late final String? owner = SupabaseService.currentUser?.id;
  final confirmation = TextEditingController();
  bool agreed = false, busy = false;
  String? error;
  @override
  void dispose() {
    confirmation.dispose();
    super.dispose();
  }

  Future<void> remove() async {
    if (owner == null || busy || !agreed || confirmation.text.trim() != '탈퇴') {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      AccountSettingsService.checkOwner(owner!);
      final token = SupabaseService.client!.auth.currentSession!.accessToken;
      final result = await SupabaseService.client!.functions
          .invoke(
            'delete-account',
            headers: {'Authorization': 'Bearer $token'},
            body: {'confirmation': '탈퇴'},
          )
          .timeout(const Duration(seconds: 90));
      if (result.status != 200 ||
          result.data is! Map ||
          result.data['ok'] != true) {
        throw StateError('삭제 결과를 확인하지 못했어요. 다시 로그인해 확인해 주세요.');
      }
      // Do not sign out a different account if the user switched during the request.
      if (SupabaseService.currentUser?.id == owner) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_stamp_wishlist_v2_$owner');
        await prefs.remove('user_stamp_collection_v2_$owner');
        if (SupabaseService.currentUser?.id == owner) {
          await SupabaseService.client!.auth.signOut(scope: SignOutScope.local);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('회원탈퇴가 완료되었습니다.')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error =
                  e is FunctionException && e.details is Map
                      ? e.details['error']?.toString() ?? '탈퇴 요청에 실패했어요.'
                      : '탈퇴 결과를 확인하지 못했어요. 다시 로그인해 계정 상태를 확인해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('회원탈퇴')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                '수집 기록이 삭제됩니다',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const Text(
                '계정 정보, 내 수집함, 위시리스트, 알림 설정과 읽음 기록, 판독 개선용으로 제공한 사진이 삭제됩니다. 삭제한 자료는 복구할 수 없습니다. 공식 우표 도감은 유지됩니다.',
                style: TextStyle(fontSize: 16, height: 1.7),
              ),
              const SizedBox(height: 16),
              const Text('관리자 계정이나 구독 확인이 필요한 계정은 바로 탈퇴할 수 없습니다.'),
              const SizedBox(height: 24),
              CheckboxListTile(
                value: agreed,
                onChanged:
                    busy
                        ? null
                        : (value) => setState(() => agreed = value ?? false),
                contentPadding: EdgeInsets.zero,
                title: const Text('삭제 범위와 복구 불가 안내를 확인했습니다.'),
              ),
              TextField(
                controller: confirmation,
                enabled: !busy,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '확인을 위해 ‘탈퇴’를 입력하세요',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                onPressed:
                    busy || !agreed || confirmation.text.trim() != '탈퇴'
                        ? null
                        : remove,
                child: Text(busy ? '삭제 중…' : '회원탈퇴'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
