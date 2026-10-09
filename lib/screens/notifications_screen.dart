import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'notification_settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final String? owner = SupabaseService.currentUser?.id;
  List<MemberNotification> items = [];
  String category = '전체';
  String? error;
  bool loading = false, more = true;
  int generation = 0, nextOffset = 0;
  final Set<String> deleting = {};
  bool get ownsPage =>
      owner != null && SupabaseService.currentUser?.id == owner;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool reset = true}) async {
    if (!ownsPage || deleting.isNotEmpty || (!reset && loading)) return;
    final ticket = ++generation;
    setState(() {
      loading = true;
      error = null;
      if (reset) items = [];
    });
    try {
      final page = await NotificationService.fetch(
        owner!,
        category,
        reset ? 0 : nextOffset,
      );
      if (!mounted || ticket != generation || !ownsPage) return;
      final rows = page.items;
      setState(() {
        nextOffset = page.nextOffset;
        items =
            reset
                ? rows
                : [
                  ...items,
                  ...rows.where((row) => !items.any((old) => old.id == row.id)),
                ];
        more = page.hasMore;
      });
    } catch (_) {
      if (mounted && ticket == generation && ownsPage) {
        setState(() => error = '알림을 불러오지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && ticket == generation) setState(() => loading = false);
    }
  }

  Future<void> remove(MemberNotification item) async {
    if (!ownsPage || loading || deleting.contains(item.id)) return;
    setState(() => deleting.add(item.id));
    try {
      await NotificationService.hide(owner!, item.id);
      if (!mounted || !ownsPage) return;
      setState(() => items.removeWhere((r) => r.id == item.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('이 기기의 알림 목록에서 삭제했어요.'),
          action: SnackBarAction(
            label: '실행 취소',
            onPressed: () async {
              if (!ownsPage) return;
              try {
                await NotificationService.hide(owner!, item.id, hidden: false);
                if (mounted && ownsPage) await load();
              } catch (_) {
                if (mounted && ownsPage) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('알림을 복원하지 못했어요. 다시 시도해 주세요.')),
                  );
                }
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted && ownsPage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => deleting.remove(item.id));
    }
  }

  Future<void> open(MemberNotification item) async {
    if (!ownsPage) return;
    // Opening the detail counts as reading; a failed save keeps the badge unread.
    final detail = Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              appBar: AppBar(title: Text(item.category)),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      date(item.date),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SelectableText(
                      item.body,
                      style: const TextStyle(fontSize: 17, height: 1.65),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
    if (!item.read) {
      try {
        await NotificationService.markRead(owner!, item.id);
        if (mounted && ownsPage) setState(() => item.read = true);
      } catch (_) {
        if (mounted && ownsPage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('읽음 상태를 저장하지 못했어요. 다시 열어 주세요.')),
          );
        }
      }
    }
    await detail;
  }

  String date(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}  ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.canvas,
    appBar: AppBar(
      title: const Text('알림'),
      actions: [
        IconButton(
          tooltip: '푸시 알림 설정',
          icon: const Icon(Icons.settings_outlined),
          onPressed:
              ownsPage
                  ? () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  )
                  : null,
        ),
      ],
    ),
    body:
        !ownsPage
            ? const Center(child: Text('로그인 후 알림을 확인해 주세요.'))
            : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children:
                          ['전체', '공지', '수집', '교환', '혜택']
                              .map(
                                (value) => Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: ChoiceChip(
                                    label: Text(
                                      value,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    selected: category == value,
                                    onSelected: (_) {
                                      if (deleting.isNotEmpty) return;
                                      setState(() => category = value);
                                      load();
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (items.isEmpty && !loading && error == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 90),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 48,
                                  color: AppTheme.textMuted,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '표시할 알림이 없어요.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '회원 공지와 새로운 소식을 여기서 확인하세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () => open(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: const Color(
                                          0xFFE8F0FF,
                                        ),
                                        foregroundColor: AppTheme.primaryBlack,
                                        child: Icon(switch (item.kind) {
                                          'announcement' =>
                                            Icons.campaign_outlined,
                                          'exchange' => Icons.swap_horiz,
                                          'event' => Icons.local_offer_outlined,
                                          _ =>
                                            Icons.markunread_mailbox_outlined,
                                        }),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.category,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 18,
                                                height: 1.45,
                                                fontWeight:
                                                    item.read
                                                        ? FontWeight.w500
                                                        : FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              date(item.date),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: '이 기기에서 알림 삭제',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed:
                                            loading ||
                                                    deleting.contains(item.id)
                                                ? null
                                                : () => remove(item),
                                      ),
                                      if (!item.read)
                                        const Padding(
                                          padding: EdgeInsets.only(
                                            left: 8,
                                            top: 5,
                                          ),
                                          child: CircleAvatar(
                                            radius: 4,
                                            backgroundColor: Color(0xFFD92D20),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        if (error != null) ...[
                          Text(error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: () => load(reset: items.isEmpty),
                            child: const Text('다시 시도'),
                          ),
                        ],
                        if (!loading && error == null && more)
                          TextButton(
                            onPressed: () => load(reset: false),
                            child: const Text('알림 더 보기'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
  );
}
