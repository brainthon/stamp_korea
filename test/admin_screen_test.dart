import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stamp_korea/screens/admin_screen.dart';
void main() {
  for (final width in [390.0,1440.0]) {
    testWidgets('admin preview fits $width and does not expose private records', (tester) async {
      tester.view.physicalSize=Size(width,1000);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home:AdminScreen()));
      await tester.pumpAndSettle();
      expect(find.text('관리자 로그인'),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.tap(find.text('우표 DB').first);
      await tester.pumpAndSettle();
      expect(find.text('관리자 로그인 후 우표 정보를 관리할 수 있습니다.'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}
