import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AdminAnnouncements extends StatefulWidget {
  const AdminAnnouncements({super.key});
  @override
  State<AdminAnnouncements> createState() => _AdminAnnouncementsState();
}

class _AdminAnnouncementsState extends State<AdminAnnouncements> {
  List<Map<String, dynamic>> rows = [];
  int page = 0;
  bool busy = false, more = false;
  String? error;
  late final String? owner = SupabaseService.currentUser?.id;
  bool get allowed =>
      owner != null &&
      SupabaseService.currentUser?.id == owner &&
      SupabaseService.currentUser?.appMetadata['stamp_admin'] == true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!allowed) return;
    setState(() {
      busy = true;
      error = null;
      rows = [];
    });
    try {
      final value = await SupabaseService.client!
          .from('member_announcements')
          .select()
          .order('created_at', ascending: false)
          .order('id')
          .range(page * 20, page * 20 + 20)
          .timeout(const Duration(seconds: 15));
      if (mounted && allowed) {
        setState(() {
          more = value.length > 20;
          rows = value.take(20).toList();
        });
      }
    } catch (_) {
      if (mounted && allowed) {
        setState(() => error = '공지를 불러오지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    if (!allowed || busy) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _AnnouncementEditor(row: row)),
    );
    if (mounted && allowed && saved == true) await load();
  }

  Future<void> publish(Map<String, dynamic> row) async {
    if (!allowed || busy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('회원 공지로 게시할까요?'),
            content: Text(
              '${row['title']}\n\n모든 회원의 알림함에 표시됩니다. 게시 후에는 수정할 수 없습니다. 실제 푸시는 발송되지 않습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('게시'),
              ),
            ],
          ),
    );
    if (yes != true || !mounted || !allowed) return;
    setState(() => busy = true);
    try {
      await SupabaseService.client!
          .rpc('publish_member_announcement', params: {'p_id': row['id']})
          .timeout(const Duration(seconds: 15));
      if (mounted && allowed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('회원 알림함에 공지를 게시했어요.')));
        await load();
      }
    } catch (_) {
      if (mounted && allowed) {
        setState(() => error = '게시 결과를 확인하지 못했어요. 새로고침해 상태를 확인하세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      !allowed
          ? const Text('관리자 권한이 필요합니다.')
          : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 12,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '회원 공지',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text('초안을 저장한 후 게시하면 회원 알림함에 표시됩니다.'),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : () => edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('공지 작성'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: busy ? null : load,
                  child: const Text('새로고침'),
                ),
              ],
              if (!busy && error == null && rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('작성한 공지가 없습니다.', textAlign: TextAlign.center),
                ),
              ...rows.map(
                (row) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['status'] == 'published' ? '게시 완료' : '초안',
                          style: TextStyle(
                            color:
                                row['status'] == 'published'
                                    ? Colors.blue
                                    : Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          row['title'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          row['body'] as String,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Text('${row['created_at']}'.split('T').first),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: busy ? null : () => edit(row),
                              child: Text(
                                row['status'] == 'published'
                                    ? '내용 보기'
                                    : '초안 수정',
                              ),
                            ),
                            if (row['status'] == 'draft')
                              FilledButton(
                                onPressed: busy ? null : () => publish(row),
                                child: const Text('회원에게 게시'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        busy || page == 0
                            ? null
                            : () {
                              setState(() => page--);
                              load();
                            },
                    child: const Text('이전'),
                  ),
                  Text('${page + 1} 페이지'),
                  TextButton(
                    onPressed:
                        busy || !more
                            ? null
                            : () {
                              setState(() => page++);
                              load();
                            },
                    child: const Text('다음'),
                  ),
                ],
              ),
            ],
          );
}

class _AnnouncementEditor extends StatefulWidget {
  const _AnnouncementEditor({this.row});
  final Map<String, dynamic>? row;
  @override
  State<_AnnouncementEditor> createState() => _AnnouncementEditorState();
}

class _AnnouncementEditorState extends State<_AnnouncementEditor> {
  late final title = TextEditingController(
    text: widget.row?['title'] as String? ?? '',
  );
  late final body = TextEditingController(
    text: widget.row?['body'] as String? ?? '',
  );
  late final String? owner = SupabaseService.currentUser?.id;
  bool busy = false;
  String? error;
  bool get editable => widget.row?['status'] != 'published';
  final form = GlobalKey<FormState>();
  bool get allowed =>
      owner != null &&
      SupabaseService.currentUser?.id == owner &&
      SupabaseService.currentUser?.appMetadata['stamp_admin'] == true;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!allowed || busy || !editable || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final data = {'title': title.text.trim(), 'body': body.text.trim()};
      if (widget.row == null) {
        await SupabaseService.client!
            .from('member_announcements')
            .insert({...data, 'created_by': owner})
            .timeout(const Duration(seconds: 15));
      } else {
        await SupabaseService.client!
            .from('member_announcements')
            .update(data)
            .eq('id', widget.row!['id'])
            .eq('status', 'draft')
            .select('id')
            .single()
            .timeout(const Duration(seconds: 15));
      }
      if (mounted && allowed) Navigator.pop(context, true);
    } catch (_) {
      if (mounted && allowed) {
        setState(() => error = '저장하지 못했어요. 새로고침 후 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(editable ? '공지 작성' : '게시된 공지')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: title,
                readOnly: !editable || busy,
                maxLength: 160,
                decoration: const InputDecoration(labelText: '제목'),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? '제목을 입력해 주세요.'
                            : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: body,
                readOnly: !editable || busy,
                minLines: 8,
                maxLines: 20,
                maxLength: 10000,
                decoration: const InputDecoration(labelText: '내용'),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? '내용을 입력해 주세요.'
                            : null,
              ),
              const SizedBox(height: 20),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (editable)
                FilledButton(
                  onPressed: busy || !allowed ? null : save,
                  child: Text(busy ? '저장 중…' : '초안 저장'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
