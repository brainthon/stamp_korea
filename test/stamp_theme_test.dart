import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stamp_korea/models/official_stamp.dart';
import 'package:stamp_korea/models/stamp_theme.dart';
import 'package:stamp_korea/services/stamp_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('최근 발행은 연도 내 날짜도 정렬하며 미래 발행과 날짜 누락을 제외한다', () {
    final samples =
        [
              ['epost_1', '2026-01-10'],
              ['epost_2', '2026-09-30'],
              ['epost_3', '2026-10-01'],
              ['epost_4', ''],
              ['epost_5', '2026-09-15'],
            ]
            .map(
              (r) => OfficialStamp({'id': r[0], 'issue_date': r[1]}).toStamp(),
            )
            .toList();
    expect(
      StampRepository.getLatestIssuedStamps(
        date: DateTime(2026, 9, 30),
        stamps: samples,
      ).map((s) => s.id),
      ['epost_2', 'epost_5', 'epost_1'],
    );
  });
  test('연도 검색은 해당 발행연도만 반환한다', () async {
    SharedPreferences.setMockInitialValues({});
    await StampRepository.initialize();
    for (final query in ['2025', '2025년', ' 2025 년 ']) {
      final results = StampRepository.searchStamps(query: query);
      expect(results.length, 74);
      expect(results.every((s) => s.issueYear == 2025), isTrue);
    }
  });
  test('발행 목적이 설명의 지역명과 동물명보다 우선한다', () {
    expect(
      StampTheme.classify(
        name: '88 서울올림픽',
        design: '호랑이',
        description: '서울에서 열리는 세계평화 축제',
      ),
      '스포츠',
    );
    expect(StampTheme.classify(name: '연하우표', design: '토끼'), '생활·기념일');
    expect(StampTheme.classify(name: '보통우표', design: '무궁화'), '동물·식물');
    expect(StampTheme.classify(name: '유네스코 세계유산 문화유산'), '문화·예술');
    expect(StampTheme.classify(name: 'unknown'), StampTheme.unclassified);
    expect(StampTheme.classify(name: '서울 기념'), StampTheme.unclassified);
  });
  test('서버 원문에도 저장된 카탈로그와 동일한 테마를 적용한다', () {
    final rows =
        jsonDecode(
              File('assets/catalog/official_stamps.json').readAsStringSync(),
            )
            as List;
    for (final row in rows) {
      final data = Map<String, dynamic>.from(row)..remove('theme');
      expect(
        OfficialStamp(data).toStamp().theme,
        row['theme'],
        reason: row['id'],
      );
    }
  });
  test('홈과 도감은 9개 테마를 공유하며 미분류도 전체에서 유지한다', () async {
    SharedPreferences.setMockInitialValues({});
    await StampRepository.initialize();
    expect(StampRepository.getAllThemes(), ['전체', ...StampTheme.names]);
    final all = StampRepository.getAllStamps();
    expect(all.length, 3896);
    for (final theme in StampTheme.names) {
      final results = StampRepository.searchStamps(theme: theme);
      expect(results, isNotEmpty);
      expect(results.every((s) => s.theme == theme), isTrue);
    }
    expect(all.any((s) => s.theme == StampTheme.unclassified), isTrue);
  });
}
