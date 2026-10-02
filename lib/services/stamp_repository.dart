import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/official_stamp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stamp.dart';
import '../models/stamp_theme.dart';
import 'supabase_service.dart';

class StampRepository {
  static const String _customStampsKey = 'custom_user_stamps_v1';

  static final List<Stamp> _baseStamps = [
    // 1. 조선 최초 우표 (문위우표)
    const Stamp(
      id: 'stamp_1884_001',
      name: '문위우표 (5문)',
      englishName: 'Moon-wi 5-Mun Stamp (First Korean Stamp)',
      issueYear: 1884,
      issueDate: '1884-11-18',
      issueVolume: 100000,
      faceValue: '5문 (五文)',
      category: '보통우표',
      theme: '역사/인물',
      designer: '일본 대장성 인쇄국 도안팀',
      printer: '일본 대장성 인쇄국',
      rarity: RarityTier.ssr,
      estimatedValue: '신품 500,000원 ~ 1,500,000원 / 사용제 1,000만원 이상',
      description:
          '1884년 11월 18일 홍영식의 주도로 우정총국이 개설되며 발행된 한국 최초의 우표입니다. 액면 표기가 화폐단위인 "문(文)"으로 되어 있어 문위우표라 불립니다.',
      historicalStory:
          '우정총국 개국 축하연 당일 발생한 갑신정변(1884.12.4)으로 인해 개국 20일 만에 우정총국이 폐쇄되면서 실사용된 우표는 극소수에 불과하여 세계적인 희귀 우표로 평가받습니다.',
      perforation: '무천공 (Imperforate)',
      sizeMm: '22 x 26 mm',
      primaryColors: ['#B71C1C', '#FFFFFF', '#D32F2F'],
      keywords: ['문위우표', '5문', '조선', '우정총국', '홍영식', '최초우표', '1884', '갑신정변'],
      visualSignature: 'sig_1884_5m_red_korea_first_vintage',
      illustrationSvgPlaceholder: 'vintage_crest',
    ),
    const Stamp(
      id: 'stamp_1884_002',
      name: '문위우표 (10문)',
      englishName: 'Moon-wi 10-Mun Stamp',
      issueYear: 1884,
      issueDate: '1884-11-18',
      issueVolume: 100000,
      faceValue: '10문 (十文)',
      category: '보통우표',
      theme: '역사/인물',
      designer: '일본 대장성 인쇄국 도안팀',
      printer: '일본 대장성 인쇄국',
      rarity: RarityTier.ssr,
      estimatedValue: '신품 600,000원 ~ 1,800,000원',
      description:
          '문위우표 5종(5문, 10문, 25문, 50문, 100문) 중 실제로 인쇄되어 국내에 도착 및 판매된 2종 중 하나인 청색 10문 우표입니다.',
      historicalStory:
          '25문, 50문, 100문 우표는 일본에서 제작되어 인천항에 도착했으나 갑신정변으로 우정총국이 폐쇄되어 배포되지 못하고 전량 압류된 비운의 역사를 품고 있습니다.',
      perforation: '무천공 (Imperforate)',
      sizeMm: '22 x 26 mm',
      primaryColors: ['#0D47A1', '#FFFFFF', '#1976D2'],
      keywords: ['문위우표', '10문', '조선', '우정총국', '청색', '1884', '최초'],
      visualSignature: 'sig_1884_10m_blue_korea_first_vintage',
      illustrationSvgPlaceholder: 'vintage_crest_blue',
    ),

    // 2. 대한제국기 우표
    const Stamp(
      id: 'stamp_1895_001',
      name: '태극우표 (5푼)',
      englishName: 'Taegeuk 5-Pun Stamp',
      issueYear: 1895,
      issueDate: '1895-07-22',
      issueVolume: 500000,
      faceValue: '5푼 (五分)',
      category: '보통우표',
      theme: '역사/인물',
      designer: '미국 와이드너사 (Widener & Co.)',
      printer: '미국 워싱턴 인쇄국',
      rarity: RarityTier.ssr,
      estimatedValue: '신품 250,000원 ~ 600,000원',
      description:
          '을미개혁으로 우편업무가 재개되면서 중앙에 태극문양과 네 귀퉁이에 건곤감리 4괘를 배치하여 자주독립의 의지를 담은 우표입니다.',
      historicalStory:
          '태극문양이 공식 우표 도안으로 채택된 최초의 사례이며, 당시 조선의 독자적인 주권국가 상징성을 전 세계에 알린 역사적 의미가 큽니다.',
      perforation: '11',
      sizeMm: '21 x 25 mm',
      primaryColors: ['#C62828', '#1565C0', '#F9A825'],
      keywords: ['태극우표', '5푼', '을미개혁', '태극', '조선', '1895', '사괘'],
      visualSignature: 'sig_1895_5pun_taegeuk_vintage',
      illustrationSvgPlaceholder: 'taegeuk_classic',
    ),
    const Stamp(
      id: 'stamp_1900_001',
      name: '이화우표 (1전)',
      englishName: 'Plum Blossom 1-Jeon Stamp',
      issueYear: 1900,
      issueDate: '1900-01-01',
      issueVolume: 1500000,
      faceValue: '1전 (一錢)',
      category: '보통우표',
      theme: '문화유산',
      designer: '프랑스 파리 조폐국 인쇄팀',
      printer: '프랑스 파리 정부인쇄국',
      rarity: RarityTier.sr,
      estimatedValue: '신품 80,000원 ~ 200,000원',
      description:
          '대한제국 선포 이후 황실을 상징하는 오얏꽃(이화, 李花) 문양을 중앙에 배치한 대한제국 대표 보통우표입니다.',
      historicalStory:
          '대한제국이 만국우편연합(UPU)에 정식 가입한 후 국제 우편 통용을 위해 프랑스에서 정교하게 음각 동판으로 인쇄한 명품 우표입니다.',
      perforation: '12 x 12½',
      sizeMm: '23 x 27 mm',
      primaryColors: ['#4E342E', '#EFEBE9', '#6D4C41'],
      keywords: ['이화우표', '대한제국', '오얏꽃', '1전', '1900', '고종', '황실'],
      visualSignature: 'sig_1900_1jeon_plum_blossom',
      illustrationSvgPlaceholder: 'plum_blossom',
    ),
    const Stamp(
      id: 'stamp_1902_001',
      name: '고종 황제 즉위 40년 칭경예식 기념우표',
      englishName:
          'Emperor Gojong 40th Jubilee Commemorative Stamp (First Commemorative)',
      issueYear: 1902,
      issueDate: '1902-10-18',
      issueVolume: 1000000,
      faceValue: '3전 (三錢)',
      category: '기념우표',
      theme: '역사/인물',
      designer: '프랑스 조폐국 디자이너',
      printer: '농상공부 통신원 인쇄과',
      rarity: RarityTier.ssr,
      estimatedValue: '신품 350,000원 ~ 800,000원',
      description:
          '한국 최초의 기념우표입니다. 고종 황제의 즉위 40주년 및 51세 망육순을 기념하여 궁중의 황제 어차를 상징하는 문양을 담았습니다.',
      historicalStory:
          '국내에서 자체 기술(통신원 인쇄과)로 인쇄한 첫 번째 기념우표로, 근대 대한제국 국가의 위엄과 행사를 전 세계에 천명한 기념비적 우표입니다.',
      perforation: '11',
      sizeMm: '24 x 28 mm',
      primaryColors: ['#E65100', '#FFF3E0', '#BF360C'],
      keywords: ['칭경예식', '고종', '대한제국', '최초기념우표', '3전', '1902', '즉위40년'],
      visualSignature: 'sig_1902_gojong_jubilee_first_commemorative',
      illustrationSvgPlaceholder: 'royal_crown',
    ),

    // 3. 해방 및 대한민국 건국기 (1940~1950년대)
    const Stamp(
      id: 'stamp_1946_001',
      name: '해방 1주년 기념우표',
      englishName: '1st Anniversary of National Liberation Commemorative Stamp',
      issueYear: 1946,
      issueDate: '1946-08-15',
      issueVolume: 500000,
      faceValue: '50전',
      category: '기념우표',
      theme: '역사/인물',
      designer: '강박 (Kang Bak)',
      printer: '조선서적 인쇄주식회사',
      rarity: RarityTier.ssr,
      estimatedValue: '신품 150,000원 ~ 400,000원',
      description:
          '8·15 광복 1주년을 기념하여 해방의 환희와 무궁화를 손에 쥔 한반도 민중의 모습을 역동적으로 표현한 우표입니다.',
      historicalStory:
          '일제강점기 동안 억압받던 한글 표기 "대조선우표"와 태극기가 다시 당당하게 들어간 감격스러운 광복 1호 기념우표입니다.',
      perforation: '11',
      sizeMm: '23 x 31 mm',
      primaryColors: ['#1B5E20', '#FFFFFF', '#2E7D32'],
      keywords: ['해방', '광복', '1주년', '1946', '50전', '무궁화', '태극기', '미군정'],
      visualSignature: 'sig_1946_liberation_1st_anniv',
      illustrationSvgPlaceholder: 'liberation_sun',
    ),
    const Stamp(
      id: 'stamp_1948_001',
      name: '대한민국 정부수립 기념우표',
      englishName:
          'Inauguration of the Government of the Republic of Korea Stamp',
      issueYear: 1948,
      issueDate: '1948-08-15',
      issueVolume: 1000000,
      faceValue: '5원 / 10원',
      category: '기념우표',
      theme: '역사/인물',
      designer: '체신부 도안실',
      printer: '조선서적 인쇄주식회사',
      rarity: RarityTier.ssr,
      estimatedValue: '신품 세트 200,000원 ~ 500,000원',
      description:
          '1948년 8월 15일 대한민국 정부의 공식 수립을 선포하며 국호 "대한민국"이 공식 인쇄된 역사적인 첫 기념우표입니다.',
      historicalStory:
          '중앙의 무궁화와 태극 문양을 배경으로 한반도 지도가 뚜렷이 새겨져 정통 국가로서의 출범을 대내외에 선언하였습니다.',
      perforation: '11',
      sizeMm: '24 x 33 mm',
      primaryColors: ['#0D47A1', '#B71C1C', '#FFFFFF'],
      keywords: ['정부수립', '대한민국', '1948', '815', '무궁화', '건국', '1호기념우표'],
      visualSignature: 'sig_1948_rok_gov_establishment',
      illustrationSvgPlaceholder: 'korea_flag_crest',
    ),
    const Stamp(
      id: 'stamp_1954_001',
      name: '독도 보통우표 (30환)',
      englishName: 'Dokdo Island Definitive Stamp (30-Hwan)',
      issueYear: 1954,
      issueDate: '1954-09-15',
      issueVolume: 5000000,
      faceValue: '30환',
      category: '보통우표',
      theme: '문화유산',
      designer: '강박',
      printer: '한국조폐공사',
      rarity: RarityTier.r,
      estimatedValue: '신품 50,000원 ~ 120,000원',
      description: '동해의 독도 동도와 서도의 웅장한 모습을 담은 독도 최초의 우표 3부작 중 30환 우표입니다.',
      historicalStory:
          '발행 당시 일본 정부가 이 우표가 붙은 한국발 국제 우편물의 수취를 거부하고 반송하는 등 국제적 외교 이슈를 낳았던 대한민국의 확고한 영토 주권 상징 우표입니다.',
      perforation: '12½',
      sizeMm: '22 x 27 mm',
      primaryColors: ['#006064', '#E0F7FA', '#00838F'],
      keywords: ['독도', '독도우표', '30환', '1954', '동해', '영토주권', '조폐공사'],
      visualSignature: 'sig_1954_dokdo_30hwan_island',
      illustrationSvgPlaceholder: 'dokdo_island',
    ),

    // 4. 경제개발 및 산업화 (1960~1970년대)
    const Stamp(
      id: 'stamp_1970_001',
      name: '경부고속도로 개통 기념우표',
      englishName: 'Opening of the Gyeongbu Expressway Commemorative Stamp',
      issueYear: 1970,
      issueDate: '1970-07-07',
      issueVolume: 2000000,
      faceValue: '10원',
      category: '기념우표',
      theme: '과학/산업',
      designer: '이혜옥',
      printer: '한국조폐공사',
      rarity: RarityTier.r,
      estimatedValue: '신품 3,000원 ~ 8,000원',
      description:
          '대한민국 국토 대동맥인 서울-부산 간 428km 경부고속도로 전 구간 완전 개통을 축하하기 위해 발행되었습니다.',
      historicalStory:
          '한국 "한강의 기적"과 일일생활권 시대를 연 기념비적인 토목 프로젝트의 완성을 기리는 역사적 우표입니다.',
      perforation: '13',
      sizeMm: '37 x 25 mm',
      primaryColors: ['#004D40', '#FFD600', '#00796B'],
      keywords: ['경부고속도로', '개통', '1970', '10원', '한강의기적', '고속도로', '교통'],
      visualSignature: 'sig_1970_gyeongbu_expressway',
      illustrationSvgPlaceholder: 'expressway_bridge',
    ),
    const Stamp(
      id: 'stamp_1977_001',
      name: '한국 에베레스트 등정 기념우표',
      englishName: 'Korean Expedition Mt. Everest Summit Commemorative Stamp',
      issueYear: 1977,
      issueDate: '1977-10-05',
      issueVolume: 3000000,
      faceValue: '20원',
      category: '기념우표',
      theme: '스포츠',
      designer: '전희한',
      printer: '한국조폐공사',
      rarity: RarityTier.r,
      estimatedValue: '신품 2,000원 ~ 5,000원',
      description:
          '1977년 9월 15일 고상돈 대원이 대한민국 최초이자 세계 8번째로 세계 최고봉 에베레스트(8,848m) 정상에 태극기를 꽂은 쾌거를 기렸습니다.',
      historicalStory:
          '"여기는 정상, 더 이상 오를 곳이 없다"는 명언을 남기며 국민들에게 도전과 자긍심을 심어준 감동의 순간을 담았습니다.',
      perforation: '13',
      sizeMm: '27 x 37 mm',
      primaryColors: ['#0D47A1', '#E0F2F1', '#D50000'],
      keywords: ['에베레스트', '고상돈', '등정', '1977', '20원', '산악', '태극기'],
      visualSignature: 'sig_1977_everest_summit_kosangdon',
      illustrationSvgPlaceholder: 'mountain_everest',
    ),

    // 5. 올림픽 및 세계 도약기 (1980~1990년대)
    const Stamp(
      id: 'stamp_1988_001',
      name: '제24회 서울올림픽대회 기념우표 (마스코트 호돌이)',
      englishName:
          '24th Seoul Olympic Games Commemorative Stamp (Hodori Mascot)',
      issueYear: 1988,
      issueDate: '1988-09-17',
      issueVolume: 3000000,
      faceValue: '80원',
      category: '기념우표',
      theme: '스포츠',
      designer: '김성실 (도안: 김현)',
      printer: '한국조폐공사',
      rarity: RarityTier.r,
      estimatedValue: '신품 2,000원 ~ 4,000원 / 시트 10,000원',
      description:
          '1988년 서울올림픽 개막을 기념하여 상투 모자(상모)를 쓰고 상모 줄로 "S"자(서울)를 그리는 아기 호랑이 마스코트 호돌이를 담은 우표입니다.',
      historicalStory:
          '동서 냉전의 벽을 넘어 전 세계 160개국이 참가한 화합의 대제전 서울올림픽을 대표하는 국민적인 인기 우표입니다.',
      perforation: '13 x 13½',
      sizeMm: '26 x 36 mm',
      primaryColors: ['#FF6F00', '#0D47A1', '#D50000', '#F5F5F5'],
      keywords: ['서울올림픽', '호돌이', '1988', '80원', '88올림픽', '올림픽우표', '마스코트'],
      visualSignature: 'sig_1988_seoul_olympic_hodori_80w',
      illustrationSvgPlaceholder: 'hodori_mascot',
    ),
    const Stamp(
      id: 'stamp_1988_002',
      name: '제24회 서울올림픽대회 기념우표 (성화 봉송)',
      englishName: '24th Seoul Olympic Games Torch Relay Commemorative Stamp',
      issueYear: 1988,
      issueDate: '1988-08-27',
      issueVolume: 3000000,
      faceValue: '80원',
      category: '기념우표',
      theme: '스포츠',
      designer: '전희한',
      printer: '한국조폐공사',
      rarity: RarityTier.r,
      estimatedValue: '신품 2,000원 ~ 3,500원',
      description:
          '올림피아에서 채화되어 제주도를 거쳐 전국을 누빈 서울올림픽 성화 봉송 주자의 열정적인 달리기 모습을 담았습니다.',
      historicalStory: '평화의 불꽃이 한반도 전역에 타오르며 온 국민이 하나로 뭉쳤던 축제의 감동을 기록했습니다.',
      perforation: '13',
      sizeMm: '26 x 36 mm',
      primaryColors: ['#D50000', '#FFAB00', '#3E2723'],
      keywords: ['올림픽', '성화봉송', '1988', '80원', '서울올림픽', '성화'],
      visualSignature: 'sig_1988_seoul_olympic_torch_80w',
      illustrationSvgPlaceholder: 'torch_flame',
    ),
    const Stamp(
      id: 'stamp_1993_001',
      name: '대전세계박람회(EXPO \'93) 개막 기념우표 (꿈돌이)',
      englishName:
          'Daejeon Expo \'93 Opening Commemorative Stamp (Kkumdori Mascot)',
      issueYear: 1993,
      issueDate: '1993-08-07',
      issueVolume: 3000000,
      faceValue: '110원',
      category: '기념우표',
      theme: '과학/산업',
      designer: '이혜옥',
      printer: '한국조폐공사',
      rarity: RarityTier.r,
      estimatedValue: '신품 1,500원 ~ 3,000원',
      description:
          '개발도상국 최초로 공인받은 전문 엑스포인 1993년 대전엑스포의 개막을 알린 우표로, 귀여운 아기 요정 마스코트 "꿈돌이"와 한빛탑을 도안하였습니다.',
      historicalStory:
          '"새로운 도약의 길"이라는 주제로 과학기술 한국의 미래 비전을 온 세계에 선보이며 1,400만 명의 관람객을 모았습니다.',
      perforation: '13',
      sizeMm: '26 x 36 mm',
      primaryColors: ['#FFD600', '#2962FF', '#00C853'],
      keywords: ['대전엑스포', '꿈돌이', '1993', '110원', '한빛탑', '과학', 'EXPO'],
      visualSignature: 'sig_1993_daejeon_expo_kkumdori_110w',
      illustrationSvgPlaceholder: 'kkumdori_star',
    ),
    const Stamp(
      id: 'stamp_1997_001',
      name: '훈민정음 유네스코 세계기록유산 등재 기념우표',
      englishName:
          'Hunminjeongeum UNESCO Memory of the World Registration Stamp',
      issueYear: 1997,
      issueDate: '1997-10-09',
      issueVolume: 2000000,
      faceValue: '150원',
      category: '기념우표',
      theme: '문화유산',
      designer: '김소정',
      printer: '한국조폐공사',
      rarity: RarityTier.r,
      estimatedValue: '신품 2,000원 ~ 4,000원',
      description:
          '세종대왕의 애민정신이 깃든 국보 훈민정음 해례본이 유네스코 세계기록유산에 등재된 것을 기념하여 훈민정음 서문 원본을 정밀 재현한 우표입니다.',
      historicalStory:
          '창제 원리와 음소 이론이 완벽히 기록된 전 세계 유일무이한 문자의 위대함을 전 세계 우취가들에게 알렸습니다.',
      perforation: '13 x 13½',
      sizeMm: '28 x 38 mm',
      primaryColors: ['#3E2723', '#D7CCC8', '#B71C1C'],
      keywords: ['훈민정음', '한글', '세종대왕', '유네스코', '1997', '150원', '기록유산'],
      visualSignature: 'sig_1997_hunminjeongeum_unesco_150w',
      illustrationSvgPlaceholder: 'hangeul_scroll',
    ),

    // 6. 밀레니엄 & 2000년대 현대 우표
    const Stamp(
      id: 'stamp_2002_001',
      name: '2002 FIFA 한일 월드컵 개최 기념우표',
      englishName: '2002 FIFA World Cup Korea/Japan Commemorative Stamp',
      issueYear: 2002,
      issueDate: '2002-05-31',
      issueVolume: 2400000,
      faceValue: '190원',
      category: '기념우표',
      theme: '스포츠',
      designer: '김소정',
      printer: '한국조폐공사',
      rarity: RarityTier.r,
      estimatedValue: '신품 1,500원 ~ 3,000원',
      description:
          '아시아 최초로 한국과 일본이 공동 개최한 2002 월드컵의 개막을 축하하며 역동적인 축구 경기 장면과 공식 엠블럼을 담았습니다.',
      historicalStory:
          '붉은악마의 뜨거운 거리응원과 함께 대한민국 대표팀이 아시아 최초 4강 신화를 달성하며 전 세계를 놀라게 한 축제의 시작이었습니다.',
      perforation: '13',
      sizeMm: '27 x 37 mm',
      primaryColors: ['#D50000', '#2962FF', '#FFD600'],
      keywords: ['월드컵', '2002', '한일월드컵', '190원', '축구', '붉은악마', '피파'],
      visualSignature: 'sig_2002_fifa_worldcup_korea_190w',
      illustrationSvgPlaceholder: 'worldcup_ball',
    ),
    const Stamp(
      id: 'stamp_2011_001',
      name: '한국 애니메이션 캐릭터 (뽀롱뽀롱 뽀로로)',
      englishName: 'Korean Animation Character (Pororo the Little Penguin)',
      issueYear: 2011,
      issueDate: '2011-02-22',
      issueVolume: 4000000,
      faceValue: '250원',
      category: '특수우표',
      theme: '예술/문화',
      designer: '박은경',
      printer: '한국조폐공사',
      rarity: RarityTier.n,
      estimatedValue: '신품 2,500원',
      description:
          '전 세계 어린이들에게 큰 사랑을 받아 "뽀통령"이라 불린 뽀로로와 크롱, 포비, 에디 등 친구들의 다채로운 표정을 담은 인기 우표입니다.',
      historicalStory:
          '발행 즉시 전국 우체국에서 품절 대란을 일으키며 우표 수집 붐을 일으킨 한국 K-콘텐츠 캐릭터의 대표작입니다.',
      perforation: '스티커형',
      sizeMm: '28 x 38 mm',
      primaryColors: ['#0288D1', '#FFF9C4', '#FF5722'],
      keywords: ['뽀로로', '애니메이션', '캐릭터', '2011', '250원', '뽀통령'],
      visualSignature: 'sig_2011_pororo_animation_250w',
      illustrationSvgPlaceholder: 'pororo_character',
    ),
    const Stamp(
      id: 'stamp_2018_001',
      name: '2018 평창 동계올림픽대회 기념우표 (수호랑과 반다비)',
      englishName:
          '2018 PyeongChang Winter Olympic Games Stamp (Soohorang & Bandabi)',
      issueYear: 2018,
      issueDate: '2017-11-01',
      issueVolume: 1400000,
      faceValue: '330원',
      category: '기념우표',
      theme: '스포츠',
      designer: '신재용',
      printer: '한국조폐공사',
      rarity: RarityTier.sr,
      estimatedValue: '신품 2,000원 ~ 4,000원',
      description:
          '30년 만에 대한민국에서 다시 열린 올림픽인 2018 평창동계올림픽의 마스코트 백호 "수호랑"과 패럴림픽 "반다비"의 설원 위 활약을 담았습니다.',
      historicalStory:
          '평화 올림픽으로서 남북 공동 입장 등 세계 평화의 메시지를 전달하며 전 세계적인 찬사를 받은 겨울 축제의 기록입니다.',
      perforation: '13½',
      sizeMm: '28 x 40 mm',
      primaryColors: ['#0277BD', '#FFFFFF', '#212121'],
      keywords: ['평창올림픽', '수호랑', '반다비', '2018', '330원', '동계올림픽'],
      visualSignature: 'sig_2018_pyeongchang_soohorang_330w',
      illustrationSvgPlaceholder: 'pyeongchang_tiger',
    ),
    const Stamp(
      id: 'stamp_2021_001',
      name: '한국형 발사체 누리호(KSLV-II) 발사 기념우표',
      englishName: 'Launch of Korea Space Launch Vehicle Nuri (KSLV-II) Stamp',
      issueYear: 2021,
      issueDate: '2021-10-21',
      issueVolume: 672000,
      faceValue: '430원',
      category: '기념우표',
      theme: '과학/산업',
      designer: '유지형',
      printer: '한국조폐공사',
      rarity: RarityTier.sr,
      estimatedValue: '신품 3,000원 ~ 6,000원',
      description:
          '대한민국 독자 기술로 개발된 우주로켓 누리호의 웅장한 화염 분사와 우주 궤도 진입을 형상화한 기념우표입니다.',
      historicalStory:
          '세계 7번째 실용급 우주 발사체 보유국으로 도약한 우주 강국 대한민국의 신기원을 축하하기 위해 특별 발행되었습니다.',
      perforation: '13½',
      sizeMm: '30 x 40 mm',
      primaryColors: ['#0D47A1', '#FF6D00', '#ECEFF1'],
      keywords: ['누리호', '우주', '로켓', '2021', '430원', 'KSLV', '우주항공'],
      visualSignature: 'sig_2021_nuri_space_rocket_430w',
      illustrationSvgPlaceholder: 'space_rocket',
    ),
    const Stamp(
      id: 'stamp_2023_001',
      name: '한국의 유네스코 인류무형문화유산 - 한국의 탈춤',
      englishName:
          'UNESCO Intangible Cultural Heritage of Humanity - Korean Talchum',
      issueYear: 2023,
      issueDate: '2023-04-20',
      issueVolume: 510000,
      faceValue: '430원',
      category: '특수우표',
      theme: '문화유산',
      designer: '김미화',
      printer: '한국조폐공사',
      rarity: RarityTier.sr,
      estimatedValue: '신품 3,000원 ~ 5,000원',
      description:
          '해학과 풍자, 평등의 가치를 담아 유네스코 인류무형문화유산으로 등재된 하회별신굿탈놀이와 봉산탈춤의 생생한 춤사위를 도안화했습니다.',
      historicalStory:
          '신분 계급의 갈등을 유쾌한 웃음으로 승화시킨 한국 전통 민중 예술의 정수를 현대적 그래픽 감각으로 담아낸 역작입니다.',
      perforation: '13½',
      sizeMm: '33 x 33 mm',
      primaryColors: ['#D50000', '#FFD600', '#2E7D32', '#0D47A1'],
      keywords: ['탈춤', '하회탈', '봉산탈춤', '유네스코', '2023', '430원', '무형문화유산'],
      visualSignature: 'sig_2023_talchum_mask_dance_430w',
      illustrationSvgPlaceholder: 'korean_mask',
    ),
  ];

  static List<Stamp> _dynamicStamps = List.from(_baseStamps);
  static bool _initialized = false;

  /// 초기 커스텀 우표 로드
  static Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final customListRaw = prefs.getStringList(_customStampsKey) ?? [];

    final mergedMap = <String, Stamp>{};
    for (final s in _baseStamps) {
      mergedMap[s.id] = s;
    }

    for (final jsonStr in customListRaw) {
      try {
        final map = jsonDecode(jsonStr);
        final vol = (map['issueVolume'] as num?)?.toInt() ?? 1000000;
        final rarityStr = map['rarity']?.toString().toUpperCase() ?? 'SR';
        RarityTier tier = RarityTier.fromVolume(vol);
        if (rarityStr == 'SSR' || rarityStr == '국보급') tier = RarityTier.ssr;
        if (rarityStr == 'SR' || rarityStr == '명품급') tier = RarityTier.sr;
        if (rarityStr == 'R' || rarityStr == '우수품') tier = RarityTier.r;
        if (rarityStr == 'N' || rarityStr == '일반품') tier = RarityTier.n;

        final stamp = Stamp(
          officialDetails: (map['officialDetails'] as Map? ?? {}).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
          id: map['id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          englishName: map['englishName']?.toString() ?? '',
          issueYear: (map['issueYear'] as num?)?.toInt() ?? 2022,
          issueDate: map['issueDate']?.toString() ?? '',
          issueVolume: vol,
          faceValue: map['faceValue']?.toString() ?? '',
          category: map['category']?.toString() ?? '기념우표',
          theme: map['theme']?.toString() ?? '역사/인물',
          designer: map['designer']?.toString() ?? '우정사업본부',
          printer: map['printer']?.toString() ?? '한국조폐공사',
          rarity: tier,
          estimatedValue: map['estimatedValue']?.toString() ?? '',
          description: map['description']?.toString() ?? '',
          historicalStory: map['historicalStory']?.toString() ?? '',
          perforation: map['perforation']?.toString() ?? '13½',
          sizeMm: map['sizeMm']?.toString() ?? '30 x 40 mm',
          primaryColors:
              (map['primaryColors'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ['#111827', '#D97706'],
          keywords:
              (map['keywords'] as List?)?.map((e) => e.toString()).toList() ??
              [],
          visualSignature: map['visualSignature']?.toString() ?? '',
          imageUrl: map['imageUrl']?.toString(),
          illustrationSvgPlaceholder: 'vintage_crest',
        );
        mergedMap[stamp.id] = stamp;
      } catch (_) {}
    }

    final official =
        jsonDecode(
              await rootBundle.loadString(
                'assets/catalog/official_stamps.json',
              ),
            )
            as List;
    for (final record in official) {
      final stamp =
          OfficialStamp(Map<String, dynamic>.from(record as Map)).toStamp();
      mergedMap[stamp.id] = stamp;
    }

    _dynamicStamps =
        mergedMap.values.toList()
          ..sort((a, b) => a.issueYear.compareTo(b.issueYear));

    _initialized = true;
  }

  /// AI가 인식했거나 사용자가 등록한 우표를 도감 마스터에 영구 저장
  static Future<void> addCustomStamp(Stamp stamp) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _dynamicStamps.indexWhere((s) => s.id == stamp.id);
    if (index >= 0) {
      _dynamicStamps[index] = stamp;
    } else {
      _dynamicStamps.add(stamp);
      _dynamicStamps.sort((a, b) => a.issueYear.compareTo(b.issueYear));
    }

    // 커스텀 우표 영구 저장
    final customStamps =
        _dynamicStamps
            .where((s) => !_baseStamps.any((b) => b.id == s.id))
            .toList();
    final jsonList = customStamps.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_customStampsKey, jsonList);
  }

  /// 전체 우표 목록 반환
  // Legacy demo records remain addressable for existing collections, but are not
  // published as official catalog entries or used for recognition.
  static List<Stamp> getAllStamps() =>
      List.unmodifiable(_dynamicStamps.where((s) => s.id.startsWith('epost_')));

  /// 수파베이스 클라우드 데이터베이스와 우표 카탈로그 동기화
  static Future<void> syncWithCloud() async {
    await initialize();
    final remoteStamps = await SupabaseService.fetchMasterStamps();
    if (remoteStamps != null && remoteStamps.isNotEmpty) {
      final mergedMap = <String, Stamp>{};
      for (final s in _dynamicStamps) {
        mergedMap[s.id] = s;
      }
      for (final r in remoteStamps) {
        mergedMap[r.id] = r;
      }
      _dynamicStamps =
          mergedMap.values.toList()
            ..sort((a, b) => a.issueYear.compareTo(b.issueYear));
    }
  }

  /// 한국 날짜 기준 이미 발행된 공식 우표를 최신 발행일순으로 표시합니다.
  static List<Stamp> getLatestIssuedStamps({
    DateTime? date,
    List<Stamp>? stamps,
    int limit = 4,
  }) {
    final now = date ?? DateTime.now().toUtc().add(const Duration(hours: 9));
    final today = DateTime(now.year, now.month, now.day);
    final issued =
        (stamps ?? getAllStamps()).where((stamp) {
            final day = DateTime.tryParse(stamp.issueDate);
            return stamp.id.startsWith('epost_') &&
                day != null &&
                !day.isAfter(today);
          }).toList()
          ..sort((a, b) {
            final order = b.issueDate.compareTo(a.issueDate);
            return order != 0 ? order : a.id.compareTo(b.id);
          });
    return issued.take(limit).toList();
  }

  /// 오늘의 역사 우표 자동 선정
  static Stamp getTodayStamp({DateTime? date, List<Stamp>? stamps}) {
    final now = date ?? DateTime.now();
    final catalog = [...(stamps ?? getAllStamps())]
      ..sort((a, b) => a.id.compareTo(b.id));
    if (catalog.isEmpty) return _baseStamps.first;
    final sameMonth =
        catalog.where((s) {
          final issued = DateTime.tryParse(s.issueDate);
          return issued != null && issued.month == now.month;
        }).toList();
    final anniversary =
        sameMonth
            .where((s) => DateTime.parse(s.issueDate).day == now.day)
            .toList();
    final pool =
        anniversary.isNotEmpty
            ? anniversary
            : sameMonth.isNotEmpty
            ? sameMonth
            : catalog;
    final day =
        DateTime.utc(
          now.year,
          now.month,
          now.day,
        ).difference(DateTime.utc(1970)).inDays;
    return pool[day % pool.length];
  }

  static String todayStampContext(Stamp stamp, {DateTime? date}) {
    final now = date ?? DateTime.now();
    final issued = DateTime.tryParse(stamp.issueDate);
    if (issued != null && issued.month == now.month) {
      return issued.day == now.day
          ? '오늘과 같은 날, ${issued.year}년 발행'
          : '${now.month}월에 발행된 우표';
    }
    return '오늘 새롭게 만나는 우표';
  }

  /// 대표 희귀 우표 목록
  static List<Stamp> getFeaturedRareStamps() {
    final rares =
        _dynamicStamps
            .where(
              (s) => s.rarity == RarityTier.ssr || s.rarity == RarityTier.sr,
            )
            .toList();
    if (rares.isEmpty) return _dynamicStamps.take(5).toList();
    return rares;
  }

  static Stamp? getStampById(String id) {
    try {
      return _dynamicStamps.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static int? searchYear(String query) {
    final match = RegExp(r'^(\d{4})\s*년?$').firstMatch(query.trim());
    final year = match == null ? null : int.tryParse(match.group(1)!);
    return year != null && year >= 1800 && year <= 2199 ? year : null;
  }

  static List<Stamp> searchStamps({
    String? query,
    String? era,
    String? theme,
    RarityTier? rarity,
    int? startYear,
    int? endYear,
  }) {
    final yearQuery = searchYear(query ?? '');
    return getAllStamps().where((stamp) {
      if (yearQuery != null && stamp.issueYear != yearQuery) return false;
      if (yearQuery == null && query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchName = stamp.name.toLowerCase().contains(q);
        final matchEng = stamp.englishName.toLowerCase().contains(q);
        final matchDesc = stamp.description.toLowerCase().contains(q);
        final matchKeywords = stamp.keywords.any(
          (k) => k.toLowerCase().contains(q),
        );
        final matchYear = stamp.issueYear.toString() == q;
        final matchFaceValue = stamp.faceValue.toLowerCase().contains(q);
        if (!matchName &&
            !matchEng &&
            !matchDesc &&
            !matchKeywords &&
            !matchYear &&
            !matchFaceValue) {
          return false;
        }
      }

      if (era != null && era != '전체' && stamp.eraName != era) {
        return false;
      }

      if (theme != null && theme != '전체' && stamp.theme != theme) {
        return false;
      }

      if (rarity != null && stamp.rarity != rarity) {
        return false;
      }

      if (startYear != null && stamp.issueYear < startYear) {
        return false;
      }

      if (endYear != null && stamp.issueYear > endYear) {
        return false;
      }

      return true;
    }).toList();
  }

  static List<String> getAllEras() {
    final eras = <String>{'전체'};
    for (final s in getAllStamps()) {
      eras.add(s.eraName);
    }
    return eras.toList();
  }

  static List<String> getAllThemes() {
    final available = getAllStamps().map((s) => s.theme).toSet();
    return ['전체', ...StampTheme.names.where(available.contains)];
  }
}
