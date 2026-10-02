import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stamp_korea/screens/admin_catalog.dart';

void main() {
  testWidgets('editor fits mobile and rejects invalid data before uploading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (_) => const StampEditor(
                            row: {
                              'id': 'epost_3920',
                              'data': {
                                'name': '',
                                'issue_date': '2026-02-30',
                                'description': '설명',
                              },
                            },
                          ),
                    ),
                child: const Text('열기'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('이미지 파일 선택'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('변경사항 저장'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('우표명·설명과 올바른 발행일을 입력해 주세요.'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('우표명·설명과 올바른 발행일을 입력해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(StampEditor), findsNothing);
  });
}
