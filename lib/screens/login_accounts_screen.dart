import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class LoginAccountsScreen extends StatefulWidget {
  const LoginAccountsScreen({super.key});
  @override
  State<LoginAccountsScreen> createState() => _LoginAccountsScreenState();
}

class _LoginAccountsScreenState extends State<LoginAccountsScreen>
    with WidgetsBindingObserver {
  late final String? owner = SupabaseService.currentUser?.id;
  StreamSubscription<AuthState>? subscription;
  List<UserIdentity> identities = [];
  bool loading = true;
  bool busy = false;
  String? error;
  int generation = 0;
  bool get ownsPage =>
      owner != null && SupabaseService.currentUser?.id == owner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscription = SupabaseService.authStateChanges?.listen((_) {
      if (mounted) unawaited(refresh());
    });
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    final request = ++generation;
    if (!ownsPage) {
      if (mounted) {
        setState(() {
          identities = [];
          loading = false;
        });
      }
      return;
    }
    try {
      final values = await SupabaseService.client!.auth.getUserIdentities();
      if (!mounted || !ownsPage || request != generation) return;
      setState(() {
        identities = values;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted || !ownsPage || request != generation) return;
      setState(() {
        loading = false;
        error = '연결 상태를 불러오지 못했어요. 다시 확인해 주세요.';
      });
    }
  }

  Future<void> connect(OAuthProvider provider, String label) async {
    if (!ownsPage || busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('$label 계정 연결'),
            content: Text(
              '현재 회원에 사용할 $label 계정을 인증해 주세요. 연결 후 같은 수집함과 위시리스트를 이용합니다. 이미 다른 회원으로 가입한 계정은 자동으로 합쳐지지 않습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('인증하고 연결'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted || !ownsPage) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final opened = await SupabaseService.linkLoginIdentity(provider);
      if (!opened) {
        throw const AuthException('Launch failed', code: 'oauth_launch_failed');
      }
      if (mounted && ownsPage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증을 완료한 뒤 연결 상태를 확인해 주세요.')),
        );
      }
    } catch (e) {
      if (mounted && ownsPage) {
        setState(() => error = SupabaseService.describeAuthError(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget account(
    String provider,
    String label,
    IconData icon,
    OAuthProvider? oauth,
  ) {
    final matches = identities.where(
      (identity) => identity.provider == provider,
    );
    final connected = matches.isNotEmpty;
    final value = connected ? (matches.first.identityData?['email']) : null;
    final email = value is String ? value : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    connected
                        ? (email?.isNotEmpty == true ? email! : '연결됨')
                        : loading
                        ? '연결 상태 확인 중…'
                        : '연결되지 않음',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (connected)
              const Icon(Icons.check_circle, color: Colors.teal)
            else if (oauth != null)
              OutlinedButton(
                onPressed: busy || loading ? null : () => connect(oauth, label),
                child: const Text('연결'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('로그인 계정 관리'),
      actions: [
        IconButton(
          tooltip: '연결 상태 새로고침',
          onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body:
        !ownsPage
            ? const Center(child: Text('기존 계정으로 다시 로그인해 주세요.'))
            : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '하나의 회원, 여러 로그인 방법',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  '이메일이 달라도 계정을 연결하면 같은 수집함·위시리스트·회원등급을 이용할 수 있어요.',
                  style: TextStyle(fontSize: 15, height: 1.65),
                ),
                const SizedBox(height: 24),
                if (loading) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 15,
                      ),
                    ),
                  ),
                account('email', '이메일', Icons.mail_outline, null),
                account(
                  'kakao',
                  '카카오',
                  Icons.chat_bubble_outline,
                  OAuthProvider.kakao,
                ),
                account(
                  'google',
                  'Google',
                  Icons.account_circle_outlined,
                  OAuthProvider.google,
                ),
                const SizedBox(height: 20),
                const Text(
                  '이미 다른 회원에 연결된 계정은 연결할 수 없어요. 각 계정의 기록은 자동 통합되지 않습니다.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
  );
}
