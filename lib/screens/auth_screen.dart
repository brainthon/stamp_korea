import 'dart:async';
import '../services/auth_flow.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'membership_policy_screen.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.recovery = false,
    this.initialSignup = false,
  });
  final bool recovery;
  final bool initialSignup;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  var form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final nickname = TextEditingController();
  bool signup = false, busy = false, hidden = true;
  String? message;
  bool failed = false, confirmationPending = false;
  StreamSubscription<AuthState>? auth;
  bool emailMode = false, resetMode = false, passwordChanged = false;
  Map<String, bool>? providers;
  String? providerError;
  @override
  void initState() {
    super.initState();
    signup = widget.initialSignup;
    emailMode = signup || widget.recovery;
    unawaited(loadProviders());
    message = SupabaseService.takeAuthError();
    failed = message != null;
    auth = SupabaseService.authStateChanges?.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          if (state.event == AuthChangeEvent.signedIn && !widget.recovery) {
            confirmationPending = false;
            failed = false;
            message = '로그인되었습니다.';
          }
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            failed = true;
            message = SupabaseService.describeAuthError(error);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    auth?.cancel();
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
          message = authFailureMessage(e.code);
          if (e.code == 'email_not_confirmed') {
            confirmationPending = true;
            emailMode = true;
          }
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
          setState(() {
            passwordChanged = true;
            message = '비밀번호가 변경되었습니다.';
          });
        }
      } else if (resetMode) {
        await SupabaseService.resetPassword(email.text);
        if (mounted) {
          setState(
            () => message = '등록된 주소라면 비밀번호 변경 메일을 보내드렸어요. 받은 메일의 버튼을 눌러 주세요.',
          );
        }
      } else if (signup) {
        final result = await SupabaseService.signUpWithEmail(
          email: email.text,
          password: password.text,
          nickname: nickname.text,
        );
        if (mounted && result.session == null) {
          setState(() {
            confirmationPending = true;
            password.clear();
            message = '인증 대기 중인 주소라면 확인 메일이 발송됩니다.';
          });
        }
      } else {
        await SupabaseService.signInWithEmail(
          email: email.text,
          password: password.text,
        );
      }
    });
  }

  Future<void> social(String provider) => run(() async {
    final opened =
        provider == 'kakao'
            ? await SupabaseService.signInWithKakao()
            : await SupabaseService.signInWithGoogle();
    if (!opened) {
      throw const AuthException(
        'Could not open login',
        code: 'oauth_launch_failed',
      );
    }
    if (mounted) {
      setState(
        () =>
            message =
                '${provider == 'kakao' ? '카카오' : 'Google'} 로그인 페이지를 열었어요. 인증을 완료하면 앱으로 돌아옵니다.',
      );
    }
  });

  Future<void> resend() => run(() async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      setState(() {
        failed = true;
        message = '이메일 주소를 입력해 주세요.';
      });
      return;
    }
    await SupabaseService.resendConfirmation(email.text);
    if (mounted) setState(() => message = '인증 대기 중인 주소라면 확인 메일이 다시 발송됩니다.');
  });

  Future<void> loadProviders() async {
    try {
      final value = await SupabaseService.loginProviders();
      if (mounted) {
        setState(() {
          providers = value;
          providerError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => providerError = '간편 로그인 연결 상태를 확인하지 못했어요.');
    }
  }

  void changeStep({
    required bool emailForm,
    bool create = false,
    bool reset = false,
  }) {
    setState(() {
      emailMode = emailForm;
      signup = create;
      resetMode = reset;
      confirmationPending = false;
      message = null;
      failed = false;
      password.clear();
      form = GlobalKey<FormState>();
    });
  }

  Widget action(
    String label,
    VoidCallback? callback, {
    IconData? icon,
    Color? color,
    bool outlined = false,
  }) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(58)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.titleMedium,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      backgroundColor: color == null ? null : WidgetStatePropertyAll(color),
      foregroundColor:
          color == null
              ? null
              : const WidgetStatePropertyAll(Color(0xFF202020)),
    );
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 24), const SizedBox(width: 12)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child:
          outlined
              ? OutlinedButton(
                onPressed: callback,
                style: style,
                child: content,
              )
              : FilledButton(onPressed: callback, style: style, child: content),
    );
  }

  Widget notice(String text, {bool problem = false}) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: problem ? const Color(0xFFFFEFEA) : AppTheme.mint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: problem ? const Color(0xFF922D1C) : AppTheme.textMain,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseService.isInitialized;
    final enabled = !busy && configured;
    final title =
        widget.recovery
            ? '비밀번호 변경'
            : confirmationPending
            ? '이메일 확인'
            : resetMode
            ? '비밀번호 찾기'
            : emailMode
            ? (signup ? '이메일 회원가입' : '이메일 로그인')
            : '로그인';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: '이전 화면',
          icon: const Icon(Icons.arrow_back),
          onPressed:
              busy
                  ? null
                  : () {
                    if (emailMode && !widget.recovery) {
                      changeStep(emailForm: false);
                    } else {
                      Navigator.maybePop(context);
                    }
                  },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                if (!emailMode && !widget.recovery) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/branding/app-logo.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  widget.recovery
                      ? (passwordChanged ? '비밀번호를 바꿨어요' : '새 비밀번호를 입력해 주세요')
                      : confirmationPending
                      ? '받은 메일을 확인해 주세요'
                      : resetMode
                      ? '가입한 이메일을 입력해 주세요'
                      : emailMode
                      ? (signup ? '우표모아에 오신 것을 환영해요' : '이메일로 로그인하세요')
                      : '우표 수집, 함께 시작해요',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  confirmationPending
                      ? email.text.trim()
                      : emailMode || widget.recovery
                      ? '아래 안내에 따라 하나씩 입력해 주세요.'
                      : '편한 방법을 선택해 주세요.\n처음 이용하시면 회원가입도 함께 진행돼요.',
                  style: const TextStyle(fontSize: 15, height: 1.65),
                ),
                const SizedBox(height: 26),
                if (message != null) notice(message!, problem: failed),
                if (!configured)
                  notice('지금은 로그인에 연결할 수 없어요. 잠시 후 다시 이용해 주세요.', problem: true),
                if (busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('잠시만 기다려 주세요…', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                ],
                if (passwordChanged)
                  action(
                    '앱으로 돌아가기',
                    () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                  )
                else if (confirmationPending && !widget.recovery) ...[
                  const Text(
                    '1. 이메일 앱이나 웹메일을 열어 주세요.\n2. 우표모아 확인 메일에서 인증 버튼을 눌러 주세요.\n3. 이 화면으로 돌아와 로그인하세요.',
                    style: TextStyle(fontSize: 15, height: 1.65),
                  ),
                  const SizedBox(height: 24),
                  action(
                    '이메일 확인했어요 · 로그인하기',
                    enabled ? () => changeStep(emailForm: true) : null,
                  ),
                  action(
                    '확인 메일 다시 받기',
                    enabled ? resend : null,
                    outlined: true,
                  ),
                  action(
                    '이메일 주소 수정하기',
                    enabled
                        ? () => changeStep(emailForm: true, create: true)
                        : null,
                    outlined: true,
                  ),
                  const Text(
                    '메일이 없으면 스팸함도 확인해 주세요.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ] else if (!emailMode && !widget.recovery) ...[
                  action(
                    '카카오로 시작하기',
                    enabled && providers?['kakao'] == true
                        ? () => social('kakao')
                        : null,
                    icon: Icons.chat_bubble_outline,
                    color: const Color(0xFFFEE500),
                  ),
                  if (providers?['kakao'] == false)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '카카오 로그인은 준비 중이에요.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  action(
                    'Google로 시작하기',
                    enabled && providers?['google'] == true
                        ? () => social('google')
                        : null,
                    icon: Icons.account_circle_outlined,
                    outlined: true,
                  ),
                  if (providers?['google'] == false)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Google 로그인은 준비 중이에요.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  if (providers == null && providerError == null)
                    notice('간편 로그인 연결 상태를 확인하고 있어요. 이메일 로그인은 바로 이용할 수 있어요.'),
                  if (providerError != null) ...[
                    notice(providerError!, problem: true),
                    action(
                      '간편 로그인 다시 확인',
                      busy ? null : loadProviders,
                      outlined: true,
                    ),
                  ],
                  const SizedBox(height: 8),
                  action(
                    '이메일로 로그인하기',
                    enabled ? () => changeStep(emailForm: true) : null,
                    icon: Icons.mail_outline,
                    outlined: true,
                  ),
                  action(
                    '처음이신가요? 이메일로 가입하기',
                    enabled
                        ? () => changeStep(emailForm: true, create: true)
                        : null,
                    outlined: true,
                  ),
                  const SizedBox(height: 12),
                  notice(
                    '이미 가입하셨나요?\n처음 가입한 방법으로 로그인해 주세요. 다른 로그인 방법은 마이페이지에서 연결할 수 있어요.',
                  ),
                  action(
                    '가입 없이 우표 도감 둘러보기',
                    busy
                        ? null
                        : () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                    outlined: true,
                  ),
                ] else ...[
                  Form(
                    key: form,
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          if (signup && !widget.recovery && !resetMode) ...[
                            TextFormField(
                              controller: nickname,
                              textInputAction: TextInputAction.next,
                              style: Theme.of(context).textTheme.bodyLarge,
                              maxLength: 30,
                              decoration: const InputDecoration(
                                labelText: '닉네임',
                                helperText: '앱에서 사용할 이름이에요.',
                              ),
                              validator:
                                  (v) =>
                                      v == null || v.trim().isEmpty
                                          ? '사용할 이름을 입력해 주세요.'
                                          : null,
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (!widget.recovery) ...[
                            TextFormField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction:
                                  resetMode
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                              style: Theme.of(context).textTheme.bodyLarge,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: '이메일 주소',
                                hintText: 'example@email.com',
                              ),
                              validator:
                                  (v) =>
                                      RegExp(
                                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                          ).hasMatch(v?.trim() ?? '')
                                          ? null
                                          : '이메일 주소를 확인해 주세요.',
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (!resetMode) ...[
                            TextFormField(
                              controller: password,
                              obscureText: hidden,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (enabled) unawaited(submit());
                              },
                              style: Theme.of(context).textTheme.bodyLarge,
                              autofillHints: [
                                signup || widget.recovery
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              decoration: InputDecoration(
                                labelText: '비밀번호',
                                helperText:
                                    signup || widget.recovery
                                        ? '8자 이상으로 정해 주세요.'
                                        : null,
                                suffixIcon: IconButton(
                                  tooltip: hidden ? '비밀번호 보기' : '비밀번호 숨기기',
                                  onPressed:
                                      () => setState(() => hidden = !hidden),
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
                                              (signup || widget.recovery
                                                  ? 8
                                                  : 1)
                                          ? (signup || widget.recovery
                                              ? '비밀번호를 8자 이상 입력해 주세요.'
                                              : '비밀번호를 입력해 주세요.')
                                          : null,
                            ),
                            const SizedBox(height: 24),
                          ],
                          action(
                            widget.recovery
                                ? '비밀번호 변경하기'
                                : resetMode
                                ? '비밀번호 변경 메일 받기'
                                : signup
                                ? '가입 확인 메일 받기'
                                : '로그인하기',
                            enabled ? submit : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.recovery && !signup && !resetMode)
                    action(
                      '비밀번호를 잊으셨나요?',
                      enabled
                          ? () => changeStep(emailForm: true, reset: true)
                          : null,
                      outlined: true,
                    ),
                  if (!widget.recovery)
                    action(
                      resetMode || signup ? '이메일 로그인으로 돌아가기' : '이메일로 새로 가입하기',
                      enabled
                          ? () => changeStep(
                            emailForm: true,
                            create: !signup && !resetMode,
                          )
                          : null,
                      outlined: true,
                    ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const MembershipPolicyScreen(),
                        ),
                      ),
                  child: const Text(
                    '회원별 이용 안내',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
