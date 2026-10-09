import 'dart:typed_data';

bool isHeicPhoto(Uint8List bytes) {
  if (bytes.length < 16 ||
      String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
    return false;
  }
  final size = ByteData.sublistView(bytes).getUint32(0);
  if (size < 16 || size > bytes.length || size > 4096) return false;
  final brands = <String>[String.fromCharCodes(bytes.sublist(8, 12))];
  for (var i = 16; i + 4 <= size; i += 4) {
    brands.add(String.fromCharCodes(bytes.sublist(i, i + 4)));
  }
  if (brands.any((b) => b == 'avif' || b == 'avis')) return false;
  return brands.any(
    (b) => const {
      'heic',
      'heix',
      'hevc',
      'hevx',
      'heim',
      'heis',
      'hevm',
      'hevs',
      'mif1',
      'msf1',
    }.contains(b),
  );
}
