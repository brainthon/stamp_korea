import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<Uint8List> convertHeicPhoto(Uint8List bytes) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    throw const FormatException(
      '이 기기에서는 HEIC 변환을 지원하지 않습니다. 웹 또는 아이폰 앱에서 선택해 주세요.',
    );
  }
  try {
    final result = await const MethodChannel('stamp_korea/photo_import')
        .invokeMethod<Uint8List>('heicToJpeg', bytes)
        .timeout(const Duration(seconds: 30));
    if (result == null || result.isEmpty) {
      throw const FormatException('HEIC 사진을 읽지 못했습니다. 다른 사진을 선택해 주세요.');
    }
    return result;
  } on PlatformException {
    throw const FormatException('HEIC 사진을 변환하지 못했습니다. 파일이 손상되지 않았는지 확인해 주세요.');
  } on MissingPluginException {
    throw const FormatException('HEIC 지원이 추가된 앱으로 업데이트해 주세요.');
  }
}
