// Offline checks that do not need a VM service socket or Flutter UI runner.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../lib/models/stamp.dart';
import '../lib/models/stamp_theme.dart';
import '../lib/models/official_stamp.dart';
import '../lib/models/membership.dart';
import '../lib/services/photo_quality.dart';

void main() {
  var passed = 0;
  void check(bool result, String name) {
    if (!result) throw StateError(name);
    passed++;
    stdout.writeln('PASS $name');
  }

  check(
    StampTheme.classify(
          name: '88 서울올림픽',
          design: '호랑이',
          description: '세계평화 축제',
        ) ==
        '스포츠',
    '발행 목적 우선 분류',
  );
  check(
    StampTheme.classify(name: 'unknown') == StampTheme.unclassified,
    '불명확한 테마 보류',
  );
  for (final condition in [
    StampCondition.mint,
    StampCondition.sheet,
    StampCondition.fdc,
  ]) {
    final item = CollectionItem(
      id: condition.name,
      stampId: 'epost_3834',
      condition: condition,
      count: 2,
      acquiredDate: DateTime(2026),
    );
    final restored = CollectionItem.fromJson(item.toJson());
    check(
      restored.id == item.id &&
          restored.condition == condition &&
          restored.count == 2,
      '${condition.name} 수집 기록 왕복 변환',
    );
  }
  final now = DateTime.now();
  Map<String, dynamic> membership(String status, DateTime end) => {
    'effective_plan': 'premium',
    'subscription_status': status,
    'period_start': now.subtract(const Duration(days: 2)).toIso8601String(),
    'period_end': end.toIso8601String(),
  };
  check(
    Membership.fromJson(
      membership('active', now.add(const Duration(days: 1))),
    ).isPremium,
    '유효 프리미엄',
  );
  check(
    !Membership.fromJson(
      membership('active', now.subtract(const Duration(days: 1))),
    ).isPremium,
    '만료 권한 차단',
  );
  check(
    Membership.fromJson(
      membership('canceled', now.add(const Duration(days: 1))),
    ).isPremium,
    '해지 후 잔여 기간',
  );
  final photo = img.fill(
    img.Image(width: 500, height: 500),
    color: img.ColorRgb8(240, 240, 240),
  );
  img.fillRect(
    photo,
    x1: 140,
    y1: 100,
    x2: 360,
    y2: 400,
    color: img.ColorRgb8(30, 70, 110),
  );
  final bytes = Uint8List.fromList(img.encodeJpg(photo));
  final extracted = extractStampRegion(bytes);
  check(
    extracted['found'] == true &&
        img.decodeImage(extracted['bytes'] as Uint8List)!.width < 300,
    '단색 배경 자동 영역 추출',
  );
  final cropped =
      img.decodeImage(
        cropStampPhoto({
          'bytes': bytes,
          'bounds': <double>[.25, .25, .75, .75],
        }),
      )!;
  check(cropped.width == 250 && cropped.height == 250, '수동 자르기 픽셀 경계');
  final blank = Uint8List.fromList(
    img.encodeJpg(img.fill(photo, color: img.ColorRgb8(240, 240, 240))),
  );
  check(extractStampRegion(blank)['found'] == false, '빈 배경 추출 거부');
  check(inspectStampPhoto(Uint8List(0)).isNotEmpty, '잘못된 사진 안내');
  final rows =
      jsonDecode(File('assets/catalog/official_stamps.json').readAsStringSync())
          as List;
  final stamps =
      rows
          .map((r) => OfficialStamp(Map<String, dynamic>.from(r)).toStamp())
          .toList();
  final counts = <String, int>{};
  for (final stamp in stamps) {
    counts.update(stamp.theme, (n) => n + 1, ifAbsent: () => 1);
  }
  check(
    stamps.every((s) => s.id.isNotEmpty) &&
        stamps.map((s) => s.id).toSet().length == stamps.length,
    '번들 도감 ID 유효성·중복 검사',
  );
  stdout.writeln(
    jsonEncode({
      'checks_passed': passed,
      'bundled_stamps': stamps.length,
      'year_2025': stamps.where((s) => s.issueYear == 2025).length,
      'themes': counts,
    }),
  );
}
