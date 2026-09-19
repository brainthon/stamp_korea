import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stamp_korea/services/recognition_service.dart';
import 'package:stamp_korea/widgets/recognition_result_view.dart';
import 'package:stamp_korea/theme/app_theme.dart';
import 'network_images.dart';

Map<String, dynamic> observation() => {
  'is_stamp': true,
  'name': 'AI 추정 이름',
  'country': '대한민국',
  'year': '2025',
  'face_value': '430',
  'visible_text': '불필요한 OCR 전문',
  'description': '합성 우표일 수도 있습니다',
  'uncertainty': '주관적인 의견',
};
void main() {
  final official =
      (jsonDecode(
                File('assets/catalog/official_stamps.json').readAsStringSync(),
              )
              as List)
          .first;
  catalogTestWidgets('ambiguous candidate needs an explicit user selection', (
    tester,
  ) async {
    String? selected;
    final result = Recognition.fromMap({
      ...observation(),
      'match_status': 'candidates',
      'candidates': [official],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecognitionResultView(
            result: result,
            photo: null,
            onBack: () {},
            onChoose: () {},
            onSave: () {},
            onSelectCandidate: (stamp) => selected = stamp.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(result.official, isNull);
    expect(selected, isNull);
    await tester.scrollUntilVisible(find.text('제21대 대통령 취임'), 200);
    await tester.tap(find.text('제21대 대통령 취임'));
    expect(selected, official['id']);
    final chosen = result.choose(result.candidates.first);
    expect(chosen.matchStatus, 'user_selected');
    expect(chosen.official?.id, official['id']);
  });
  catalogTestWidgets(
    'official description replaces AI opinion and save confirms matched stamp',
    (tester) async {
      var saved = false;
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: RecognitionResultView(
              result: Recognition.fromMap({
                ...observation(),
                'official': official,
              }),
              photo: null,
              onBack: () {},
              onChoose: () {},
              onSave: () => saved = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('제21대 대통령 취임'), findsOneWidget);
      expect(find.text('430원'), findsOneWidget);
      expect(find.text('3834'), findsOneWidget);
      expect(find.text('합성 우표일 수도 있습니다'), findsNothing);
      expect(find.text('주관적인 의견'), findsNothing);
      await tester.scrollUntilVisible(find.text(official['description']), 250);
      expect(find.text('설명 더 보기'), findsNothing);
      expect(find.text(official['description']), findsOneWidget);
      await tester.scrollUntilVisible(find.text('이 우표를 수집함에 추가'), 300);
      await tester.tap(find.text('이 우표를 수집함에 추가'));
      expect(saved, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  catalogTestWidgets(
    'unmatched stamps never present generated prose as official text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: RecognitionResultView(
              result: Recognition.fromMap(observation()),
              photo: null,
              onBack: () {},
              onChoose: () {},
              onSave: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('공식 설명을 아직 연결하지 못했어요.'), findsOneWidget);
      expect(find.text('합성 우표일 수도 있습니다'), findsNothing);
      expect(find.text('공식 발행 정보'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
