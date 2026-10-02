import 'delete_account_screen.dart';
import '../widgets/notification_bell.dart';
import 'notifications_screen.dart';
import 'profile_edit_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/membership.dart';
import '../models/stamp.dart';
import '../services/collection_service.dart';
import '../services/membership_service.dart';
import '../services/stamp_repository.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stamp_visual_view.dart';
import 'membership_policy_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    required this.onCollection,
    required this.onStamp,
  });
  final ValueChanged<String> onCollection;
  final ValueChanged<Stamp> onStamp;
  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  late final String? ownerId;
  late Future<Membership> membership = MembershipService.fetch();
  late Future<UserProfile?> profile = SupabaseService.fetchProfile().timeout(
    const Duration(seconds: 15),
  );
  StreamSubscription<AuthState>? auth;
  bool busy = false;
  String? savedNickname;
  bool get ownsPage =>
      ownerId != null && SupabaseService.currentUser?.id == ownerId;

  @override
  void initState() {
    super.initState();
    ownerId = SupabaseService.currentUser?.id;
    auth = SupabaseService.authStateChanges?.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    auth?.cancel();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void openCollection(String filter) {
    if (!ownsPage) return;
    Navigator.pop(context);
    widget.onCollection(filter);
  }

  Future<void> editProfile(String name) async {
    if (!ownsPage) return;
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(initialNickname: name),
      ),
    );
    if (value != null && mounted && ownsPage) {
      setState(() {
        savedNickname = value;
        profile = SupabaseService.fetchProfile();
      });
      message('프로필을 저장했어요.');
    }
  }

  Future<void> reload() async {
    if (busy || !ownsPage) return;
    setState(() {
      busy = true;
      membership = MembershipService.fetch();
      profile = SupabaseService.fetchProfile().timeout(
        const Duration(seconds: 15),
      );
    });
    try {
      await CollectionService.reloadForAccount();
      if (ownsPage) message(CollectionService.syncError ?? '수집 기록을 새로 불러왔어요.');
    } catch (_) {
      if (ownsPage) message('연결 상태를 확인하고 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    if (busy || !ownsPage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('로그아웃할까요?'),
            content: const Text('계정에 저장한 수집 기록은 유지됩니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('로그아웃'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted || !ownsPage) return;
    setState(() => busy = true);
    try {
      await SupabaseService.signOut();
    } catch (_) {
      message('로그아웃하지 못했어요. 연결 상태를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String providerName(String value) => switch (value) {
    'email' => '이메일',
    'google' => 'Google',
    'kakao' => '카카오',
    _ => '연결 계정',
  };
  String dateLabel(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    if (!ownsPage || user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('마이페이지'),
          actions: const [NotificationBell()],
        ),
        body: const Center(child: Text('로그인한 계정에서 이용할 수 있어요.')),
      );
    }
    final rawProviders = user.appMetadata['providers'];
    final providers =
        rawProviders is List && rawProviders.isNotEmpty
            ? rawProviders
                .map((v) => providerName(v.toString()))
                .toSet()
                .join(' · ')
            : providerName(user.appMetadata['provider']?.toString() ?? 'email');
    final fallbackName =
        [
          user.userMetadata?['nickname'],
          user.userMetadata?['name'],
          user.userMetadata?['full_name'],
        ].whereType<String>().where((v) => v.trim().isNotEmpty).firstOrNull ??
        '우표 수집가';
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        actions: const [NotificationBell()],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ValueListenableBuilder<int>(
            valueListenable: CollectionService.notifier,
            builder: (context, _, child) {
              final items = CollectionService.getItems();
              final counts = <String, int>{};
              for (final item in items) {
                counts.update(
                  item.stampId,
                  (n) => n + item.count,
                  ifAbsent: () => item.count,
                );
              }
              final recent = [...items]..sort((a, b) {
                final order = b.acquiredDate.compareTo(a.acquiredDate);
                return order != 0 ? order : b.id.compareTo(a.id);
              });
              final ready =
                  !CollectionService.loading &&
                  CollectionService.syncError == null;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  FutureBuilder<UserProfile?>(
                    future: profile,
                    builder: (context, snapshot) {
                      final name =
                          savedNickname != null
                              ? savedNickname!
                              : snapshot.data?.nickname.trim().isNotEmpty ==
                                  true
                              ? snapshot.data!.nickname
                              : fallbackName;
                      return Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppTheme.mint,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person_outline,
                                color: AppTheme.primaryBlack,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.email?.isNotEmpty == true
                                  ? user.email!
                                  : '$providers 계정으로 로그인',
                              style: const TextStyle(color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<Membership>(
                              future: membership,
                              builder:
                                  (context, state) => Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      Chip(
                                        label: Text(
                                          state.hasError
                                              ? '등급 확인 필요'
                                              : !state.hasData
                                              ? '등급 확인 중'
                                              : state.data!.isPremium
                                              ? '프리미엄회원'
                                              : '무료회원',
                                        ),
                                        avatar: const Icon(
                                          Icons.verified_user_outlined,
                                          size: 18,
                                        ),
                                      ),
                                      if (state.hasError)
                                        TextButton(
                                          onPressed:
                                              () => setState(
                                                () =>
                                                    membership =
                                                        MembershipService.fetch(),
                                              ),
                                          child: const Text('다시 확인'),
                                        ),
                                    ],
                                  ),
                            ),
                            TextButton.icon(
                              onPressed:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => _ProfileDetails(
                                            onEdit: () {
                                              Navigator.pop(context);
                                              unawaited(editProfile(name));
                                            },
                                            name: name,
                                            email: user.email,
                                            providers: providers,
                                            joined: DateTime.tryParse(
                                              user.createdAt,
                                            ),
                                          ),
                                    ),
                                  ),
                              icon: const Icon(Icons.badge_outlined),
                              label: const Text('내 정보 보기'),
                            ),
                            TextButton.icon(
                              onPressed: () => editProfile(name),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('프로필 수정'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '나의 수집 현황',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Summary(
                        value: ready ? '${counts.length}' : '—',
                        label: '수집한 우표',
                        onTap: ready ? () => openCollection('전체') : null,
                      ),
                      const SizedBox(width: 8),
                      _Summary(
                        value:
                            ready ? '${CollectionService.wishlistCount}' : '—',
                        label: '위시리스트',
                        onTap: ready ? () => openCollection('위시리스트') : null,
                      ),
                      const SizedBox(width: 8),
                      _Summary(
                        value:
                            ready
                                ? '${counts.values.where((n) => n > 1).length}'
                                : '—',
                        label: '중복 우표',
                        onTap: ready ? () => openCollection('중복') : null,
                      ),
                    ],
                  ),
                  if (CollectionService.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (CollectionService.syncError != null) ...[
                    const SizedBox(height: 12),
                    Text(CollectionService.syncError!),
                    TextButton(
                      onPressed: busy ? null : reload,
                      child: const Text('다시 불러오기'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    '종수 기준으로 표시해요. 수집 기록과 위시리스트는 계정에 저장됩니다.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '최근 수집 기록',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () => openCollection('전체'),
                        child: const Text('모두 보기'),
                      ),
                    ],
                  ),
                  if (ready && recent.isEmpty)
                    _panel(
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('아직 수집 기록이 없어요. 도감에서 첫 우표를 등록해 보세요.'),
                      ),
                    ),
                  if (ready && recent.isNotEmpty)
                    _panel(
                      child: Column(
                        children: [
                          for (final record in recent.take(3)) _recent(record),
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    '내 기록과 이용 안내',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _panel(
                    child: Column(
                      children: [
                        _menu(
                          Icons.collections_bookmark_outlined,
                          '내 수집함',
                          '소장 형태 · 수량 · 메모',
                          () => openCollection('전체'),
                        ),
                        const Divider(height: 1),
                        _menu(
                          Icons.bookmark_border,
                          '위시리스트',
                          '앞으로 모으고 싶은 우표',
                          () => openCollection('위시리스트'),
                        ),
                        const Divider(height: 1),
                        _menu(
                          Icons.ios_share,
                          '수집 기록 복사',
                          '텍스트로 기록 가져가기',
                          !ready
                              ? null
                              : () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text:
                                        CollectionService.generateCatalogTextReport(),
                                  ),
                                );
                                if (ownsPage) message('수집 기록을 복사했어요.');
                              },
                        ),
                        const Divider(height: 1),
                        _menu(
                          Icons.sync,
                          '수집 기록 새로고침',
                          busy ? '불러오는 중…' : '계정에 저장된 기록 다시 불러오기',
                          busy ? null : reload,
                        ),
                        const Divider(height: 1),
                        _menu(
                          Icons.info_outline,
                          '회원별 이용 안내',
                          '무료회원 · 프리미엄 준비 사항',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const MembershipPolicyScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _menu(
                    Icons.notifications_outlined,
                    '알림',
                    '회원 공지와 새로운 소식',
                    () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: busy ? null : logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('로그아웃'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed:
                        busy
                            ? null
                            : () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DeleteAccountScreen(),
                              ),
                            ),
                    child: const Text('회원탈퇴'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.borderGray),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
  Widget _menu(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? action,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    leading: Icon(icon, color: AppTheme.primaryBlack),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: action,
    enabled: action != null,
  );
  Widget _recent(CollectionItem item) {
    final stamp = StampRepository.getStampById(item.stampId);
    return InkWell(
      onTap:
          stamp == null
              ? null
              : () {
                if (!ownsPage) return;
                Navigator.pop(context);
                widget.onStamp(stamp);
              },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (stamp == null)
              const SizedBox(width: 48, child: Icon(Icons.image_outlined))
            else
              StampVisualView(stamp: stamp, width: 48, height: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stamp?.name ?? '도감 정보 확인 중',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.condition.title} · ${item.count}장',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  Text(
                    dateLabel(item.acquiredDate),
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (stamp != null) const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.value,
    required this.label,
    required this.onTap,
  });
  final String value, label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.borderGray),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({
    required this.name,
    required this.email,
    required this.providers,
    required this.joined,
    required this.onEdit,
  });
  final VoidCallback onEdit;
  final String name, providers;
  final String? email;
  final DateTime? joined;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('내 정보')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('내 계정 정보', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            for (final entry
                in {
                  '닉네임': name,
                  '이메일': email?.isNotEmpty == true ? email! : '제공된 이메일 없음',
                  '로그인 방식': providers,
                  '가입일':
                      joined == null
                          ? '확인할 수 없음'
                          : '${joined!.toLocal().year}.${joined!.toLocal().month.toString().padLeft(2, '0')}.${joined!.toLocal().day.toString().padLeft(2, '0')}',
                }.entries) ...[
              Text(
                entry.key,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 6),
              SelectableText(
                entry.value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
            ],
            FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('프로필 수정'),
            ),
          ],
        ),
      ),
    ),
  );
}
