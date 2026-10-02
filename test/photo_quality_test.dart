import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stamp_korea/services/photo_quality.dart';
import 'package:stamp_korea/screens/photo_crop_screen.dart';

void main() {
  test('automatic extraction crops distinct stamp and declines blank background', () {
    final image = img.fill(img.Image(width: 500, height: 500), color: img.ColorRgb8(240,240,240));
    img.fillRect(image, x1: 140,y1:100,x2:360,y2:400,color:img.ColorRgb8(30,70,110));
    final result = extractStampRegion(Uint8List.fromList(img.encodeJpg(image)));
    expect(result['found'], true);
    final cropped = img.decodeImage(result['bytes'] as Uint8List)!;
    expect(cropped.width, lessThan(300));
    final blank = img.fill(image, color: img.ColorRgb8(240,240,240));
    expect(extractStampRegion(Uint8List.fromList(img.encodeJpg(blank)))['found'], false);
  });
  Uint8List photo(int w, int h, int value) => Uint8List.fromList(
    img.encodeJpg(
      img.fill(
        img.Image(width: w, height: h),
        color: img.ColorRgb8(value, value, value),
      ),
    ),
  );
  test('dark, bright, tiny and invalid images receive actionable guidance', () {
    expect(inspectStampPhoto(photo(300, 300, 0)).join(), contains('어두워'));
    expect(inspectStampPhoto(photo(300, 300, 255)).join(), contains('밝은 영역'));
    expect(inspectStampPhoto(photo(100, 100, 128)).join(), contains('가까이'));
    expect(inspectStampPhoto(Uint8List(0)), isNotEmpty);
  });
  test(
    'crop uses selected pixel bounds and keeps original bytes unchanged',
    () {
      final source = photo(400, 600, 100);
      final snapshot = Uint8List.fromList(source);
      final cropped = cropStampPhoto({
        'bytes': source,
        'bounds': <double>[.25, .25, .75, .75],
      });
      final decoded = img.decodeImage(cropped)!;
      expect(decoded.width, 200);
      expect(decoded.height, 300);
      expect(source, snapshot);
    },
  );
  testWidgets('crop controls fit a small mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: PhotoCropScreen(bytes: photo(400, 600, 100))),
    );
    expect(find.byType(RangeSlider), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
