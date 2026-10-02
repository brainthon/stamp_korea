import 'package:flutter/material.dart';
import '../services/account_settings_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final String? owner;
  NotificationPreferences settings = const NotificationPreferences();
  bool loading = true, saving = false, dirty = false;
  String? error;
  @override
  void initState() {
    super.initState();
    owner = SupabaseService.currentUser?.id;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (owner == null) throw StateError('Login required');
      final value = await AccountSettingsService.fetch(owner!);
      if (mounted) {
        setState(() {
          settings = value;
          dirty = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '알림 설정을 불러오지 못했어요. 로그인과 연결 상태를 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void change(NotificationPreferences value) => setState(() {
    settings = value;
    dirty = true;
  });
  Future<void> save() async {
    if (saving || owner == null || !dirty) return;
    setState(() => saving = true);
    try {
      await AccountSettingsService.save(owner!, settings);
      if (mounted) {
        setState(() => dirty = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('알림 선호 설정을 저장했어요.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장하지 못했어요. 연결을 확인하고 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget option(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> update,
  ) => SwitchListTile.adaptive(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    value: value,
    onChanged: saving || !settings.enabled ? null : update,
    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('푸시 알림 설정')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.mint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                '현재는 알림 선호 설정을 계정에 저장합니다. 실제 푸시 발송과 기기 알림 권한 연결은 준비 중이므로 아직 알림이 오지 않습니다.',
              ),
            ),
            const SizedBox(height: 24),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null) ...[
              Text(error!),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: load, child: const Text('다시 불러오기')),
            ] else ...[
              SwitchListTile.adaptive(
                title: const Text(
                  '알림 수신',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('받고 싶은 알림 항목을 선택해 주세요.'),
                value: settings.enabled,
                onChanged:
                    saving
                        ? null
                        : (v) => change(settings.copyWith(enabled: v)),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 32),
              option(
                '신규 우표 발행',
                '새 우표가 도감에 등록될 때',
                settings.newStamps,
                (v) => change(settings.copyWith(newStamps: v)),
              ),
              option(
                '위시리스트 매칭',
                '찾는 우표의 교환·판매 정보 · 기능 준비 중',
                settings.wishlistMatches,
                (v) => change(settings.copyWith(wishlistMatches: v)),
              ),
              option(
                '교환 진행',
                '교환 요청과 진행 상황 · 기능 준비 중',
                settings.exchangeUpdates,
                (v) => change(settings.copyWith(exchangeUpdates: v)),
              ),
              option(
                '이벤트·혜택',
                '우표모아 소식과 혜택 · 선택 수신',
                settings.events,
                (v) => change(settings.copyWith(events: v)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: !dirty || saving ? null : save,
                child: Text(saving ? '저장 중…' : '설정 저장'),
              ),
              const SizedBox(height: 16),
              const Text(
                '알림 수신을 끄면 항목별 선택은 보관됩니다. 이 설정은 기기의 알림 권한을 변경하지 않습니다.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
