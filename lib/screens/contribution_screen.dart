import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/contribution_service.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key, this.photo, this.stampId});
  final Uint8List? photo;
  final String? stampId;
  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  bool reference = false, training = false, busy = false;
  String? selected;
  List<Map<String, dynamic>> matches = [], rows = [];
  String message = '';
  int searchGeneration = 0;
  @override
  void initState() {
    super.initState();
    selected = widget.stampId;
    load();
  }

  Future<void> load() async {
    try {
      final data = await ContributionService.client
          .from('photo_contributions')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) setState(() => rows = List<Map<String, dynamic>>.from(data));
    } catch (_) {
      if (mounted) {
        setState(() => message = '목록을 불러오지 못했어요. 로그인과 연결 상태를 확인해 주세요.');
      }
    }
  }

  Future<void> search(String text) async {
    final generation = ++searchGeneration;
    if (text.trim().length < 2) return;
    try {
      final data = await ContributionService.client
          .from('official_stamp_catalog')
          .select('id,data')
          .ilike('data->>name', '%${text.trim()}%')
          .limit(12);
      if (mounted && generation == searchGeneration) {
        setState(() => matches = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {
      if (mounted) setState(() => message = '우표 검색을 다시 시도해 주세요.');
    }
  }

  Future<void> action(Future<void> Function() run) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await run();
      await load();
    } catch (_) {
      if (mounted) {
        setState(() => message = '처리하지 못했어요. 로그인과 연결 상태를 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(Map<String, dynamic> row) async {
    try {
      final url = await ContributionService.client.storage
          .from(ContributionService.bucket)
          .createSignedUrl(row['image_path'], 300);
      final record =
          await ContributionService.client
              .from('official_stamp_catalog')
              .select('data')
              .eq('id', row['stamp_id'])
              .single();
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(record['data']['name'] ?? '정답 검수'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(url, height: 180),
                    const Text('회원 사진'),
                    Image.network(
                      record['data']['image_url'] ?? '',
                      height: 180,
                    ),
                    const Text(
                      '공식 원본과 도안·액면·발행연도를 비교해 주세요. 불명확하거나 다른 우표이면 반려합니다.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('반려'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('정답 승인'),
                ),
              ],
            ),
      );
      if (accepted == null) return;
      await ContributionService.client
          .from('photo_contributions')
          .update({
            'status': accepted ? 'approved' : 'rejected',
            'reviewed_by': ContributionService.client.auth.currentUser!.id,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', row['id']);
    } catch (_) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('판독 개선 사진')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.photo != null) ...[
          Image.memory(widget.photo!, height: 200),
          const SizedBox(height: 16),
          const Text(
            '사진의 정확한 우표를 확인해 주세요.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextField(
            onSubmitted: search,
            decoration: const InputDecoration(
              labelText: '우표 이름 검색 후 검색 키를 눌러주세요',
            ),
          ),
          for (final item in matches)
            RadioListTile<String>(
              value: item['id'],
              groupValue: selected,
              onChanged: busy ? null : (v) => setState(() => selected = v),
              title: Text(item['data']['name'] ?? item['id']),
            ),
          if (selected != null) Text('선택한 우표: $selected'),
          CheckboxListTile(
            value: reference,
            onChanged: busy ? null : (v) => setState(() => reference = v!),
            title: const Text('판독 비교 자료로 사진 제공 (선택)'),
            subtitle: const Text(
              '비공개 저장 후 관리자 검수에 사용합니다. 승인된 사진은 다른 회원의 판독 시 Gemini에 비교 자료로 전송됩니다. 동의하지 않아도 판독·수집 기능을 사용할 수 있습니다.',
            ),
          ),
          CheckboxListTile(
            value: training,
            onChanged: busy ? null : (v) => setState(() => training = v!),
            title: const Text('향후 AI 추가 학습에도 사용 (선택)'),
            subtitle: const Text(
              '별도 동의한 승인 사진만 학습 데이터 후보로 사용합니다. 저장만으로 AI가 자동 학습되지는 않습니다.',
            ),
          ),
          const Text(
            '직접 촬영한 우표 사진만 제공해 주세요. 얼굴·주소 등 개인정보가 포함된 사진은 제외해 주세요. 아래 목록에서 철회하면 비교와 향후 학습 대상에서 제외됩니다. 이미 학습을 마친 모델에서 개별 사진의 영향을 즉시 제거할 수는 없습니다.',
          ),
          FilledButton(
            onPressed:
                busy || !reference || selected == null
                    ? null
                    : () => action(() async {
                      await ContributionService.submit(
                        widget.photo!,
                        selected!,
                        training,
                      );
                      if (mounted) {
                        setState(() {
                          reference = false;
                          training = false;
                          message = '검수 대기로 접수했어요.';
                        });
                      }
                    }),
            child: const Text('동의하고 사진 제공'),
          ),
        ],
        if (message.isNotEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(message)),
        const SizedBox(height: 20),
        Text(
          ContributionService.isAdmin ? '사진 검수 목록' : '내가 제공한 사진',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('제공된 사진이 없습니다.'),
          ),
        for (final row in rows)
          ListTile(
            title: Text(row['stamp_id']),
            subtitle: Text(
              '${{'pending': '검수 대기', 'approved': '승인', 'rejected': '반려'}[row['status']]} · 학습 동의 ${row['training_consent'] == true ? '있음' : '없음'}',
            ),
            trailing: Wrap(
              children: [
                if (ContributionService.isAdmin)
                  IconButton(
                    tooltip: '원본 비교 검수',
                    onPressed: busy ? null : () => action(() => review(row)),
                    icon: const Icon(Icons.fact_check_outlined),
                  ),
                if (row['user_id'] ==
                    ContributionService.client.auth.currentUser?.id)
                  IconButton(
                    tooltip: '제공 철회',
                    onPressed:
                        busy
                            ? null
                            : () =>
                                action(() => ContributionService.withdraw(row)),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ),
        TextButton(onPressed: busy ? null : load, child: const Text('새로고침')),
      ],
    ),
  );
}
