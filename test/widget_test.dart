import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stamp_korea/main.dart';
import 'package:stamp_korea/services/collection_service.dart';
import 'package:stamp_korea/services/stamp_repository.dart';
import 'network_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await CollectionService.initialize();
  });

  catalogTestWidgets(
    'mobile: search, wishlist, save, edit and delete a collection record',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      expect(CollectionService.getItems(), isEmpty);
      await tester.pumpWidget(const StampKoreaApp());
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(find.text('작은 한 장,\n새로운 발견.'), findsNothing);
      expect(find.text('당신의 수집이, 이야기가 되는 곳'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('우표 도감').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '제21대 대통령 취임');
      await tester.pumpAndSettle();
      expect(find.text('1종의 우표'), findsOneWidget);
      await tester.tap(find.byTooltip('위시리스트에 추가').first);
      await tester.pumpAndSettle();
      expect(CollectionService.isWishlisted('epost_3834'), isTrue);
      await tester.tap(find.text('제21대 대통령 취임').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('내 수집함에 추가'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('내 수집함에 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('수량 늘리기'));
      await tester.enterText(
        find.widgetWithText(TextField, '수집 메모'),
        '첫 수집 기록',
      );
      await tester.ensureVisible(find.text('수집 기록 저장'));
      await tester.tap(find.text('수집 기록 저장'));
      await tester.pumpAndSettle();
      final item = CollectionService.getItemByStampId('epost_3834');
      expect(item?.count, 2);
      expect(item?.memo, '첫 수집 기록');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('user_stamp_collection_v1')!.single,
        contains('첫 수집 기록'),
      );
      await tester.scrollUntilVisible(
        find.text('수집 기록 삭제'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('수집 기록 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(CollectionService.getItems(), isNotEmpty);
      await tester.tap(find.text('수집 기록 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(CollectionService.getItems(), isEmpty);
      expect(prefs.getStringList('user_stamp_collection_v1'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  catalogTestWidgets('320px and desktop layouts have no overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 740), const Size(1280, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const StampKoreaApp());
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('사진 판독').last);
      await tester.pumpAndSettle();
      expect(find.text('사진으로 우표 찾기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('홈').last);
      await tester.pumpAndSettle();
    }
  });
  test('catalog query applies keyword and theme together', () {
    expect(StampRepository.searchStamps(query: '3834'), isNotEmpty);
    expect(StampRepository.searchStamps(query: '없는우표'), isEmpty);
    expect(StampRepository.searchStamps(query: '태극', theme: '자연/생물'), isEmpty);
  });
}
