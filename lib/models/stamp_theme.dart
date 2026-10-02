/// App themes inferred from catalog text, independent of official issue types.
class StampTheme {
  static const unclassified = '미분류';
  static const keywords = <String, List<String>>{
    '역사·인물': [
      '독립운동',
      '광복',
      '삼일절',
      '3·1',
      '3.1',
      '임시정부',
      '순국선열',
      '호국',
      '대통령',
      '즉위',
      '취임',
      '역사인물',
      '위인',
      '정부수립',
      '해방',
      '이순신',
      '세종',
      '안중근',
      '유관순',
      '김구',
      '윤봉길',
      '태극기',
      '문위우표',
    ],
    '문화·예술': [
      '문화유산',
      '세계유산',
      '국보',
      '궁궐',
      '사찰',
      '불상',
      '석탑',
      '도자기',
      '청자',
      '백자',
      '회화',
      '한국화',
      '민화',
      '서예',
      '문학',
      '한글',
      '국악',
      '탈춤',
      '공예',
      '미술',
      '음악',
      '영화',
      '애니메이션',
      '캐릭터',
      '훈민정음',
      '십장생',
      '전통',
      '문화재',
      '불국사',
      '석굴암',
    ],
    '자연·환경': [
      '자연경관',
      '명산',
      '산맥',
      '호수',
      '폭포',
      '갯벌',
      '습지',
      '국립공원',
      '생태계',
      '환경보호',
      '자연보호',
      '기후변화',
      '탄소중립',
      '환경의날',
      '산림',
      '금강산',
      '한라산',
      '설악산',
      '백두산',
      '독도',
    ],
    '동물·식물': [
      '동물',
      '식물',
      '조류',
      '철새',
      '곤충',
      '나비',
      '어류',
      '해양생물',
      '야생화',
      '수목',
      '멸종위기',
      '무궁화',
      '진달래',
      '소나무',
      '호랑이',
      '독수리',
      '두루미',
      '장미',
      '난초',
      '매화',
      '연꽃',
      '백로',
      '원앙',
      '기러기',
      '사슴',
      '고래',
      '거북',
      '토끼',
      '다람쥐',
      '수선화',
      '동백',
      '오얏꽃',
      '이화보통',
    ],
    '과학·기술': [
      '과학',
      '기술',
      '발명',
      '우주',
      '천문',
      '별자리',
      '인공위성',
      '로켓',
      '우주선',
      '통신',
      '인터넷',
      '반도체',
      '로봇',
      '산업',
      '철도',
      '기차',
      '자동차',
      '항공기',
      '선박',
      '고속도로',
      '누리호',
      '발전소',
      '정보화',
      '항공우표',
    ],
    '스포츠': [
      '올림픽',
      '패럴림픽',
      '월드컵',
      '아시안게임',
      '아시아경기',
      '전국체육',
      '체육',
      '선수권',
      '메달리스트',
      '축구',
      '야구',
      '배구',
      '농구',
      '수영',
      '육상',
      '양궁',
      '태권도',
      '스케이팅',
      '스키',
      '스포츠',
    ],
    '지역·관광': ['내고향', '관광', '관광지', '명소', '지역축제', '둘레길', '도시풍경', '지역명소'],
    '국제·평화': [
      '수교',
      '외교',
      '국교',
      '국제연합',
      '유엔',
      '국제기구',
      '정상회의',
      '국제협력',
      '세계평화',
      '남북회담',
      '적십자',
      '국제해사기구',
      '만국우편연합',
      'un',
      'u.n',
      'unesco',
      '유네스코',
    ],
    '생활·기념일': [
      '연하',
      '새해',
      '설날',
      '추석',
      '어린이날',
      '어버이날',
      '스승의날',
      '가정의달',
      '가족',
      '사랑',
      '결혼',
      '우표취미',
      '우표전시',
      '우정사업',
      '우편',
      '저축',
      '보건',
      '어린이헌장',
    ],
  };
  static List<String> get names => keywords.keys.toList(growable: false);
  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  static bool _matches(String text, String word) {
    if (RegExp(r'^[a-z.]+$').hasMatch(word)) {
      return RegExp('(?<![a-z])${RegExp.escape(word)}(?![a-z])').hasMatch(text);
    }
    return text.contains(word);
  }

  static String classify({
    required String name,
    String design = '',
    String description = '',
  }) {
    // A title match wins over incidental terms in a design or long explanation.
    final fields = [name, design, description];
    for (var index = 0; index < fields.length; index++) {
      final field = fields[index];
      final text = _normalize(field);
      final scores = <String, int>{};
      for (final entry in keywords.entries) {
        scores[entry.key] =
            entry.value.where((word) => _matches(text, word)).length;
      }
      final ranked =
          scores.entries.where((e) => e.value > 0).toList()..sort((a, b) {
            final score = b.value.compareTo(a.value);
            return score != 0
                ? score
                : names.indexOf(a.key).compareTo(names.indexOf(b.key));
          });
      if (ranked.isEmpty) continue;
      // Descriptions need two distinct clues and an unambiguous winner.
      if (index == 2 &&
          (ranked.first.value < 2 ||
              (ranked.length > 1 && ranked[0].value == ranked[1].value))) {
        continue;
      }
      return ranked.first.key;
    }
    return unclassified;
  }
}
