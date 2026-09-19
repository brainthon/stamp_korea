# 우표모아 — Flutter MVP

대한민국 우표를 발견하고 개인 수집 기록을 남기는 iOS/Android 공용 Flutter 앱입니다. 기존 `stamp_korea.zip` 프로젝트를 기반으로 첫 개발 버전을 정리했습니다.

## 지금 사용할 수 있는 기능

- 홈: 오늘의 우표, 테마 탐색, 실제 개인 수집 통계
- 도감: 19종의 기존 샘플 데이터, 이름·연도·키워드 검색, 테마 필터, 발행순 정렬
- 우표 상세: 발행정보, 이야기, 위시리스트
- 개인 수집함: 추가·편집·삭제, 수량·상태·보관 위치·메모, 중복 필터
- 카메라/앨범: 사진 선택 → 사용자가 도감에서 우표 선택 → 개인 사진과 기록 저장
- 수집 기록 텍스트 복사
- 휴대폰 하단 탐색 및 넓은 화면의 사이드바
- 기기 내 저장. 서버 설정 없이 실행 가능

## 디자인

크림 `#FAFAF5`, 짙은 녹색 `#173E35`, 종이색 `#E9ECDD`. 불투명한 면, 얇은 구분선, 읽기 쉬운 한글 타이포그래피를 사용합니다. 글래스모피즘·배경 블러는 없습니다. Noto Sans KR의 400/700/800 굵기를 앱에 포함해 외부 폰트 요청 없이 표시합니다. 폰트 라이선스는 `assets/fonts/OFL.txt`에 있습니다.

## 명확한 한계

- 사진 AI 판독 함수와 로그인 UI를 구현·배포했습니다. 실제 AI 판독과 소셜 로그인 활성화에는 제공자 키/설정이 필요합니다. **[설정 및 현재 상태](AUTH_AND_AI_SETUP.md)**를 확인하세요.
- 기본 우표 이미지들은 기존 코드의 **예시 도안**이며, 정식 도감 사진이 아닙니다. 발행정보와 역사 설명도 공식 출처 대조 전 샘플입니다.
- 샘플 우표를 실제 소유물로 자동 추가하지 않습니다. 처음 시작하면 수집함은 비어 있습니다.
- 이메일/소셜 로그인 UI와 계정별 수집함 동기화를 구현했습니다. 관리자 웹, 이미지 검수, 구독·결제·거래는 후속 범위입니다.
- Supabase stamp_app을 연결하고 실제 DB에서 회원별 RLS 접근 제한을 검증했습니다. 실행 시 config/development.json을 지정하면 연결됩니다.
- 비로그인 개인 기록과 사진은 SharedPreferences에 저장됩니다. 로그인한 회원 기록과 사진은 Supabase에 저장합니다. 브라우저 데이터 삭제 시 없어질 수 있고, 대량 사진 저장에는 적합하지 않습니다. 출시 전 SQLite/파일 저장 및 계정별 동기화가 필요합니다.
- 앱스토어 출시용 서명, 결제 정책, 실기기 카메라 테스트는 아직 완료하지 않았습니다.

## 실행

이 환경의 Flutter 3.29.2 / Dart 3.7.2에서 분석·테스트·웹 빌드를 검증했습니다. 첨부 원본이 요구하던 더 높은 SDK 버전은 이 환경에서 실행 가능한 범위로 조정했으며, 실제로 해결된 의존성 버전은 `pubspec.lock`에 고정되어 있습니다.

```sh
flutter pub get
flutter run -d chrome --web-port 8318 --dart-define-from-file=config/development.json
flutter test
flutter analyze
flutter build web --pwa-strategy=none --no-web-resources-cdn --dart-define-from-file=config/development.json
```

Android/iOS 기기 실행은 `flutter devices`로 기기를 확인한 후 `flutter run -d <device-id>`를 사용합니다. 카메라와 사진 접근 목적 문자열을 iOS에 추가했고 Android 인터넷 권한을 명시했습니다.

## 이어서 개발하기

`DEVELOPMENT.md`에 기능별 완료 상태와 다음 구현 순서를 기록했습니다. `lib/screens/main_nav_screen.dart`가 현재 실행되는 화면입니다. `lib/models/stamp.dart`, `lib/services/stamp_repository.dart`, `lib/services/collection_service.dart`, `lib/widgets/stamp_visual_view.dart`는 원본 구조를 이어 사용합니다.

기존 하드코딩 API 키는 제거했습니다. 이미 배포했거나 공유한 원본에 들어 있던 Gemini 키는 제공자 콘솔에서 폐기/재발급해야 합니다. 새 Gemini 키를 앱 코드·dart-define·브라우저 저장소에 넣지 말고 서버 비밀값으로만 보관하세요.
