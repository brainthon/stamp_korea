import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/account_settings_service.dart';
import '../services/stamp_repository.dart';
import 'recognition_feedback_screen.dart';

class AdminRecognition extends StatefulWidget {
  const AdminRecognition({super.key});
  @override
  State<AdminRecognition> createState() => _AdminRecognitionState();
}

class _AdminRecognitionState extends State<AdminRecognition> {
  late final String owner = SupabaseService.currentUser!.id;
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic> summary = {};
  String? error;
  bool busy = false;
  int page = 0;
  void guard() {
    AccountSettingsService.checkOwner(owner);
    if (SupabaseService.currentUser!.appMetadata['stamp_admin'] != true) {
      throw StateError('관리자 권한 필요');
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      guard();
      final sb = SupabaseService.client!;
      final totals = await sb.rpc('recognition_evaluation_summary');
      final runs = await sb
          .from('recognition_runs')
          .select('*,recognition_feedback(*)')
          .gte(
            'created_at',
            DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 30))
                .toIso8601String(),
          )
          .order('created_at', ascending: false)
          .range(page * 25, page * 25 + 24);
      guard();
      if (mounted) {
        setState(() {
          summary = Map<String, dynamic>.from(totals as Map);
          rows = List<Map<String, dynamic>>.from(runs);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '판독 기록을 불러오지 못했습니다. 관리자 권한과 연결을 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int n(String key) => (summary[key] as num? ?? 0).toInt();
  String title(dynamic id) =>
      id == null
          ? '미확정'
          : StampRepository.getStampById(id.toString())?.name ?? id.toString();
  Map<String, dynamic>? feedback(Map<String, dynamic> r) {
    final f = r['recognition_feedback'];
    return f is Map
        ? Map<String, dynamic>.from(f)
        : f is List && f.isNotEmpty
        ? Map<String, dynamic>.from(f.first as Map)
        : null;
  }

  Future<void> detail(Map<String, dynamic> row) async {
    final f = feedback(row);
    String? truth = f?['proposed_id'];
    String note = '';
    bool saving = false;
    List<String> photos = [];
    try {
      guard();
      final images = await SupabaseService.client!
          .from('photo_contributions')
          .select('image_path')
          .eq('recognition_run_id', row['id'])
          .eq('reference_consent', true);
      for (final image in images.take(3)) {
        photos.add(
          await SupabaseService.client!.storage
              .from('recognition-contributions')
              .createSignedUrl(image['image_path'], 60),
        );
      }
      guard();
    } catch (_) {
      note = '동의 사진을 불러오지 못했습니다.';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, update) => AlertDialog(
                  title: const Text('판독 기록 검수'),
                  content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI 결과: ${title(row['predicted_id'])}\n상태: ${row['outcome']}\n오류: ${row['error_code'] ?? '없음'}\n처리 시간: ${row['duration_ms']}ms\n모델: ${row['model']}\n버전: ${row['algorithm_version']}',
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '회원 답변: ${f?['kind'] ?? '미제출'}\n제안 정답: ${title(f?['proposed_id'])}\n검수 상태: ${f?['status'] ?? '미제출'}',
                          ),
                          if (photos.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                '동의받은 원본 사진이 없습니다. 결과 메타데이터만으로 정답을 확정하지 마세요.',
                              ),
                            ),
                          ...photos.map(
                            (url) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Image.network(
                                url,
                                height: 240,
                                errorBuilder:
                                    (_, e, stack) =>
                                        const Text('사진 링크가 만료되었습니다. 다시 열어주세요.'),
                              ),
                            ),
                          ),
                          OutlinedButton(
                            onPressed:
                                saving
                                    ? null
                                    : () async {
                                      final id = await selectEvaluationStamp(
                                        context,
                                      );
                                      if (id != null && context.mounted) {
                                        update(() => truth = id);
                                      }
                                    },
                            child: Text(
                              truth == null
                                  ? '검증한 정답 선택'
                                  : '정답: ${title(truth)}',
                            ),
                          ),
                          if (note.isNotEmpty) Text(note),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          saving ? null : () => Navigator.pop(dialogContext),
                      child: const Text('닫기'),
                    ),
                    if (f != null)
                      TextButton(
                        onPressed:
                            saving
                                ? null
                                : () async {
                                  update(() => saving = true);
                                  try {
                                    guard();
                                    await SupabaseService.client!
                                        .from('recognition_feedback')
                                        .update({
                                          'status': 'unscorable',
                                          'ground_truth_id': null,
                                          'reviewed_by': owner,
                                          'reviewed_at':
                                              DateTime.now()
                                                  .toUtc()
                                                  .toIso8601String(),
                                        })
                                        .eq('run_id', row['id']);
                                    guard();
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  } catch (_) {
                                    if (dialogContext.mounted) {
                                      update(() {
                                        note = '저장하지 못했습니다.';
                                        saving = false;
                                      });
                                    }
                                  }
                                },
                        child: const Text('평가 제외'),
                      ),
                    if (f != null)
                      FilledButton(
                        onPressed:
                            saving || truth == null || photos.isEmpty
                                ? null
                                : () async {
                                  update(() => saving = true);
                                  try {
                                    guard();
                                    await SupabaseService.client!
                                        .from('recognition_feedback')
                                        .update({
                                          'status': 'verified',
                                          'ground_truth_id': truth,
                                          'reviewed_by': owner,
                                          'reviewed_at':
                                              DateTime.now()
                                                  .toUtc()
                                                  .toIso8601String(),
                                        })
                                        .eq('run_id', row['id']);
                                    guard();
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  } catch (_) {
                                    if (dialogContext.mounted) {
                                      update(() {
                                        note = '저장하지 못했습니다.';
                                        saving = false;
                                      });
                                    }
                                  }
                                },
                        child: const Text('정답 검수 완료'),
                      ),
                  ],
                ),
          ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              '사진 판독 평가 · 오류 기록',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: busy ? null : load,
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text('최근 30일 · 정답률은 관리자 검수가 완료된 표본만 집계합니다.'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          metric('판독 요청', '${n('total')}'),
          metric('요청·처리 오류', '${n('technical_errors')}'),
          metric('검수 대기', '${n('pending')}'),
          metric('검수 표본', '${n('verified')}'),
          metric(
            '검수 표본 정답률',
            n('verified') == 0
                ? '표본 없음'
                : '${(100 * n('identified_correct') / n('verified')).toStringAsFixed(1)}% (${n('identified_correct')}/${n('verified')})',
          ),
          metric(
            '확정 결과 중 오판',
            n('verified_matches') == 0
                ? '표본 없음'
                : '${n('false_confirmations')}/${n('verified_matches')}',
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (busy) const LinearProgressIndicator(),
      if (error != null) Text(error!),
      if (!busy && error == null && rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('판독 기록이 없습니다. 새 사진 판독부터 기록됩니다.'),
        ),
      ...rows.map((r) {
        final f = feedback(r);
        return Card(
          child: ListTile(
            leading: Icon(
              r['error_code'] == null
                  ? Icons.document_scanner_outlined
                  : Icons.error_outline,
              color: r['error_code'] == null ? Colors.blue : Colors.red,
            ),
            title: Text(title(r['predicted_id'])),
            subtitle: Text(
              '${r['created_at']} · ${r['outcome']}\n${r['error_code'] ?? '오류 없음'} · ${f?['status'] ?? '답변 미제출'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => detail(r),
          ),
        );
      }),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
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
          Text('${page + 1} 페이지'),
          TextButton(
            onPressed:
                busy || rows.length < 25
                    ? null
                    : () {
                      page++;
                      load();
                    },
            child: const Text('다음'),
          ),
        ],
      ),
    ],
  );
  Widget metric(String label, String value) => Container(
    width: 220,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe2e7ed)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
