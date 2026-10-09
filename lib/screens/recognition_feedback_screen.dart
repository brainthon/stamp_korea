import 'package:flutter/material.dart';
import '../services/recognition_service.dart';
import '../services/supabase_service.dart';
import '../services/account_settings_service.dart';

Future<String?> selectEvaluationStamp(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (_) => const _StampPicker(),
  );
}

class _StampPicker extends StatefulWidget {
  const _StampPicker();
  @override
  State<_StampPicker> createState() => _StampPickerState();
}

class _StampPickerState extends State<_StampPicker> {
  List<Map<String, dynamic>> rows = [];
  int generation = 0;
  String message = '우표명 또는 발행연도를 검색해 주세요.';
  Future<void> search(String text) async {
    final ticket = ++generation;
    if (text.trim().isEmpty) {
      setState(() => rows = []);
      return;
    }
    try {
      final query = SupabaseService.client!
          .from('official_stamp_catalog')
          .select('id,data');
      final year = int.tryParse(text.trim());
      final result =
          year != null && text.trim().length == 4
              ? await query.eq('data->>year', '$year').limit(20)
              : await query
                  .ilike(
                    'data->>name',
                    '%${text.trim().replaceAll('%', '').replaceAll('_', '')}%',
                  )
                  .limit(20);
      if (mounted && ticket == generation) {
        setState(() {
          rows = List<Map<String, dynamic>>.from(result);
          message = rows.isEmpty ? '검색 결과가 없습니다.' : '';
        });
      }
    } catch (_) {
      if (mounted && ticket == generation) {
        setState(() => message = '검색하지 못했습니다. 다시 시도해 주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('정답 우표 선택'),
    content: SizedBox(
      width: 480,
      height: 380,
      child: Column(
        children: [
          TextField(
            onSubmitted: search,
            decoration: const InputDecoration(
              labelText: '우표명 / 발행연도',
              suffixIcon: Icon(Icons.search),
              helperText: '입력 후 검색 키를 눌러주세요.',
            ),
          ),
          if (message.isNotEmpty)
            Padding(padding: const EdgeInsets.all(12), child: Text(message)),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i];
                final d = r['data'] as Map;
                return ListTile(
                  title: Text('${d['name']}'),
                  subtitle: Text(
                    '${d['year'] ?? ''} · ${d['face_value'] ?? ''}',
                  ),
                  onTap: () => Navigator.pop(context, r['id'] as String),
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
    ],
  );
}

class RecognitionFeedbackScreen extends StatefulWidget {
  const RecognitionFeedbackScreen({super.key, required this.result});
  final Recognition result;
  @override
  State<RecognitionFeedbackScreen> createState() =>
      _RecognitionFeedbackScreenState();
}

class _RecognitionFeedbackScreenState extends State<RecognitionFeedbackScreen> {
  late final String owner = SupabaseService.currentUser!.id;
  String kind = 'unknown', message = '';
  String? proposed;
  bool busy = false, locked = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      AccountSettingsService.checkOwner(owner);
      final row =
          await SupabaseService.client!
              .from('recognition_feedback')
              .select()
              .eq('run_id', widget.result.recognitionId!)
              .eq('user_id', owner)
              .maybeSingle();
      AccountSettingsService.checkOwner(owner);
      if (mounted && row != null) {
        setState(() {
          kind = row['kind'];
          proposed = row['proposed_id'];
          locked = row['status'] != 'pending';
          message = locked ? '관리자가 검수한 기록입니다.' : '제출한 답변을 수정할 수 있습니다.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          locked = true;
          message = '기록을 불러오지 못했습니다. 다시 열어 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      AccountSettingsService.checkOwner(owner);
      final table = SupabaseService.client!.from('recognition_feedback');
      final existing =
          await table
              .select('status')
              .eq('run_id', widget.result.recognitionId!)
              .eq('user_id', owner)
              .maybeSingle();
      AccountSettingsService.checkOwner(owner);
      final values = {
        'kind': kind,
        'proposed_id': kind == 'unknown' ? null : proposed,
      };
      if (existing == null) {
        await table.insert({
          ...values,
          'run_id': widget.result.recognitionId,
          'user_id': owner,
        });
      } else {
        if (existing['status'] != 'pending') throw StateError('검수 완료');
        await table
            .update(values)
            .eq('run_id', widget.result.recognitionId!)
            .eq('user_id', owner)
            .eq('status', 'pending')
            .select('run_id')
            .single();
      }
      AccountSettingsService.checkOwner(owner);
      if (mounted) setState(() => message = '접수되었습니다. 관리자 검수 후 평가에 반영됩니다.');
    } catch (_) {
      if (mounted) setState(() => message = '저장하지 못했습니다. 계정이나 검수 상태를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('판독 결과 확인')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.result.official?.name ?? '우표를 확정하지 못했습니다.',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text('정답을 알고 있다면 알려주세요. 사진은 이 화면에서 저장하지 않습니다.'),
        ...['correct', 'incorrect', 'unknown']
            .where((k) => k != 'correct' || widget.result.official != null)
            .map(
              (k) => ListTile(
                leading: Icon(
                  kind == k
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(
                  {
                    'correct': '이 우표가 맞아요',
                    'incorrect': '다른 우표예요',
                    'unknown': '정답을 모르겠어요',
                  }[k]!,
                ),
                onTap:
                    busy || locked
                        ? null
                        : () => setState(() {
                          kind = k;
                          proposed =
                              k == 'correct'
                                  ? widget.result.official!.id
                                  : null;
                        }),
              ),
            ),
        if (kind == 'incorrect')
          OutlinedButton(
            onPressed:
                busy || locked
                    ? null
                    : () async {
                      final id = await selectEvaluationStamp(context);
                      if (id != null && mounted) setState(() => proposed = id);
                    },
            child: Text(proposed == null ? '정답 우표 선택' : '정답 우표 선택됨 · 변경'),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed:
              busy || locked || (kind == 'incorrect' && proposed == null)
                  ? null
                  : save,
          child: Text(busy ? '처리 중…' : '답변 저장'),
        ),
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(message),
          ),
      ],
    ),
  );
}
