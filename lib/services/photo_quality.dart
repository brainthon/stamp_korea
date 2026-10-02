import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Conservative, local heuristics. Warnings are not a recognition confidence score.
List<String> inspectStampPhoto(Uint8List bytes) {
  img.Image? source;
  try {
    source = img.decodeImage(bytes);
  } catch (_) {
    return ['사진을 읽을 수 없습니다. 다시 선택해 주세요.'];
  }
  if (source == null) return ['사진을 읽을 수 없습니다. 다시 선택해 주세요.'];
  final warnings = <String>[];
  if (source.width < 240 || source.height < 240) {
    warnings.add('우표가 작게 보일 수 있어요. 가까이에서 다시 촬영해 주세요.');
  }
  final image = img.copyResize(
    source,
    width: source.width >= source.height ? 256 : null,
    height: source.height > source.width ? 256 : null,
  );
  double light = 0, edges = 0;
  int dark = 0, bright = 0, samples = 0;
  double gray(int x, int y) =>
      img.getLuminance(image.getPixel(x, y)).toDouble();
  for (var y = 1; y < image.height - 1; y++) {
    for (var x = 1; x < image.width - 1; x++) {
      final v = gray(x, y);
      light += v;
      if (v < 25) dark++;
      if (v > 248) bright++;
      edges +=
          (4 * v -
                  gray(x - 1, y) -
                  gray(x + 1, y) -
                  gray(x, y - 1) -
                  gray(x, y + 1))
              .abs();
      samples++;
    }
  }
  if (samples == 0) return warnings;
  if (light / samples < 55 || dark / samples > .7) {
    warnings.add('사진이 어두워요. 밝은 곳에서 그림자를 피해 촬영해 주세요.');
  }
  if (bright / samples > .55) {
    warnings.add('밝은 영역이 많아요. 흰 배경을 줄이고 우표의 빛 반사를 확인해 주세요.');
  }
  if (edges / samples < 3) {
    warnings.add('세부 무늬가 약하게 보여요. 우표 영역을 자르거나 초점을 맞춰 다시 촬영해 주세요.');
  }
  return warnings;
}

Uint8List cropStampPhoto(Map<String, Object> input) {
  final source = img.decodeImage(input['bytes'] as Uint8List)!;
  final bounds = input['bounds'] as List<double>;
  final x = (bounds[0] * source.width).floor().clamp(0, source.width - 1);
  final y = (bounds[1] * source.height).floor().clamp(0, source.height - 1);
  final width = ((bounds[2] - bounds[0]) * source.width).round().clamp(
    1,
    source.width - x,
  );
  final height = ((bounds[3] - bounds[1]) * source.height).round().clamp(
    1,
    source.height - y,
  );
  return Uint8List.fromList(
    img.encodeJpg(
      img.copyCrop(source, x: x, y: y, width: width, height: height),
      quality: 90,
    ),
  );
}

/// Border-connected background removal for a single stamp on a plain surface.
/// Declines cluttered, border-touching or low-contrast images instead of guessing.
Map<String, Object> extractStampRegion(Uint8List bytes) {
  final original = img.decodeImage(bytes);
  if (original == null) throw const FormatException('사진을 읽을 수 없습니다.');
  final small = img.copyResize(
    original,
    width: original.width >= original.height ? 256 : null,
    height: original.height > original.width ? 256 : null,
  );
  final w = small.width, h = small.height;
  if (w < 20 || h < 20) return {'found': false};
  final corners = [
    small.getPixel(2, 2),
    small.getPixel(w - 3, 2),
    small.getPixel(2, h - 3),
    small.getPixel(w - 3, h - 3),
  ];
  final r = corners.map((p) => p.r).reduce((a, b) => a + b) / 4;
  final g = corners.map((p) => p.g).reduce((a, b) => a + b) / 4;
  final b = corners.map((p) => p.b).reduce((a, b) => a + b) / 4;
  double distance(img.Pixel p) =>
      (p.r - r).abs() + (p.g - g).abs() + (p.b - b).abs();
  if (corners.any((p) => distance(p) > 65)) return {'found': false};
  final mask = Uint8List(w * h), queue = <int>[];
  void add(int x, int y) {
    final i = y * w + x;
    if (mask[i] == 0 && distance(small.getPixel(x, y)) < 70) {
      mask[i] = 1;
      queue.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    add(x, 0);
    add(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    add(0, y);
    add(w - 1, y);
  }
  for (var n = 0; n < queue.length; n++) {
    final i = queue[n], x = i % w, y = i ~/ w;
    if (x > 0) add(x - 1, y);
    if (x < w - 1) add(x + 1, y);
    if (y > 0) add(x, y - 1);
    if (y < h - 1) add(x, y + 1);
  }
  var left = w, top = h, right = 0, bottom = 0, count = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (mask[y * w + x] == 0) {
        count++;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }
  final area = (right - left + 1) * (bottom - top + 1);
  if (count < w * h * .06 ||
      count > w * h * .9 ||
      left < 3 ||
      top < 3 ||
      right > w - 4 ||
      bottom > h - 4 ||
      count / area < .65) {
    return {'found': false};
  }
  // Preserve a margin for perforations; whiten only background reached from edges.
  final cleaned = img.Image.from(original);
  for (var y = 0; y < cleaned.height; y++) {
    for (var x = 0; x < cleaned.width; x++) {
      final sx = (x * w / cleaned.width).floor().clamp(0, w - 1),
          sy = (y * h / cleaned.height).floor().clamp(0, h - 1);
      if (mask[sy * w + sx] == 1) cleaned.setPixelRgb(x, y, 255, 255, 255);
    }
  }
  final bounds = <double>[
    (left - 3) / w,
    (top - 3) / h,
    ((right + 4) / w).clamp(0, 1),
    ((bottom + 4) / h).clamp(0, 1),
  ];
  final cleanedBytes = Uint8List.fromList(img.encodeJpg(cleaned, quality: 90));
  return {
    'found': true,
    'bytes': cropStampPhoto({'bytes': cleanedBytes, 'bounds': bounds}),
  };
}
