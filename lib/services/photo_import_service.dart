import 'package:flutter/foundation.dart';
import 'heic_converter.dart';
import 'photo_format.dart';
import 'recognition_service.dart';

Future<Uint8List> importStampPhoto(Uint8List source) async {
  if (source.length > 20 * 1024 * 1024) {
    throw const FormatException('사진은 20MB 이하로 선택해 주세요.');
  }
  final pixels = isHeicPhoto(source) ? await convertHeicPhoto(source) : source;
  return compute(normalizeStampPhoto, pixels);
}
