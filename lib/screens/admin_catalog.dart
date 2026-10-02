import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/recognition_service.dart';

class AdminCatalog extends StatefulWidget {
  const AdminCatalog({super.key});
  @override
  State<AdminCatalog> createState() => _AdminCatalogState();
}

class _AdminCatalogState extends State<AdminCatalog> {
  final query = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  bool busy = false, more = false;
  String filter = '전체';
  String? error;
  int page = 0, generation = 0;
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
    super.dispose();
  }

  Future<void> load() async {
    if (!allowed) return;
    final token = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (filter == '수집 이력') {
        final result = await SupabaseService.client!
            .from('catalog_import_runs')
            .select()
            .order('started_at', ascending: false)
            .range(page * 25, page * 25 + 25);
        if (mounted && token == generation) {
          setState(() {
            more = result.length > 25;
            rows = List<Map<String, dynamic>>.from(result.take(25));
          });
        }
        return;
      }
      var request =
          SupabaseService.client!.from('official_stamp_catalog').select();
      final text = query.text.trim();
      if (RegExp(r'^\d{4}$').hasMatch(text)) {
        request = request.eq('year', int.parse(text));
      } else if (RegExp(r'^\d+$').hasMatch(text)) {
        request = request.eq('id', 'epost_$text');
      } else if (text.isNotEmpty) {
        request = request.ilike(
          'name',
          '%${text.replaceAll('%', '').replaceAll('_', '')}%',
        );
      }
      if (filter == '정보 누락') {
        request = request.or(
          'data->>description.is.null,data->>description.eq.,data->>image_url.is.null,data->>image_url.eq.',
        );
      }
      if (filter == '수집 자료') {
        request = request.not('data->>fetched_at', 'is', null);
      }
      final result = await request
          .order(
            filter == '수집 자료' ? 'updated_at' : 'data->>issue_date',
            ascending: false,
          )
          .order('id')
          .range(page * 25, page * 25 + 25);
      if (mounted && token == generation) {
        setState(() {
          more = result.length > 25;
          rows = List<Map<String, dynamic>>.from(result.take(25));
        });
      }
    } catch (_) {
      if (mounted && token == generation) {
        setState(() => error = '목록을 불러오지 못했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  Future<void> edit(Map<String, dynamic> row) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => StampEditor(row: row),
    );
    if (changed == true) await load();
  }

  Future<void> recollect(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('공식 자료 다시 수집'),
            content: Text(
              '$id의 상세정보와 설명을 한국우표포털 자료로 갱신합니다. 직접 수정한 설명도 교체됩니다. 저장소에 보관된 대표 이미지는 유지합니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('재수집'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await SupabaseService.client!.functions.invoke(
        'refresh-stamp',
        body: {'id': id},
      );
      if (response.status != 200 || response.data?['ok'] != true) {
        throw StateError('refresh');
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공식 자료 갱신이 완료되었습니다.')));
      }
      await load();
    } on FunctionException catch (e) {
      if (mounted) {
        setState(
          () =>
              error =
                  e.details is Map
                      ? e.details['error']?.toString() ?? '재수집에 실패했습니다.'
                      : '재수집에 실패했습니다. 수집 이력을 확인해 주세요.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '연결이 끊겼을 수 있습니다. 수집 이력을 새로 조회해 결과를 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!allowed) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('관리자 로그인 후 우표 정보를 관리할 수 있습니다.'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: query,
          onSubmitted: (_) {
            page = 0;
            load();
          },
          decoration: InputDecoration(
            labelText: '우표명 · 발행연도(4자리) · 우표번호',
            suffixIcon: IconButton(
              onPressed: () {
                page = 0;
                load();
              },
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children:
              ['전체', '정보 누락', '수집 자료', '수집 이력']
                  .map(
                    (f) => ChoiceChip(
                      label: Text(f),
                      selected: filter == f,
                      onSelected:
                          busy
                              ? null
                              : (_) {
                                setState(() {
                                  filter = f;
                                  page = 0;
                                });
                                load();
                              },
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 16),
        if (filter == '수집 자료')
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('공식 출처에서 가져온 자료입니다. 각 우표 메뉴에서 재수집할 수 있습니다.'),
          ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) TextButton(onPressed: load, child: Text(error!)),
        if (!busy && error == null && rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('조건에 맞는 우표가 없습니다.'),
          ),
        if (filter == '수집 이력')
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '이력 기록 기능 도입 이후의 실행만 표시합니다. 진행 중이 오래 지속되면 재조회하고, 5분 후 다시 수집할 수 있습니다.',
            ),
          ),
        for (final row in filter == '수집 이력' ? rows : <Map<String, dynamic>>[])
          Card(
            elevation: 0,
            child: ListTile(
              title: Text(
                '${row['stamp_id'] ?? '신규 우표 확인'} · ${{'running': '진행 중', 'success': '완료', 'failed': '실패'}[row['status']]}',
              ),
              subtitle: Text(
                '${row['started_at']}\n${row['message']}\n처리 ${row['imported_count']}건',
              ),
              trailing:
                  row['stamp_id'] == null
                      ? null
                      : IconButton(
                        tooltip: '다시 수집',
                        onPressed:
                            busy ? null : () => recollect(row['stamp_id']),
                        icon: const Icon(Icons.refresh),
                      ),
            ),
          ),
        for (final row in filter != '수집 이력' ? rows : <Map<String, dynamic>>[])
          Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: SizedBox(
                width: 60,
                height: 65,
                child: Image.network(
                  row['data']['image_url'] ?? '',
                  fit: BoxFit.contain,
                  errorBuilder:
                      (_, __, ___) => const Icon(Icons.broken_image_outlined),
                ),
              ),
              title: Text(
                row['name'],
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${row['id']} · ${row['data']['issue_date']}\n${filter == '수집 자료' ? 'DB 갱신: ${row['updated_at']}' : row['face_value']}',
                style: const TextStyle(height: 1.7),
              ),
              trailing: PopupMenuButton<String>(
                enabled: !busy,
                onSelected: (action) {
                  if (action == 'edit') {
                    edit(row);
                  } else {
                    recollect(row['id']);
                  }
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('정보·이미지 수정')),
                      PopupMenuItem(
                        value: 'refresh',
                        child: Text('포털에서 다시 수집'),
                      ),
                    ],
              ),
              onTap: busy ? null : () => edit(row),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
                  busy || !more
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
  }
}

class StampEditor extends StatefulWidget {
  const StampEditor({super.key, required this.row});
  final Map<String, dynamic> row;
  @override
  State<StampEditor> createState() => _StampEditorState();
}

class _StampEditorState extends State<StampEditor> {
  static const fields = {
    'name': '우표명',
    'issue_date': '발행일 (YYYY-MM-DD)',
    'face_value': '액면가격',
    'design': '디자인',
    'designer': '디자이너',
    'issue_volume_display': '발행량',
    'issue_count': '종수',
    'printing': '인쇄 및 색수',
    'sheet': '전지구성',
    'size': '우표크기',
    'image_size': '인면',
    'perforation': '천공',
    'paper': '용지',
    'printer': '인쇄처',
    'image_url': '대표 이미지 HTTPS 주소',
    'description': '우표 설명',
  };
  late final inputs = {
    for (final key in fields.keys)
      key: TextEditingController(
        text: widget.row['data'][key]?.toString() ?? '',
      ),
  };
  bool saving = false;
  bool picking = false;
  Uint8List? selectedImage;
  String? error;

  Future<void> pickImage() async {
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > 15 * 1024 * 1024) throw StateError('large');
      final image = await compute(
        normalizeStampPhoto,
        await file.readAsBytes(),
      );
      if (mounted) setState(() => selectedImage = image);
    } catch (_) {
      if (mounted) {
        setState(() => error = '이미지를 읽지 못했습니다. 15MB 이하의 JPEG·PNG 사진을 선택해 주세요.');
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  void dispose() {
    for (final input in inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final date = DateTime.tryParse(inputs['issue_date']!.text.trim());
    if (date == null ||
        date.toIso8601String().split('T').first !=
            inputs['issue_date']!.text.trim() ||
        inputs['name']!.text.trim().isEmpty ||
        inputs['description']!.text.trim().isEmpty) {
      setState(() => error = '우표명·설명과 올바른 발행일을 입력해 주세요.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    String? uploaded;
    try {
      final data = Map<String, dynamic>.from(widget.row['data']);
      for (final entry in inputs.entries) {
        data[entry.key] = entry.value.text.trim();
      }
      data['year'] = date.year.toString();
      if (selectedImage != null) {
        final path =
            'admin/${widget.row['id']}/${DateTime.now().microsecondsSinceEpoch}.jpg';
        final storage = SupabaseService.client!.storage.from('official-stamps');
        await storage.uploadBinary(
          path,
          selectedImage!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        uploaded = path;
        data['image_url'] = storage.getPublicUrl(path);
      }
      await SupabaseService.client!.rpc(
        'admin_save_stamp',
        params: {
          'p_id': widget.row['id'],
          'p_expected': widget.row['updated_at'],
          'p_data': data,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      var cleanupFailed = false;
      if (uploaded != null) {
        try {
          await SupabaseService.client!.storage.from('official-stamps').remove([
            uploaded,
          ]);
        } catch (_) {
          cleanupFailed = true;
        }
      }
      if (mounted) {
        setState(
          () =>
              error =
                  '저장하지 못했습니다. 저장 용량·연결·이미지 주소를 확인해 주세요. 다른 수정과 충돌했다면 닫고 다시 조회해 주세요.${cleanupFailed ? ' 업로드 파일 정리가 되지 않았으므로 저장소 확인이 필요합니다.' : ''}',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !picking,
    child: AlertDialog(
      title: Text('우표 수정 · ${widget.row['id']}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('대표 이미지를 선택하고 미리보기를 확인해 주세요. 파일은 저장 버튼을 누르면 업로드됩니다.'),
              if (selectedImage != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.memory(selectedImage!, height: 180),
                ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: saving || picking ? null : pickImage,
                    icon: const Icon(Icons.upload_outlined),
                    label: Text(picking ? '사진 처리 중…' : '이미지 파일 선택'),
                  ),
                  if (selectedImage != null)
                    TextButton(
                      onPressed:
                          saving
                              ? null
                              : () => setState(() => selectedImage = null),
                      child: const Text('선택 취소'),
                    ),
                ],
              ),
              for (final entry in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    controller: inputs[entry.key],
                    enabled:
                        !saving &&
                        !picking &&
                        !(entry.key == 'image_url' && selectedImage != null),
                    maxLines: entry.key == 'description' ? 7 : 1,
                    decoration: InputDecoration(
                      labelText: entry.value,
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving || picking ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: saving || picking ? null : save,
          child: Text(saving ? '저장 중…' : '변경사항 저장'),
        ),
      ],
    ),
  );
}
