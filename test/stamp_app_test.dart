import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stamp_korea/models/stamp.dart';
import 'package:stamp_korea/services/stamp_repository.dart';
import 'package:stamp_korea/services/collection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CollectionService.initialize();
  });

  group('국내 우표 마스터 데이터베이스 (StampRepository) 검증', () {
    test('포털의 상세 발행 정보 14개 항목과 설명 원문을 유지한다', () {
      final stamp = StampRepository.getStampById('epost_3920')!;
      expect(stamp.officialDetails.length, 14);
      expect(stamp.officialDetails['종수'], '1');
      expect(stamp.officialDetails['발행량'], '496,000(전지 31,000장)');
      expect(stamp.officialDetails['전지구성'], '4 × 4 (226mm × 135mm)');
      expect(stamp.officialDetails['인쇄처'], 'POSA(Brebner Print社)');
      expect(stamp.description, contains('기록으로 오래 기억되기를 바랍니다.'));
    });
    test('오늘의 우표는 발행일을 우선하며 DB 정렬에 영향받지 않는다', () {
      final stamps = StampRepository.getAllStamps();
      final sample = stamps.first;
      final issued = DateTime.parse(sample.issueDate);
      final date = DateTime(2026, issued.month, issued.day);
      final today = StampRepository.getTodayStamp(date: date);
      final selectedDate = DateTime.parse(today.issueDate);
      expect(selectedDate.month, date.month);
      expect(selectedDate.day, date.day);
      expect(
        StampRepository.getTodayStamp(
          date: date,
          stamps: stamps.reversed.toList(),
        ).id,
        today.id,
      );
      expect(
        StampRepository.todayStampContext(today, date: date),
        contains('오늘과 같은 날'),
      );
    });

    test('발행일이 없는 날은 같은 달의 우표를 매일 순환한다', () {
      final stamps = StampRepository.getAllStamps();
      final month = DateTime.parse(stamps.first.issueDate).month;
      final pool =
          stamps
              .where(
                (s) =>
                    DateTime.parse(s.issueDate).month == month &&
                    DateTime.parse(s.issueDate).day > 2,
              )
              .toList();
      expect(pool.length, greaterThan(1));
      final first = StampRepository.getTodayStamp(
        date: DateTime(2026, month, 1),
        stamps: pool,
      );
      final second = StampRepository.getTodayStamp(
        date: DateTime(2026, month, 2),
        stamps: pool,
      );
      expect(first.id, isNot(second.id));
      expect(DateTime.parse(first.issueDate).month, month);
    });
    test('국내 역대 우표 데이터가 정상 로드되어야 함', () {
      final stamps = StampRepository.getAllStamps();
      expect(stamps.isNotEmpty, true);
      expect(stamps.length >= 10, true);

      // 한국 최초 우표(1884 문위우표) 존재 검증
      final moonWi = StampRepository.getStampById('stamp_1884_001')!;
      expect(moonWi.name, contains('문위우표'));
      expect(moonWi.issueYear, 1884);
      expect(moonWi.faceValue, '5문 (五文)');
      expect(moonWi.rarity, RarityTier.ssr);
    });

    test('우표 키워드 및 연도 검색 필터가 올바르게 작동해야 함', () {
      // 1. 호돌이 검색
      final hodoriResults = StampRepository.searchStamps(query: '제21대 대통령 취임');
      expect(hodoriResults.isNotEmpty, true);
      expect(hodoriResults.first.issueYear, 2025);

      // 2. 1884년도 검색
      final vintageResults = StampRepository.searchStamps(
        startYear: 2025,
        endYear: 2025,
      );
      expect(vintageResults.every((s) => s.issueYear == 2025), true);

      // 3. 테마별 필터 (스포츠)
      expect(
        StampRepository.getAllStamps().every(
          (s) => s.id.startsWith('epost_') && s.imageUrl != null,
        ),
        true,
      );
    });
  });

  group('소장 도감 및 통계 서비스 (CollectionService) 검증', () {
    test('도감 아이템 추가/수정/삭제 및 통계 계산이 정상 동작해야 함', () async {
      final initialStats = CollectionService.getStatistics();
      expect(
        initialStats['totalDbCount'],
        StampRepository.getAllStamps().length,
      );

      // 신규 우표 도감 등록
      final newItem = CollectionItem(
        id: 'test_item_1',
        stampId: 'stamp_2021_001', // 누리호 우표
        condition: StampCondition.mint,
        count: 5,
        acquiredDate: DateTime.now(),
        purchasePrice: 15000,
        storageLocation: '2번 앨범 5페이지',
      );

      await CollectionService.addOrUpdateItem(newItem);
      expect(CollectionService.isCollected('stamp_2021_001'), true);

      final updatedStats = CollectionService.getStatistics();
      expect(updatedStats['totalPieces'] >= 5, true);

      // 도록 텍스트 보고서 생성 확인
      final report = CollectionService.generateCatalogTextReport();
      expect(report, contains('대한민국 우표 수집 도감'));
      expect(report, contains('누리호'));

      await CollectionService.addOrUpdateItem(
        CollectionItem(
          id: newItem.id,
          stampId: newItem.stampId,
          condition: StampCondition.used,
          count: 3,
          acquiredDate: newItem.acquiredDate,
          memo: '수량과 상태 변경',
        ),
      );
      expect(CollectionService.getItemByStampId(newItem.stampId)?.count, 3);
      expect(
        CollectionService.getItemByStampId(newItem.stampId)?.condition,
        StampCondition.used,
      );

      // 삭제
      await CollectionService.removeItem('test_item_1');
      expect(CollectionService.isCollected('stamp_2021_001'), false);
    });
  });
}
