# 우표모아 — stamp_korea

Flutter 기반 대한민국 우표 도감·사진 판독·개인 수집 앱입니다. iOS/Android 프로젝트와 같은 소스의 웹 관리자 화면을 포함하며 Supabase Auth/DB/Storage/Edge Functions를 사용합니다.

**현재 기능, 검증 범위, 출시 전 작업과 교환 매칭 로드맵은 [PROJECT_STATUS.md](PROJECT_STATUS.md)를 기준으로 확인합니다.** 구현·배포가 사용자 흐름 검증 완료를 의미하지 않습니다.

비로그인·무료·프리미엄 이용 정책과 최신 화면 변경은 [MEMBERSHIP_POLICY.md](MEMBERSHIP_POLICY.md)를 참조합니다.

## 구현된 영역

- 홈·오늘의 우표·최근 발행, 공식 이미지/설명 도감, 검색·테마 분류.
- 이메일·Google·Kakao 인증 코드, 계정별 수집함, 여러 소장 상태, 공식 도감 이미지 기반 등록.
- 사진 선택·품질 안내·자르기·제한적 영역 추출, Gemini 관찰 + DB 후보/시각 비교.
- 명시적 사진 제공·학습 동의·철회, 관리자 검수와 승인 사진 비교 활용.
- 관리자 도감 수정·이미지 업로드·재수집·이력, 회원관리·등급 구조, 운영 통계.

위시리스트는 계정별 클라우드 저장이며 로그인·앱 복귀·화면 진입·새로고침 시 최신 기록을 불러옵니다. 추가 모델 학습·판독 오류 관리·실제 결제·광고·교환/거래는 완료되지 않았습니다. 자세한 상태는 중앙 문서를 참조하세요.

## 실행

Flutter/Dart 의존성은 pubspec.lock을 사용합니다. 연결 설정 config/development.json은 Git에서 제외됩니다. Gemini 키·Supabase 서비스 역할 키를 앱 코드/공개 설정에 넣지 않습니다.

```sh
flutter pub get
flutter run -d chrome --web-port 8320 --dart-define-from-file=config/development.json
```

이미 생성된 웹 파일은 프로젝트 폴더에서 아래 명령으로 실행합니다. 터미널 창을 열어두세요.

```sh
zsh start_admin.command
```

- 사용자 앱: http://127.0.0.1:8320/
- 관리자: http://127.0.0.1:8320/?admin=true
- 통계: http://127.0.0.1:8320/?admin=true&section=stats&v=20261001-stats1
- 관리자 URL만으로 권한이 생기지 않습니다. 서버가 실제 계정 권한을 확인합니다.
- iPhone 시뮬레이터 갱신: scripts/update_simulator.command (Xcode/권한 필요).

## 검사와 빌드

```sh
flutter analyze --no-pub
flutter test
node --experimental-strip-types --test supabase/functions/identify-stamp/hybrid.test.ts
dart --packages=.dart_tool/package_config.json tool/verify_core.dart
flutter build web --no-pub --pwa-strategy=none --no-web-resources-cdn --dart-define-from-file=config/development.json
```

소켓이 차단된 환경에서는 Flutter 화면 테스트를 실행할 수 없습니다. 순수 로직 검사로 화면 검사까지 완료했다고 판단하지 않습니다. 새 웹 빌드 후에는 브라우저 탭도 새로 로드해야 합니다.

## 운영·설계 자료

- [기능/진행/검증과 단계별 로드맵](PROJECT_STATUS.md)
- [회원 등급 구조](supabase/MEMBERSHIPS.md)
- [사진 제공·검수·추가 학습 범위](supabase/PHOTO_RECOGNITION.md)
- [인증/AI 설정 가이드](AUTH_AND_AI_SETUP.md) — 대시보드 설정 별도 확인 필요
- [메일 템플릿](supabase/templates/README.md)
- [초기 인수인계 기록](DEVELOPMENT.md) — 과거 기록, 현재 상태의 기준 아님

공식 이미지/원문은 사용자가 우표포털 담당자의 이용 허가를 받았다고 알려준 자료를 기반으로 수집했습니다. 권한 확인 자료와 출처 정보를 운영에서 보관합니다. 로컬 게스트 기록은 브라우저 데이터 삭제 시 사라질 수 있습니다. 현재 서비스는 출시 검증 진행 중입니다.
