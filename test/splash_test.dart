import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stamp_korea/screens/splash_screen.dart';

void main() {
  testWidgets('launch shows branding then opens the app once', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SplashScreen(child: Scaffold(body: Text('홈 화면'))),
    ));
    expect(find.text('우표모아'), findsOneWidget);
    expect(find.text('홈 화면'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text('홈 화면'), findsOneWidget);
    expect(find.text('우표모아'), findsNothing);
  });

  testWidgets('closing during splash cancels transition', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SplashScreen(child: SizedBox()),
    ));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
