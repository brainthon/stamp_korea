import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stamp_korea/screens/auth_screen.dart';
import 'package:stamp_korea/services/recognition_service.dart';
import 'package:stamp_korea/theme/app_theme.dart';

void main() {
  test('photo is normalized to bounded JPEG with no EXIF', () {
    final original = img.Image(width: 2000, height: 1000);
    original.exif.imageIfd.make = 'Private device';
    final bytes = normalizeStampPhoto(
      Uint8List.fromList(img.encodePng(original)),
    );
    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 800);
    expect(decoded.exif.imageIfd.make, isNull);
    expect(bytes.length, lessThan(4 * 1024 * 1024));
  });
  test('invalid input is rejected before AI upload', () {
    expect(
      () => normalizeStampPhoto(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(
      () => normalizeStampPhoto(Uint8List(21 * 1024 * 1024)),
      throwsFormatException,
    );
  });
  test('AI requires an authenticated account', () async {
    await expectLater(
      RecognitionService.identify(Uint8List(10)),
      throwsA(isA<RecognitionException>()),
    );
  });
  testWidgets('mobile login and signup forms remain usable at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme(), home: const AuthScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('카카오로 계속하기'), findsOneWidget);
    expect(find.text('Google로 계속하기'), findsOneWidget);
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), false);
    await tester.pumpAndSettle();
    expect(find.text('올바른 이메일을 입력해 주세요.'), findsOneWidget);
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '닉네임'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('recovery displays password change without social login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const AuthScreen(recovery: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('카카오로 계속하기'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
