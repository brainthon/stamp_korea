import 'stamp.dart';

class OfficialStamp {
  OfficialStamp(this.data);
  final Map<String, dynamic> data;
  String value(String key) => data[key]?.toString() ?? '';
  String get id => value('id');
  String get name => value('name');
  String get description => value('description');
  String get sourceUrl => value('source_url');
  Stamp toStamp() => Stamp(
    officialDetails: {
      '우표번호': value('stamp_number'),
      '종수': value('issue_count'),
      '발행량': value('issue_volume_display'),
      '디자인': value('design'),
      '인쇄 및 색수': value('printing'),
      '전지구성': value('sheet'),
      '디자이너': value('designer'),
      '발행일': value('issue_date'),
      '액면가격': value('face_value'),
      '우표크기': value('size'),
      '인면': value('image_size'),
      '천공': value('perforation'),
      '용지': value('paper'),
      '인쇄처': value('printer'),
    },
    id: id,
    name: name,
    englishName: '',
    issueYear: int.tryParse(value('year')) ?? 0,
    issueDate: value('issue_date'),
    issueVolume: (data['issue_volume'] as num?)?.toInt() ?? 0,
    faceValue: value('face_value'),
    category: value('category'),
    theme: value('theme').isEmpty ? '기타' : value('theme'),
    designer: value('designer'),
    printer: value('printer'),
    rarity: RarityTier.n,
    estimatedValue: '',
    description: description,
    historicalStory: '',
    perforation: value('perforation'),
    sizeMm: value('size'),
    primaryColors: const ['#173E35', '#E9ECDD'],
    keywords: [name, value('stamp_number'), value('design')],
    visualSignature: id,
    imageUrl: value('image_url'),
    illustrationSvgPlaceholder: 'vintage_crest',
  );
}
