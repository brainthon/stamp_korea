import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MembershipPolicyScreen extends StatelessWidget {
  const MembershipPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('회원별 이용 안내')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '둘러보기부터 나만의 수집까지',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text('우표 도감과 공식 발행 정보는 누구나 볼 수 있어요.'),
            const SizedBox(height: 24),
            _plan(context, '가입 없이 둘러보기', Icons.explore_outlined, [
              '오늘의 우표와 최근 발행 우표',
              '우표 도감 · 연도 검색 · 테마 탐색',
              '공식 우표 이미지와 상세 설명',
            ]),
            _plan(context, '무료회원', Icons.collections_bookmark_outlined, [
              '수집함 등록 · 상태별 수량 · 보관 위치 · 메모',
              '위시리스트로 찾고 싶은 우표 기록',
              '사진 판독 · 현재 하루 최대 20회',
            ]),
            _plan(context, '프리미엄 · 준비 중', Icons.workspace_premium_outlined, [
              '판독 이용량 확대',
              '고급 수집 분석 · 일괄 정리 · 인쇄용 보고서',
              '광고 도입 시 광고 제거',
            ], planned: true),
            const SizedBox(height: 8),
            const Text(
              '수집함에는 공식 도감 이미지를 사용해요.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '촬영 사진은 판독에만 사용하며 수집함에 자동 보관하지 않아요. 판독 개선을 위한 사진 제공은 별도의 선택 동의로 진행해요.',
            ),
            const SizedBox(height: 16),
            const Text(
              '현재 위시리스트는 이 기기에 저장됩니다. 기기 간 동기화와 프리미엄 결제·추가 혜택은 준비 중이며, 아직 이용할 수 없습니다.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _plan(
    BuildContext context,
    String title,
    IconData icon,
    List<String> benefits, {
    bool planned = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: planned ? AppTheme.peach : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.borderGray),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryBlack, size: 28),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final benefit in benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  planned ? Icons.schedule : Icons.check,
                  size: 18,
                  color: AppTheme.primaryBlack,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(benefit)),
              ],
            ),
          ),
      ],
    ),
  );
}
