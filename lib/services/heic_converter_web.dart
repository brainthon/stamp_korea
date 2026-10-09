import 'dart:js_interop';
import 'dart:typed_data';

@JS('stampConvertHeic')
external JSPromise<JSUint8Array> _convert(JSUint8Array bytes);

Future<Uint8List> convertHeicPhoto(Uint8List bytes) async {
  try {
    return (await _convert(
      bytes.toJS,
    ).toDart.timeout(const Duration(seconds: 60))).toDart;
  } catch (_) {
    throw const FormatException(
      'HEIC 사진을 변환하지 못했습니다. 인터넷 연결을 확인한 후 다시 선택해 주세요.',
    );
  }
}
