import 'admin_recognition.dart';
import 'admin_announcements.dart';
import 'admin_catalog.dart';
import 'admin_members.dart';
import 'admin_stats.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'auth_screen.dart';
import 'contribution_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const ink = Color(0xff203d3a), teal = Color(0xff167c70);
  final menus = const [
    '대시보드',
    '우표 DB',
    '이미지 검수',
    '판독 오류',
    '회원 관리',
    '통계',
    '회원 공지',
  ];
  final icons = const [
    Icons.space_dashboard_outlined,
    Icons.local_post_office_outlined,
    Icons.fact_check_outlined,
    Icons.document_scanner_outlined,
    Icons.people_outline,
    Icons.bar_chart_outlined,
    Icons.campaign_outlined,
  ];
  int selected = 0;
  List<Map<String, dynamic>> rows = [];
  bool loading = false;
  String? error;
  bool get admin =>
      SupabaseService.currentUser?.appMetadata['stamp_admin'] == true;
  @override
  void initState() {
    super.initState();
    if (Uri.base.queryParameters['section'] == 'errors') selected = 3;
    if (Uri.base.queryParameters['section'] == 'stats') selected = 5;
    if (Uri.base.queryParameters['section'] == 'announcements') selected = 6;
    load();
  }

  Future<void> load() async {
    if (!admin) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await SupabaseService.client!
          .from('photo_contributions')
          .select('id,stamp_id,status,created_at,training_consent')
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() => rows = List<Map<String, dynamic>>.from(result));
      }
    } catch (_) {
      if (mounted) setState(() => error = '검수 목록을 불러오지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> login() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
    if (mounted) {
      setState(() {});
      await load();
    }
  }

  Future<void> review() async {
    if (!admin) {
      await login();
      if (!admin) return;
    }
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ContributionScreen()));
    await load();
  }

  Widget pill(String text, {Color color = teal}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffe3eae6)),
    ),
    child: child,
  );
  Widget metric(String title, String value, String note, IconData icon) =>
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: teal, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: ink, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              note,
              style: const TextStyle(fontSize: 13, color: Color(0xff586e67)),
            ),
          ],
        ),
      );
  Widget navigation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(24, 32, 24, 6),
        child: Text(
          '✉ 우표모아',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Text(
          'COLLECTION STUDIO',
          style: TextStyle(fontSize: 11, letterSpacing: 2, color: teal),
        ),
      ),
      for (int i = 0; i < menus.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            selected: selected == i,
            selectedTileColor: const Color(0xffe2f3ed),
            selectedColor: teal,
            leading: Icon(icons[i], size: 21),
            title: Text(
              menus[i],
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            onTap: () => setState(() => selected = i),
          ),
        ),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.all(20),
        child: pill(admin ? '관리자 연결됨' : '디자인 미리보기'),
      ),
    ],
  );
  Widget dashboard(double width) {
    final pending = rows.where((r) => r['status'] == 'pending').length;
    final cards = [
      metric(
        '검수 대기',
        admin ? '$pending' : '—',
        '최근 제공 사진 100건 기준',
        Icons.fact_check_outlined,
      ),
      metric(
        '승인된 사진',
        admin ? '${rows.where((r) => r['status'] == 'approved').length}' : '—',
        '최근 제공 사진 100건 기준',
        Icons.verified_outlined,
      ),
      metric('우표 DB', '—', '다음 개발 · 등록 현황', Icons.local_post_office_outlined),
      metric('전체 회원', '—', '다음 개발 · 회원 현황', Icons.people_outline),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xffe6f4ee),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pill('우선 처리할 업무'),
              const SizedBox(height: 16),
              const Text(
                '한 장의 검수가,\n더 정확한 도감을 만듭니다.',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '회원 사진을 공식 우표와 비교하고 판독 자료로 승인하세요.',
                style: TextStyle(fontSize: 15, color: ink),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: review,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('사진 검수 시작'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children:
              cards
                  .map(
                    (card) => SizedBox(
                      width:
                          width > 1000
                              ? (width - 48) / 4
                              : width > 550
                              ? (width - 16) / 2
                              : width,
                      child: card,
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 28),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '최근 제공 사진',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: review,
                    child: const Text('검수 화면 열기 →'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '확인된 정답만 비교 자료로 사용됩니다.',
                style: TextStyle(color: Color(0xff586e67)),
              ),
              const Divider(height: 32),
              if (loading) const LinearProgressIndicator(),
              if (error != null) Text(error!),
              if (!admin)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    '관리자 로그인 후 실제 사진 목록이 표시됩니다.\n개인 사진은 미리보기에 노출하지 않습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.8, color: Color(0xff586e67)),
                  ),
                ),
              if (admin && !loading && error == null && rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('아직 제공된 사진이 없습니다.', textAlign: TextAlign.center),
                ),
              for (final row in rows.take(6))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff0f5f2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image_outlined, color: teal),
                  ),
                  title: Text(
                    row['stamp_id'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(row['created_at'].toString().split('T').first),
                  trailing: pill(
                    {
                          'pending': '검수 대기',
                          'approved': '승인 완료',
                          'rejected': '반려',
                        }[row['status']] ??
                        '확인 필요',
                  ),
                  onTap: review,
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '개발 순서  01 사진 검수  →  02 우표 DB · 이미지 관리  →  03 판독 오류  →  04 회원 · 통계',
          style: TextStyle(fontSize: 13, height: 1.8, color: Color(0xff586e67)),
        ),
      ],
    );
  }

  Widget workspace() => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pill(selected == 2 ? '사용 가능' : '화면 설계 · 준비 중'),
        const SizedBox(height: 24),
        Text(
          menus[selected],
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          const [
            '',
            '우표명·발행연도 검색, 상세정보 수정, 원본 이미지 관리와 신규 수집 내역을 이곳에 모읍니다.',
            '회원 사진과 공식 원본을 비교하고 정답을 승인하거나 반려합니다.',
            '오판독 신고와 사용자 수정 결과를 모아 반복되는 오류부터 확인합니다.',
            '회원 검색, 가입 상태와 구독 현황을 확인하는 화면입니다.',
            '판독 성공률, 도감 등록량과 회원 활동을 기간별로 확인합니다.',
          ][selected],
          style: const TextStyle(fontSize: 16, height: 1.8, color: ink),
        ),
        const SizedBox(height: 24),
        if (selected == 2)
          FilledButton.icon(
            onPressed: review,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('사진 정답 검수 열기'),
          )
        else
          const Text(
            '아직 데이터 조회·수정 기능은 연결하지 않았습니다.',
            style: TextStyle(color: Color(0xff586e67)),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff6f8f4),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 850;
          return Row(
            children: [
              if (wide)
                SizedBox(
                  width: 228,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        right: BorderSide(color: Color(0xffe3eae6)),
                      ),
                    ),
                    child: navigation(),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '운영 관리 / ${menus[selected]}',
                              style: const TextStyle(fontSize: 14, color: ink),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: admin ? load : login,
                            icon: Icon(
                              admin ? Icons.refresh : Icons.lock_outline,
                              size: 17,
                            ),
                            label: Text(admin ? '새로고침' : '관리자 로그인'),
                          ),
                        ],
                      ),
                    ),
                    if (!wide)
                      SizedBox(
                        height: 60,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          children: List.generate(
                            menus.length,
                            (i) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ChoiceChip(
                                label: Text(menus[i]),
                                selected: selected == i,
                                onSelected: (_) => setState(() => selected = i),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(wide ? 32 : 16),
                        children: [
                          Text(
                            menus[selected],
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '우표와 수집가를 연결하는 운영 공간',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xff586e67),
                            ),
                          ),
                          const SizedBox(height: 28),
                          LayoutBuilder(
                            builder:
                                (context, constraints) =>
                                    selected == 0
                                        ? dashboard(constraints.maxWidth)
                                        : selected == 1
                                        ? const AdminCatalog()
                                        : selected == 3
                                        ? const AdminRecognition()
                                        : selected == 4
                                        ? const AdminMembers()
                                        : selected == 5
                                        ? const AdminStats()
                                        : selected == 6
                                        ? const AdminAnnouncements()
                                        : workspace(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
