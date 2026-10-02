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

  catalogTestWidgets('home theme opens a filtered catalog on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StampKoreaApp());
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    final count = StampRepository.searchStamps(theme: '스포츠').length;
    final chip = find.widgetWithText(InkWell, '스포츠');
    await tester.scrollUntilVisible(
      chip,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(chip), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('$count종의 우표'), findsOneWidget);
    final selected = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '스포츠'),
    );
    expect(selected.selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  catalogTestWidgets(
    'visitor sees public catalog but personal actions require login',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const StampKoreaApp());
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(find.text('차곡차곡, 나의 수집'), findsNothing);
      expect(find.text('수집한 우표'), findsNothing);
      expect(find.text('나만의 우표 수집을 시작하세요'), findsOneWidget);
      await tester.tap(find.text('내 수집함').last);
      await tester.pumpAndSettle();
      expect(find.text('좋아하는 우표를 한곳에'), findsOneWidget);
      expect(find.text('수집 기록 복사'), findsNothing);
      expect(find.text('0종'), findsNothing);
      await tester.tap(find.text('사진 판독').last);
      await tester.pumpAndSettle();
      expect(find.text('사진 한 장으로 우표 찾기'), findsOneWidget);
      expect(find.text('우표 촬영'), findsNothing);
      await tester.tap(find.text('우표 도감').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '제21대 대통령 취임');
      await tester.pumpAndSettle();
      expect(find.text('1종의 우표'), findsOneWidget);
      final before = CollectionService.isWishlisted('epost_3834');
      await tester.tap(find.byTooltip('위시리스트에 추가').first);
      await tester.pumpAndSettle();
      expect(find.text('이메일로 로그인'), findsOneWidget);
      expect(CollectionService.isWishlisted('epost_3834'), before);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('제21대 대통령 취임').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('로그인하고 수집함에 추가'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('로그인하고 수집함에 추가'));
      await tester.pumpAndSettle();
      expect(find.text('이메일로 로그인'), findsOneWidget);
      expect(find.text('수집 기록 저장'), findsNothing);
      expect(CollectionService.getItems(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  catalogTestWidgets('320px and desktop layouts have no overflow', (
    tester,
  ) async {
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
