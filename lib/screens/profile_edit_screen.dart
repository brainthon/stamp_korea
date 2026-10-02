import 'package:flutter/material.dart';
import '../services/account_settings_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.initialNickname});
  final String initialNickname;
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController nickname = TextEditingController(
    text: widget.initialNickname,
  );
  late final String? owner;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    owner = SupabaseService.currentUser?.id;
  }

  @override
  void dispose() {
    nickname.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || owner == null || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final name = await AccountSettingsService.saveNickname(
        owner!,
        nickname.text,
      );
      if (mounted) Navigator.pop(context, name);
    } catch (_) {
      if (mounted) {
        setState(() => error = '저장하지 못했어요. 로그인과 연결 상태를 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('프로필 수정')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '나를 소개하는 이름',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text('마이페이지에 표시할 닉네임을 정해주세요.'),
            const SizedBox(height: 24),
            Form(
              key: form,
              child: TextFormField(
                controller: nickname,
                enabled: !saving,
                maxLength: 20,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => save(),
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  helperText: '2~20자로 입력해 주세요.',
                ),
                validator: (value) {
                  final n = (value ?? '').trim();
                  return n.runes.length < 2 ||
                          n.runes.length > 20 ||
                          RegExp(r'[\x00-\x1f\x7f]').hasMatch(n)
                      ? '닉네임은 2~20자로 입력해 주세요.'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving || owner == null ? null : save,
              child: Text(saving ? '저장 중…' : '프로필 저장'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              '이메일과 로그인 방식은 계정 인증 정보이므로 이 화면에서 변경하지 않습니다.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    ),
  );
}
