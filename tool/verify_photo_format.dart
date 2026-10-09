import 'dart:io';
import 'dart:typed_data';
import '../lib/services/photo_format.dart';

Uint8List box(String major, List<String> compatible) {
  final result = Uint8List(16 + compatible.length * 4);
  ByteData.sublistView(result).setUint32(0, result.length);
  result.setRange(4, 8, 'ftyp'.codeUnits);
  result.setRange(8, 12, major.codeUnits);
  for (var i = 0; i < compatible.length; i++) {
    result.setRange(16 + i * 4, 20 + i * 4, compatible[i].codeUnits);
  }
  return result;
}

void check(bool ok, String message) {
  if (!ok) throw StateError(message);
}

void main(List<String> args) {
  for (final brand in ['heic', 'heix', 'mif1', 'msf1']) {
    check(isHeicPhoto(box(brand, [])), brand);
  }
  check(isHeicPhoto(box('other', ['heic'])), 'Compatible HEIC brand');
  check(
    !isHeicPhoto(box('mif1', ['avif'])),
    'AVIF must not be treated as HEIC',
  );
  check(!isHeicPhoto(Uint8List.fromList([255, 216, 255])), 'JPEG passthrough');
  check(
    !isHeicPhoto(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])),
    'PNG passthrough',
  );
  final broken = box('heic', []);
  ByteData.sublistView(broken).setUint32(0, 9999);
  check(!isHeicPhoto(broken), 'Malformed box length');
  if (args.isNotEmpty) {
    check(
      isHeicPhoto(File(args.first).readAsBytesSync()),
      'Actual iPhone HEIC fixture',
    );
  }
  print(
    'PASS: HEIC/HEIF brands, compatible brands, AVIF exclusion, malformed input, JPEG/PNG passthrough and supplied HEIC fixture',
  );
}
