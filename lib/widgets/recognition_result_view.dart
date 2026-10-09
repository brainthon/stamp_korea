import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/recognition_service.dart';
import '../theme/app_theme.dart';
import '../models/official_stamp.dart';
import 'stamp_facts.dart';

class RecognitionResultView extends StatefulWidget {
  const RecognitionResultView({
    super.key,
    required this.result,
    required this.photo,
    required this.onBack,
    required this.onChoose,
    required this.onSave,
    this.collected = false,
    this.onSelectCandidate,
    this.onContribute,
    this.onFeedback,
  });
  final Recognition result;
  final Uint8List? photo;
  final VoidCallback onBack, onChoose, onSave;
  final bool collected;
  final VoidCallback? onContribute;
  final VoidCallback? onFeedback;
  final ValueChanged<OfficialStamp>? onSelectCandidate;
  @override
  State<RecognitionResultView> createState() => _RecognitionResultViewState();
}

class _RecognitionResultViewState extends State<RecognitionResultView> {
  static const green = AppTheme.primaryBlack;
  static const muted = AppTheme.textMuted;
  Future<void> source() async {
    final uri = Uri.tryParse(widget.result.official?.sourceUrl ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'stamp.epost.go.kr') {
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('link');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공식 페이지를 열지 못했어요. 잠시 후 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result, official = result.official;
    final paragraphs = official?.description.split('\n\n') ?? <String>[];
    final title =
        official?.name ??
        (result.isStamp && result.name.isNotEmpty
            ? result.candidates.isNotEmpty
                ? '같은 우표를 골라주세요'
                : '${result.name} (추정)'
            : '우표를 확인하지 못했어요');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        if (widget.onFeedback != null)
          TextButton.icon(
            onPressed: widget.onFeedback,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('판독 결과 확인 · 오류 신고'),
          ),
        if (widget.onContribute != null)
          TextButton.icon(
            onPressed: widget.onContribute,
            icon: const Icon(Icons.volunteer_activism_outlined),
            label: const Text('판독 개선 사진 제공'),
          ),
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              tooltip: '사진 선택으로 돌아가기',
              icon: const Icon(Icons.arrow_back),
            ),
            const Expanded(
              child: Text(
                '판독 결과',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(onPressed: widget.onBack, child: const Text('다시 촬영')),
          ],
        ),
        const SizedBox(height: 14),
        if (official != null && official.value('image_url').isNotEmpty)
          StampDetailImage(
            url: official.value('image_url'),
            label: official.name,
          )
        else
          Container(
            height: 250,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.subtleGray,
              borderRadius: BorderRadius.circular(22),
            ),
            child:
                widget.photo == null
                    ? const Icon(Icons.local_post_office_outlined, size: 70)
                    : Image.memory(
                      widget.photo!,
                      fit: BoxFit.contain,
                      semanticLabel: '판독한 우표 사진',
                    ),
          ),
        const SizedBox(height: 26),
        if (official != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              result.matchStatus == 'user_selected'
                  ? '직접 선택한 우표 · 공식 자료'
                  : 'AI와 공식 DB 대조 결과',
              style: const TextStyle(
                color: green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Text(
          official == null
              ? '사진에서 찾은 우표'
              : '${official.value('country')} · ${official.value('category')}',
          style: const TextStyle(color: muted, fontSize: 12, letterSpacing: .4),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.4,
            color: green,
          ),
        ),
        const SizedBox(height: 20),
        if (official != null) ...[
          StampFacts(fields: official.toStamp().officialDetails),
          const SizedBox(height: 30),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '우표 설명',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.article_outlined, size: 15, color: muted),
              const SizedBox(width: 5),
              const Text(
                '공식 발행 정보',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            paragraphs.join('\n\n'),
            style: const TextStyle(
              fontSize: 14,
              height: 1.9,
              color: Color(0xFF35463F),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: source,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('출처 · 한국우표포털', style: TextStyle(fontSize: 12)),
            ),
          ),
          const Divider(height: 28),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.onSave,
            icon: const Icon(Icons.add),
            label: Text(widget.collected ? '수집 기록 편집' : '이 우표를 수집함에 추가'),
          ),
          TextButton(
            onPressed: widget.onChoose,
            child: const Text('다른 우표인가요?'),
          ),
        ] else ...[
          if (result.candidates.isNotEmpty) ...[
            const Text(
              '비슷한 우표를 찾았어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '도안과 액면가를 비교해 같은 우표를 선택해 주세요.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            ...result.candidates.map(
              (candidate) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: SizedBox(
                      width: 52,
                      height: 64,
                      child: Image.network(
                        candidate.value('image_url'),
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => const Icon(Icons.image_outlined),
                      ),
                    ),
                    title: Text(
                      candidate.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${candidate.value('design')}\n${candidate.value('year')} · ${candidate.value('face_value')} · ${candidate.value('stamp_number')}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        widget.onSelectCandidate == null
                            ? null
                            : () => widget.onSelectCandidate!(candidate),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (result.isStamp) ...[
            Wrap(
              spacing: 24,
              runSpacing: 14,
              children: [
                if (result.country.isNotEmpty) fact('국가', result.country),
                if (result.year.isNotEmpty) fact('사진 속 연도', result.year),
                if (result.faceValue.isNotEmpty)
                  fact('사진 속 액면가', result.faceValue),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              result.matchStatus == 'catalog_unavailable'
                  ? '도감 연결이 잠시 원활하지 않아요.'
                  : result.candidates.isNotEmpty
                  ? '사진만으로 확정하지 않았어요.'
                  : '공식 설명을 아직 연결하지 못했어요.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '우표 영역을 자른 뒤 다시 판독하거나, 액면가와 글자가 보이게 정면에서 촬영해 주세요. 도감에서 직접 선택할 수도 있어요.',
              style: TextStyle(color: muted, height: 1.7),
            ),
          ] else
            const Text(
              '우표 한 장이 선명하게 보이도록 다시 촬영해 주세요.',
              style: TextStyle(color: muted, height: 1.7),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: result.isStamp ? widget.onChoose : widget.onBack,
            child: Text(result.isStamp ? '도감에서 우표 찾기' : '사진 다시 선택'),
          ),
        ],
      ],
    );
  }

  Widget fact(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: green,
        ),
      ),
    ],
  );
}
