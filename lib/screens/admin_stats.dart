import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AdminStats extends StatefulWidget {
  const AdminStats({super.key});
  @override
  State<AdminStats> createState() => _AdminStatsState();
}

class _AdminStatsState extends State<AdminStats> {
  static const teal = Color(0xff167c70), blue = Color(0xff507fcb);
  Map<String, dynamic>? data;
  bool busy = false;
  String? error;
  int days = 7;
  bool get allowed =>
      SupabaseService.currentUser?.appMetadata['stamp_admin'] == true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!allowed || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await SupabaseService.client!.functions.invoke(
        'admin-members',
        body: {'action': 'stats', 'days': days},
      );
      if (result.status != 200) throw StateError('stats');
      if (mounted) {
        setState(() => data = Map<String, dynamic>.from(result.data));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error =
                  e is FunctionException && e.details is Map
                      ? e.details['error']?.toString() ?? '통계를 조회하지 못했습니다.'
                      : '연결을 확인한 뒤 다시 조회해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String number(dynamic value) => (value ?? 0).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  Widget panel(String title, Widget content) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffdce5e0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        content,
      ],
    ),
  );
  Widget metric(String label, dynamic value, String note, Color color) => panel(
    label,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number(value),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          note,
          style: const TextStyle(fontSize: 14, color: Color(0xff52675e)),
        ),
      ],
    ),
  );
  Widget trend(String key, Color color) {
    final series = List<Map<String, dynamic>>.from(data!['series']);
    final peak = series.fold<int>(
      0,
      (v, row) => math.max(v, (row[key] as num).toInt()),
    );
    return Column(
      children: [
        Row(
          children: [
            Text(
              '최고 ${number(peak)}건 / 일',
              style: const TextStyle(fontSize: 14),
            ),
            const Spacer(),
            Text('최근 $days일', style: const TextStyle(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 156,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final row in series)
                Expanded(
                  child: Tooltip(
                    message: '${row['day']} · ${number(row[key])}건',
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: days == 7 ? 5 : 2,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (days == 7)
                            Text(
                              number(row[key]),
                              style: const TextStyle(fontSize: 13),
                            ),
                          const SizedBox(height: 5),
                          Container(
                            height:
                                peak == 0
                                    ? 2
                                    : math.max(
                                      2,
                                      110 * (row[key] as num) / peak,
                                    ),
                            decoration: BoxDecoration(
                              color:
                                  (row[key] as num) == 0
                                      ? const Color(0xffdce5e0)
                                      : color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(series.first['day'].toString().substring(5)),
            Text(series.last['day'].toString().substring(5)),
          ],
        ),
        if (peak == 0)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('선택한 기간에 기록된 이용이 없습니다.'),
          ),
      ],
    );
  }

  Widget distribution(List<(String, int, Color)> items, {String unit = '건'}) {
    final total = items.fold<int>(0, (sum, item) => sum + item.$2);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child:
                total == 0
                    ? const ColoredBox(color: Color(0xffedf1ee))
                    : Row(
                      children: [
                        for (final item in items)
                          if (item.$2 > 0)
                            Expanded(
                              flex: item.$2,
                              child: ColoredBox(color: item.$3),
                            ),
                      ],
                    ),
          ),
        ),
        const SizedBox(height: 14),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: item.$3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.$1, style: const TextStyle(fontSize: 15)),
                ),
                Text(
                  '${number(item.$2)}$unit${total == 0 ? '' : ' · ${(item.$2 * 100 / total).toStringAsFixed(0)}%'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!allowed) return const Text('관리자 로그인 후 운영 통계를 확인할 수 있습니다.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '운영 통계',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          '회원 성장과 서비스 이용 현황을 한눈에 확인하세요.',
          style: TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final value in [7, 30])
              ChoiceChip(
                label: Text('최근 $value일'),
                selected: days == value,
                onSelected:
                    busy
                        ? null
                        : (_) {
                          setState(() => days = value);
                          load();
                        },
              ),
            IconButton(
              tooltip: '새로고침',
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          TextButton(onPressed: busy ? null : load, child: Text(error!)),
        if (data != null && error == null && !busy) ...[
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final d = data!,
                  m = d['members'],
                  p = d['photos'],
                  i = d['imports'],
                  c = d['collections'];
              final columns =
                  constraints.maxWidth >= 1050
                      ? 4
                      : constraints.maxWidth >= 560
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - 16 * (columns - 1)) / columns;
              final chartsWidth =
                  constraints.maxWidth >= 760
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
              return Column(
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: width,
                        child: metric('전체 회원', m['total'], '현재 가입 회원', teal),
                      ),
                      SizedBox(
                        width: width,
                        child: metric(
                          '신규 가입',
                          m['new'],
                          '최근 ${d['days']}일',
                          teal,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: metric(
                          '판독 이용',
                          d['scans'],
                          '최근 ${d['days']}일 · 접수 기준',
                          blue,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: metric(
                          '우표 도감',
                          d['catalog'],
                          'DB에 등록된 우표',
                          teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: chartsWidth,
                        child: panel('신규 가입 추이', trend('signups', teal)),
                      ),
                      SizedBox(
                        width: chartsWidth,
                        child: panel('판독 이용 추이', trend('scans', blue)),
                      ),
                      SizedBox(
                        width: chartsWidth,
                        child: panel(
                          '회원 등급 · 현재',
                          distribution([
                            ('무료', m['free'] as int, teal),
                            ('프리미엄', m['premium'] as int, blue),
                          ], unit: '명'),
                        ),
                      ),
                      SizedBox(
                        width: chartsWidth,
                        child: panel(
                          '사진 검수 · 전체',
                          distribution([
                            (
                              '검수 대기',
                              p['pending'] as int,
                              const Color(0xffd39b3d),
                            ),
                            ('승인', p['approved'] as int, teal),
                            (
                              '반려',
                              p['rejected'] as int,
                              const Color(0xffb75b52),
                            ),
                          ]),
                        ),
                      ),
                      SizedBox(
                        width: chartsWidth,
                        child: panel(
                          '수집 활동 · 전체',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '수집 등록 ${number(c['entries'])}건\n보유 수량 ${number(c['quantity'])}장\n사진 제공 ${number(p['total'])}건',
                                style: const TextStyle(fontSize: 16, height: 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: chartsWidth,
                        child: panel(
                          '우표 수집 작업 · 최근 ${d['days']}일',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              distribution([
                                ('성공', i['success'] as int, teal),
                                (
                                  '실패',
                                  i['failed'] as int,
                                  const Color(0xffb75b52),
                                ),
                                ('진행 중', i['running'] as int, blue),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                '자동 신규 등록 ${number(i['inserted'])}건',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            '일별 집계는 UTC 기준입니다. 판독 이용은 서버가 접수한 사용량이며 판독 성공률·정확도를 의미하지 않습니다. 수집·사진은 서버 저장 자료만 포함하고, 수집 작업 이력은 기록 기능 도입 이후 자료입니다.',
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Color(0xff52675e),
            ),
          ),
        ],
      ],
    );
  }
}
