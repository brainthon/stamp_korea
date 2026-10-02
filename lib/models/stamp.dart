import 'dart:convert';
import 'dart:typed_data';

enum RarityTier {
  ssr('국보급', '극희귀 (최상급)', 0xFFE5A93C),
  sr('명품급', '희귀 (상급)', 0xFF9C27B0),
  r('우수품', '수집용 (중급)', 0xFF2196F3),
  n('일반품', '보통 (보급형)', 0xFF78909C);

  final String code;
  final String label;
  final int colorValue;

  const RarityTier(this.code, this.label, this.colorValue);

  static RarityTier fromVolume(int volume) {
    if (volume <= 500000) return RarityTier.ssr; // 50만 장 이하
    if (volume <= 1500000) return RarityTier.sr; // 150만 장 이하
    if (volume <= 3000000) return RarityTier.r; // 300만 장 이하
    return RarityTier.n; // 300만 장 초과
  }
}

enum StampCondition {
  mint('신품 (미사용)', '미사용 원본 상태, 뒷면 풀 보존', 0xFF2E7D32),
  used('사용제 (소인)', '우편 소인(도장)이 찍힌 실사용 우표', 0xFF1565C0),
  fdc('초일봉투 (기념봉투)', '발행 첫날 소인이 찍힌 기념 봉투/우표', 0xFFC2185B),
  sheet('전지/시트', '낱장이 아닌 전지 또는 소형 시트 형태', 0xFFE65100);

  final String title;
  final String description;
  final int colorValue;

  const StampCondition(this.title, this.description, this.colorValue);
}

class Stamp {
  final Map<String, String> officialDetails;
  final String id;
  final String name;
  final String englishName;
  final int issueYear;
  final String issueDate; // YYYY-MM-DD
  final int issueVolume; // 발행량
  final String faceValue; // 액면가 (예: "80원", "10문", "500원")
  final String category; // 보통우표, 기념우표, 특수우표, 연하우표 등
  final String theme; // 역사/인물, 스포츠, 문화유산, 자연/생물, 과학/산업, 예술 등
  final String designer; // 도안자
  final String printer; // 인쇄처 (예: 한국조폐공사, 대장성 인쇄국 등)
  final RarityTier rarity;
  final String estimatedValue; // 참고 시세
  final String description; // 도안 및 우표 설명
  final String historicalStory; // 우표에 얽힌 역사적 배경
  final String perforation; // 천공 (예: "13 x 13½")
  final String sizeMm; // 크기 (예: "26 x 36 mm")
  final List<String> primaryColors; // 색상 코드
  final List<String> keywords; // 검색 및 AI 매칭용 키워드
  final String visualSignature; // AI 비전 온디바이스 매칭용 해시/특징 문자열
  final String? assetImage; // 에셋 이미지 경로 (있는 경우)
  final String? imageUrl; // 공식 원본 웹 CDN 이미지 URL
  final String illustrationSvgPlaceholder; // 렌더링용 대표 그래픽 테마

  const Stamp({
    this.officialDetails = const {},
    required this.id,
    required this.name,
    required this.englishName,
    required this.issueYear,
    required this.issueDate,
    required this.issueVolume,
    required this.faceValue,
    required this.category,
    required this.theme,
    required this.designer,
    required this.printer,
    required this.rarity,
    required this.estimatedValue,
    required this.description,
    required this.historicalStory,
    required this.perforation,
    required this.sizeMm,
    required this.primaryColors,
    required this.keywords,
    required this.visualSignature,
    this.assetImage,
    this.imageUrl,
    required this.illustrationSvgPlaceholder,
  });

  String get formattedVolume {
    if (issueVolume >= 10000) {
      final man = issueVolume / 10000;
      if (man == man.roundToDouble()) {
        return '${man.toInt()}만 장';
      }
      return '${man.toStringAsFixed(1)}만 장';
    }
    return '$issueVolume 장';
  }

  String get eraName {
    if (issueYear < 1897) return '조선 말기 (우정총국)';
    if (issueYear < 1910) return '대한제국기';
    if (issueYear < 1948) return '미군정 및 해방기';
    if (issueYear < 1960) return '제1공화국';
    if (issueYear < 1980) return '근대화/경제개발기';
    if (issueYear < 2000) return '올림픽 및 도약기';
    return '밀레니엄 & 현대';
  }

  Map<String, dynamic> toJson() => {
    'officialDetails': officialDetails,
    'id': id,
    'name': name,
    'englishName': englishName,
    'issueYear': issueYear,
    'issueDate': issueDate,
    'issueVolume': issueVolume,
    'faceValue': faceValue,
    'category': category,
    'theme': theme,
    'designer': designer,
    'printer': printer,
    'rarity': rarity.name,
    'estimatedValue': estimatedValue,
    'description': description,
    'historicalStory': historicalStory,
    'perforation': perforation,
    'sizeMm': sizeMm,
    'primaryColors': primaryColors,
    'keywords': keywords,
    'visualSignature': visualSignature,
    'assetImage': assetImage,
    'imageUrl': imageUrl,
    'illustrationSvgPlaceholder': illustrationSvgPlaceholder,
  };
}

class CollectionItem {
  final String id;
  final String stampId;
  final StampCondition condition;
  final int count;
  final DateTime acquiredDate;
  final int? purchasePrice; // 원 단위 (선택)
  final String? storageLocation; // 보관함 번호 또는 앨범 페이지
  final String? memo;
  final String? userImagePath; // 사용자가 직접 촬영한 로컬 우표 사진 경로
  final String? userImageUrl; // 표시용 임시 서명 URL 또는 게스트의 로컬 이미지

  CollectionItem({
    required this.id,
    required this.stampId,
    required this.condition,
    this.count = 1,
    required this.acquiredDate,
    this.purchasePrice,
    this.storageLocation,
    this.memo,
    this.userImagePath,
    this.userImageUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'stamp_id': stampId,
    'condition': condition.name,
    'count': count,
    'acquired_date': acquiredDate.toIso8601String(),
    'purchase_price': purchasePrice,
    'storage_location': storageLocation,
    'memo': memo,
    'user_image_path': userImagePath,
    'user_image_url': userImageUrl,
  };

  factory CollectionItem.fromMap(Map<String, dynamic> map) {
    return CollectionItem(
      id: (map['id'] ?? map['item_id']).toString(),
      stampId: (map['stamp_id'] ?? map['stampId']).toString(),
      condition: StampCondition.values.firstWhere(
        (e) => e.name == map['condition'],
        orElse: () => StampCondition.mint,
      ),
      count: (map['count'] as int?) ?? 1,
      acquiredDate:
          DateTime.tryParse(
            map['acquired_date'] ?? map['acquiredDate'] ?? '',
          ) ??
          DateTime.now(),
      purchasePrice: (map['purchase_price'] ?? map['purchasePrice']) as int?,
      storageLocation:
          (map['storage_location'] ?? map['storageLocation']) as String?,
      memo: map['memo'] as String?,
      userImagePath:
          (map['user_image_path'] ?? map['userImagePath']) as String?,
      userImageUrl: (map['user_image_url'] ?? map['userImageUrl']) as String?,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory CollectionItem.fromJson(String source) =>
      CollectionItem.fromMap(jsonDecode(source));
}

class ScanResult {
  final Stamp matchedStamp;
  final double confidence; // 0.0 ~ 1.0 (예: 0.96 -> 96%)
  final double visualSimilarity; // 비전 특징점 유사도
  final double textMatchScore; // OCR 텍스트 매칭 점수
  final double colorMatchScore; // 색상 분포 일치도
  final List<String> detectedFeatures; // 감지된 특징
  final List<StampCandidate> alternativeCandidates; // 차순위 후보군
  final Uint8List? scannedImageBytes; // 사용자가 촬영/선택한 원본 이미지 바이트

  ScanResult({
    required this.matchedStamp,
    required this.confidence,
    required this.visualSimilarity,
    required this.textMatchScore,
    required this.colorMatchScore,
    required this.detectedFeatures,
    required this.alternativeCandidates,
    this.scannedImageBytes,
  });
}

class StampCandidate {
  final Stamp stamp;
  final double confidence;

  StampCandidate({required this.stamp, required this.confidence});
}
