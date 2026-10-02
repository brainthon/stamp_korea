import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AdminMembers extends StatefulWidget {
  const AdminMembers({super.key});
  @override
  State<AdminMembers> createState() => _AdminMembersState();
}

class _AdminMembersState extends State<AdminMembers> {
  final query = TextEditingController();
  final listScroll = ScrollController();
  final filters = const {
    'all': '전체',
    'unconfirmed': '이메일 미인증',
    'restricted': '로그인 제한',
    'admin': '관리자',
  };
  List<Map<String, dynamic>> rows = [];
  String status = 'all';
  String plan = 'all';
  String? error;
  int page = 0, total = 0;
  bool busy = false;
  bool get allowed =>
      SupabaseService.currentUser?.appMetadata['stamp_admin'] == true;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    query.dispose();
    listScroll.dispose();
    super.dispose();
  }

  String date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '—';
    return '${parsed.year}.${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
  }

  bool restricted(Map<String, dynamic> row) =>
      DateTime.tryParse(
        row['banned_until']?.toString() ?? '',
      )?.isAfter(DateTime.now()) ??
      false;
  Future<dynamic> invoke(Map<String, dynamic> body) async {
    final result = await SupabaseService.client!.functions.invoke(
      'admin-members',
      body: body,
    );
    if (result.status != 200) throw StateError('request');
    return result.data;
  }

  String failure(Object e) =>
      e is FunctionException && e.details is Map
          ? e.details['error']?.toString() ?? '요청에 실패했습니다.'
          : '연결을 확인한 뒤 다시 조회해 주세요.';
  Future<void> load() async {
    if (!allowed || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await invoke({
        'action': 'list',
        'query': query.text,
        'status': status,
        'plan': plan,
        'page': page,
      });
      if (mounted) {
        setState(() {
          rows = List<Map<String, dynamic>>.from(data['members']);
          total = data['total'] as int;
        });
        if (listScroll.hasClients) listScroll.jumpTo(0);
      }
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> detail(Map<String, dynamic> row) async {
    final history = SupabaseService.client!
        .from('member_admin_actions')
        .select('action,reason,status,created_at')
        .eq('member_id', row['id'])
        .order('created_at', ascending: false)
        .limit(10);
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('회원 상세'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    '${row['email'] ?? '이메일 없음'}\n${row['nickname']}',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '가입일  ${date(row['created_at'])}\n최근 로그인  ${date(row['last_sign_in_at'])}\n이메일 인증  ${date(row['email_confirmed_at'])}\n수집 등록  ${row['collection_count']}건\n사진 제공  ${row['photo_count']}건\n로그인 방식  ${(row['providers'] as List).join(', ')}',
                    style: const TextStyle(fontSize: 15, height: 1.9),
                  ),
                  if (restricted(row))
                    Text('로그인 제한 종료  ${date(row['banned_until'])}'),
                  const SizedBox(height: 12),
                  Text(
                    '회원 등급  ${memberPlan(row)}\n구독 상태  ${{'inactive': '미구독', 'active': '구독 중', 'canceled': '갱신 해지 · 기간까지 이용', 'expired': '만료'}[row['subscription_status']] ?? '미구독'}\n구독 시작  ${date(row['period_start'])}\n이용 종료  ${date(row['period_end'])}',
                    style: const TextStyle(fontSize: 15, height: 1.9),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '수집 건수는 서버에 저장된 등록 건수입니다. 위시리스트는 현재 기기에 저장되어 표시하지 않습니다.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '최근 관리 이력',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: history,
                    builder: (_, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('이력을 조회하지 못했습니다.');
                      }
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.data!.isEmpty) {
                        return const Text('관리 이력이 없습니다.');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final log in snapshot.data!)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${date(log['created_at'])} · ${log['action'] == 'restrict' ? '로그인 제한' : '제한 해제'} · ${{'pending': '처리 확인 필요', 'success': '완료', 'failed': '실패'}[log['status']]}\n${log['reason']}',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }

  Future<void> change(Map<String, dynamic> row) async {
    final restore = restricted(row), reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(restore ? '로그인 제한 해제' : '30일 로그인 제한'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${row['email']}\n${restore ? '다시 로그인할 수 있도록 허용합니다.' : '새 로그인과 토큰 갱신을 제한합니다. 이미 발급된 접근 토큰은 만료 전까지 유효할 수 있습니다.'}',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reason,
                    maxLength: 300,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '처리 사유 (3자 이상)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: reason,
                builder:
                    (_, value, __) => FilledButton(
                      onPressed:
                          value.text.trim().length < 3
                              ? null
                              : () => Navigator.pop(context, true),
                      child: const Text('적용'),
                    ),
              ),
            ],
          ),
    );
    final note = reason.text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    reason.dispose();
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await invoke({
        'action': restore ? 'restore' : 'restrict',
        'id': row['id'],
        'reason': note,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('회원 로그인 상태를 변경했습니다.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted && error == null) await load();
  }

  @override
  Widget build(BuildContext context) {
    if (!allowed) return const Text('관리자 로그인 후 회원 정보를 관리할 수 있습니다.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '회원 관리',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '검색 결과 $total명 · 가입과 활동 현황을 확인하세요.',
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: query,
          enabled: !busy,
          maxLength: 100,
          onSubmitted: (_) {
            page = 0;
            load();
          },
          decoration: InputDecoration(
            labelText: '이메일 또는 닉네임 검색',
            counterText: '',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed:
                  busy
                      ? null
                      : () {
                        page = 0;
                        load();
                      },
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in filters.entries)
              ChoiceChip(
                label: Text(f.value),
                selected: status == f.key,
                onSelected:
                    busy
                        ? null
                        : (_) {
                          setState(() {
                            status = f.key;
                            page = 0;
                          });
                          load();
                        },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option
                in const {
                  'all': '모든 등급',
                  'free': '무료',
                  'premium': '프리미엄',
                }.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: plan == option.key,
                onSelected:
                    busy
                        ? null
                        : (_) {
                          setState(() {
                            plan = option.key;
                            page = 0;
                          });
                          load();
                        },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          TextButton(onPressed: busy ? null : load, child: Text(error!)),
        if (!busy && error == null && rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('조건에 맞는 회원이 없습니다.'),
          ),
        if (rows.isNotEmpty) memberList(),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed:
                  busy || page == 0
                      ? null
                      : () {
                        page--;
                        load();
                      },
              child: const Text('이전'),
            ),
            Text('${page + 1} / ${math.max(1, (total / 25).ceil())}'),
            TextButton(
              onPressed:
                  busy || (page + 1) * 25 >= total
                      ? null
                      : () {
                        page++;
                        load();
                      },
              child: const Text('다음'),
            ),
            const Spacer(),
            IconButton(
              tooltip: '새로고침',
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ],
    );
  }

  String memberStatus(Map<String, dynamic> row) =>
      row['is_admin'] == true
          ? '관리자'
          : restricted(row)
          ? '로그인 제한'
          : row['email_confirmed_at'] == null
          ? '이메일 미인증'
          : '일반 회원';

  String memberPlan(Map<String, dynamic> row) =>
      row['effective_plan'] == 'premium' ? '프리미엄' : '무료';

  Widget actions(Map<String, dynamic> row) => PopupMenuButton<String>(
    tooltip: '회원 관리 메뉴',
    enabled: !busy,
    onSelected: (action) {
      if (action == 'detail') {
        detail(row);
      } else {
        change(row);
      }
    },
    itemBuilder:
        (_) => [
          const PopupMenuItem(value: 'detail', child: Text('상세 정보 · 관리 이력')),
          if (row['is_admin'] != true)
            PopupMenuItem(
              value: 'change',
              child: Text(restricted(row) ? '로그인 제한 해제' : '30일 로그인 제한'),
            ),
        ],
  );

  Widget memberList() => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 760;
      final rowHeight = desktop ? 76.0 : 92.0;
      final height = math.min(
        rows.length * rowHeight,
        math.min(
          480.0,
          math.max(240.0, MediaQuery.sizeOf(context).height * .5),
        ),
      );
      Widget cell(String value, int flex, {bool bold = false}) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      );
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffdce5e0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            if (desktop)
              Container(
                color: const Color(0xffedf5f1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    cell('회원 · 닉네임', 4, bold: true),
                    cell('등급', 2, bold: true),
                    cell('상태', 2, bold: true),
                    cell('가입일', 2, bold: true),
                    cell('수집 / 사진', 2, bold: true),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            SizedBox(
              height: height,
              child: Scrollbar(
                controller: listScroll,
                thumbVisibility: rows.length * rowHeight > height,
                child: ListView.builder(
                  controller: listScroll,
                  primary: false,
                  itemCount: rows.length,
                  itemExtent: rowHeight,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final email = row['email'] ?? '이메일 없음';
                    final nickname = row['nickname']?.toString() ?? '';
                    final label = memberStatus(row);
                    final color =
                        restricted(row)
                            ? const Color(0xffa33e35)
                            : const Color(0xff245e52);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                index == rows.length - 1
                                    ? Colors.transparent
                                    : const Color(0xffedf1ee),
                          ),
                        ),
                      ),
                      child: InkWell(
                        onTap: busy ? null : () => detail(row),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xff203d3a),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      desktop
                                          ? (nickname.isEmpty
                                              ? '닉네임 미등록'
                                              : nickname)
                                          : '${memberPlan(row)} · $label',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xff52675e),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (desktop) ...[
                                cell(
                                  memberPlan(row),
                                  2,
                                  bold: row['effective_plan'] == 'premium',
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: .08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                cell(date(row['created_at']), 2),
                                cell(
                                  '${row['collection_count']} / ${row['photo_count']}',
                                  2,
                                ),
                              ],
                              actions(row),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
