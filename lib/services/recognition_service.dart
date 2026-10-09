import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/official_stamp.dart';

class Recognition {
  final List<OfficialStamp> candidates;
  final String matchStatus;
  final String? recognitionId;
  final OfficialStamp? official;
  final bool isStamp;
  final String name,
      country,
      visibleText,
      faceValue,
      year,
      description,
      uncertainty;
  Recognition.fromMap(Map<String, dynamic> map)
    : candidates =
          (map['candidates'] as List? ?? [])
              .whereType<Map>()
              .map((r) => OfficialStamp(Map<String, dynamic>.from(r)))
              .toList(),
      recognitionId = map['recognition_id'] as String?,
      matchStatus = map['match_status']?.toString() ?? 'no_match',
      official =
          map['official'] is Map
              ? OfficialStamp(Map<String, dynamic>.from(map['official'] as Map))
              : null,
      isStamp = map['is_stamp'] == true,
      name = map['name'] as String,
      country = map['country'] as String,
      visibleText = map['visible_text'] as String,
      faceValue = map['face_value'] as String,
      year = map['year'] as String,
      description = map['description'] as String,
      uncertainty = map['uncertainty'] as String;

  Recognition choose(OfficialStamp stamp) => Recognition.fromMap({
    'recognition_id': recognitionId,
    'is_stamp': isStamp,
    'name': name,
    'country': country,
    'visible_text': visibleText,
    'face_value': faceValue,
    'year': year,
    'description': '',
    'uncertainty': '',
    'official': stamp.data,
    'candidates': candidates.map((c) => c.data).toList(),
    'match_status': 'user_selected',
  });
}

class RecognitionException implements Exception {
  final String message;
  RecognitionException(this.message);
}

Uint8List normalizeStampPhoto(Uint8List bytes) {
  try {
    return _normalize(bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('사진을 읽을 수 없습니다. JPEG 또는 PNG로 다시 선택해 주세요.');
  }
}

Uint8List _normalize(Uint8List bytes) {
  if (bytes.length > 20 * 1024 * 1024) {
    throw FormatException('사진은 20MB 이하로 선택해 주세요.');
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 40000000) {
    throw FormatException('JPEG 또는 PNG 사진으로 다시 선택해 주세요.');
  }
  var picture = decoder!.decodeFrame(0);
  if (picture == null) throw FormatException('사진을 읽을 수 없습니다.');
  picture = img.bakeOrientation(picture);
  if (picture.width > 1600 || picture.height > 1600) {
    picture = img.copyResize(
      picture,
      width: picture.width >= picture.height ? 1600 : null,
      height: picture.height > picture.width ? 1600 : null,
    );
  }
  // Re-encode pixels only; omit EXIF/GPS metadata.
  final clean = img.Image(
    width: picture.width,
    height: picture.height,
    numChannels: 3,
  );
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, picture);
  final output = Uint8List.fromList(img.encodeJpg(clean, quality: 85));
  if (output.length > 4 * 1024 * 1024) {
    throw FormatException('사진 크기를 줄여 다시 선택해 주세요.');
  }
  return output;
}

class RecognitionService {
  static Future<Recognition> identify(Uint8List jpeg) async {
    final sb = SupabaseService.client;
    if (sb == null || !SupabaseService.isLoggedIn) {
      throw RecognitionException('로그인 후 AI 판독을 시작해 주세요.');
    }
    try {
      final response = await sb.functions
          .invoke('identify-stamp', body: {'image_base64': base64Encode(jpeg)})
          .timeout(const Duration(seconds: 100));
      final data = Map<String, dynamic>.from(response.data as Map);
      return Recognition.fromMap(data);
    } on FunctionException catch (e) {
      final details = e.details;
      throw RecognitionException(
        details is Map && details['message'] is String
            ? details['message'] as String
            : e.status == 401
            ? '로그인이 만료되었습니다. 다시 로그인해 주세요.'
            : '판독 서버에 연결하지 못했어요.',
      );
    } on TimeoutException {
      throw RecognitionException('판독 시간이 길어지고 있어요. 잠시 후 다시 시도해 주세요.');
    } on RecognitionException {
      rethrow;
    } catch (_) {
      throw RecognitionException('사진을 판독하지 못했어요. 연결을 확인하고 다시 시도해 주세요.');
    }
  }
}
