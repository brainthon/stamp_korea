import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/collection_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.recovery = false});
  final bool recovery;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final nickname = TextEditingController();
  bool signup = false, busy = false, hidden = true;
  String? message;
  bool failed = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    nickname.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
      failed = false;
    });
    try {
      await operation();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          failed = true;
          message = switch (e.code) {
            'invalid_credentials' => '이메일 또는 비밀번호를 확인해 주세요.',
            'email_not_confirmed' => '받은 메일에서 이메일 인증을 완료해 주세요.',
            'over_email_send_rate_limit' ||
            'over_request_rate_limit' => '요청이 많아요. 잠시 후 다시 시도해 주세요.',
            'provider_disabled' ||
            'validation_failed' => '로그인 제공자 설정을 확인해야 합니다.',
            _ => '인증을 완료하지 못했어요. 입력 내용과 연결 상태를 확인해 주세요.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          message = '연결하지 못했어요. 잠시 후 다시 시도해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    await run(() async {
      if (widget.recovery) {
        await SupabaseService.client!.auth.updateUser(
          UserAttributes(password: password.text),
        );
        SupabaseService.recoveryPending = false;
        if (mounted) {
          setState(() => message = '비밀번호가 변경되었습니다.');
        }
      } else if (signup) {
        final result = await SupabaseService.signUpWithEmail(
          email: email.text,
          password: password.text,
          nickname: nickname.text,
        );
        if (mounted && result.session == null) {
          setState(() => message = '가입 확인 메일을 보냈어요. 받은 메일의 링크를 누른 후 로그인해 주세요.');
        }
      } else {
        await SupabaseService.signInWithEmail(
          email: email.text,
          password: password.text,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final configured = SupabaseService.isInitialized;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recovery
              ? '비밀번호 변경'
              : user != null
              ? '내 계정'
              : '로그인',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Image.asset(
                  'assets/branding/app-logo.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.recovery
                    ? '새 비밀번호를 정해주세요'
                    : user != null
                    ? '나의 우표, 안전하게'
                    : '수집의 즐거움을 이어가세요',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                user != null && !widget.recovery
                    ? (user.email ??
                        user.userMetadata?['nickname']?.toString() ??
                        '로그인된 계정')
                    : '로그인하면 AI 사진 판독과 계정별 수집함을 이용할 수 있어요.',
              ),
              const SizedBox(height: 24),
              if (!configured)
                const Text('Supabase 연결 설정이 필요합니다. 현재는 기기 내 수집 기능을 이용할 수 있어요.'),
              if (user != null && !widget.recovery) ...[
                const Text('게스트 수집함은 이 기기에 따로 보관됩니다. 찜 목록은 계정별로 이 기기에 저장됩니다.'),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed:
                      busy
                          ? null
                          : () => run(() async {
                            await SupabaseService.signOut();
                          }),
                  child: const Text('로그아웃'),
                ),
                TextButton(
                  onPressed:
                      busy
                          ? null
                          : () => run(() async {
                            await CollectionService.reloadForAccount();
                            if (CollectionService.syncError != null) {
                              throw StateError('sync');
                            }
                            if (mounted) {
                              setState(() => message = '수집 기록을 새로 불러왔어요.');
                            }
                          }),
                  child: const Text('수집 기록 새로고침'),
                ),
              ] else ...[
                if (!widget.recovery) ...[
                  FilledButton(
                    onPressed:
                        busy || !configured
                            ? null
                            : () => run(() async {
                              final opened =
                                  await SupabaseService.signInWithKakao();
                              if (!opened) throw StateError('oauth');
                            }),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE500),
                      foregroundColor: const Color(0xFF191919),
                    ),
                    child: const Text('카카오로 계속하기'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed:
                        busy || !configured
                            ? null
                            : () => run(() async {
                              final opened =
                                  await SupabaseService.signInWithGoogle();
                              if (!opened) throw StateError('oauth');
                            }),
                    child: const Text('Google로 계속하기'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Center(child: Text('또는 이메일로')),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('로그인')),
                      ButtonSegment(value: true, label: Text('회원가입')),
                    ],
                    selected: {signup},
                    onSelectionChanged:
                        busy
                            ? null
                            : (v) => setState(() {
                              signup = v.first;
                              message = null;
                              form.currentState?.reset();
                            }),
                  ),
                  const SizedBox(height: 22),
                ],
                Form(
                  key: form,
                  child: AutofillGroup(
                    child: Column(
                      children: [
                        if (signup && !widget.recovery) ...[
                          TextFormField(
                            controller: nickname,
                            maxLength: 30,
                            decoration: const InputDecoration(labelText: '닉네임'),
                            validator:
                                (v) =>
                                    (v?.trim().isEmpty ?? true)
                                        ? '닉네임을 입력해 주세요.'
                                        : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (!widget.recovery) ...[
                          TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: const InputDecoration(labelText: '이메일'),
                            validator:
                                (v) =>
                                    RegExp(
                                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                        ).hasMatch(v?.trim() ?? '')
                                        ? null
                                        : '올바른 이메일을 입력해 주세요.',
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: password,
                          obscureText: hidden,
                          autofillHints: [
                            signup || widget.recovery
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            helperText:
                                signup || widget.recovery
                                    ? '8자 이상으로 입력해 주세요.'
                                    : null,
                            suffixIcon: IconButton(
                              tooltip: hidden ? '비밀번호 보기' : '비밀번호 숨기기',
                              onPressed: () => setState(() => hidden = !hidden),
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator:
                              (v) =>
                                  (v ?? '').length <
                                          (signup || widget.recovery ? 8 : 1)
                                      ? '비밀번호를 확인해 주세요.'
                                      : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: busy || !configured ? null : submit,
                            child: Text(
                              widget.recovery
                                  ? '비밀번호 변경'
                                  : signup
                                  ? '이메일로 가입하기'
                                  : '이메일로 로그인',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!widget.recovery && !signup)
                  TextButton(
                    onPressed:
                        busy || !configured
                            ? null
                            : () => run(() async {
                              if (!RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(email.text.trim())) {
                                setState(() {
                                  failed = true;
                                  message = '위 이메일 칸에 주소를 입력해 주세요.';
                                });
                                return;
                              }
                              await SupabaseService.resetPassword(email.text);
                              if (mounted) {
                                setState(
                                  () =>
                                      message = '등록된 주소라면 비밀번호 재설정 메일이 발송됩니다.',
                                );
                              }
                            }),
                    child: const Text('비밀번호를 잊으셨나요?'),
                  ),
              ],
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message!,
                      style: TextStyle(
                        color:
                            failed
                                ? Colors.red.shade800
                                : const Color(0xFF173E35),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
