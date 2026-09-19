# 사진 판독 · 회원 계정 연결 안내

2026-09-15 기준. 연결 프로젝트: stamp_app (dyrteyrpimesipypwdpo).

## 구현 및 배포한 내용

- 이메일 회원가입/로그인, 가입 확인 메일, 비밀번호 재설정/변경 화면.
- Kakao/Google OAuth 진입과 웹·Android·iOS 복귀 처리.
- 로그인한 계정별 Supabase 수집 기록 조회/저장/삭제. 게스트 기록과 분리.
- 비공개 stamp-photos 저장소. 회원 본인의 경로만 접근 가능. 사진 표시용 서명 URL은 1시간 유효하며 내 계정 > 수집 기록 새로고침으로 갱신.
- 사진 정규화: 최대 1600px JPEG, 위치·EXIF 제거, 4MB 제한.
- identify-stamp Edge Function 배포. 사용자 JWT를 Supabase Auth getUser로 검증하며 공개 키/비로그인 요청 거부.
- 서버의 Gemini 호출과 구조화 결과: 도안, 읽힌 글자, 액면가, 연도, 추정 이름과 불확실성.
- 기본 Gemini 모델: gemini-3.6-flash. GEMINI_MODEL 비밀값으로 변경 가능. 기존 2.5 Flash는 신규 사용자 호출 시 404를 반환하여 교체함.
- 일일 회원당 요청 20회 제한(UTC). 서비스 호출 실패도 시도 횟수에 포함. 키 미설정 요청은 포함하지 않음.
- 결과 확인 후 도감에서 사용자가 우표 선택 → 사진과 수집 기록 저장.
- 사진은 판독 요청에 사용하며 자동으로 공식 도감·학습 데이터에 추가하지 않음.

## 대시보드에서 완료할 설정

비밀 키를 채팅이나 Flutter 코드에 붙여 넣지 마세요.

### 1. Gemini

[Supabase 함수 Secrets](https://supabase.com/dashboard/project/dyrteyrpimesipypwdpo/functions/secrets)에서
GEMINI_API_KEY를 추가합니다. [Google AI Studio](https://aistudio.google.com/apikey)에서 발급한 서버용 키를 입력하세요.
원본 앱에 공개되었던 기존 키는 재사용하지 말고 폐기/재발급합니다.
이 키는 함수가 요청마다 읽으므로 입력 후 앱 재빌드 없이 적용됩니다.

### 2. 로그인 복귀 주소

[Supabase Auth URL 설정](https://supabase.com/dashboard/project/dyrteyrpimesipypwdpo/auth/url-configuration):

- 개발용 Site URL: http://127.0.0.1:8318/
- Additional Redirect URLs: http://127.0.0.1:8318/
- Additional Redirect URLs: io.supabase.stampkorea://login-callback/
- 실제 배포 시 HTTPS 앱 주소를 정확히 추가하고 Site URL도 배포 주소로 교체.
- 휴대폰 브라우저에서 LAN 주소로 접속하면 그 주소도 별도로 등록해야 함.
- 이메일 확인/재설정 링크는 PKCE를 시작한 같은 브라우저/기기에서 열어 테스트.

### 3. Kakao

[카카오 개발자 콘솔](https://developers.kakao.com/)에서 앱을 만들고 카카오 로그인을 활성화합니다.

- Redirect URI: https://dyrteyrpimesipypwdpo.supabase.co/auth/v1/callback
- [Supabase Auth Providers](https://supabase.com/dashboard/project/dyrteyrpimesipypwdpo/auth/providers)의 Kakao에서 REST API 키와 Kakao Login Client Secret 입력 후 활성화.
- 프로필/닉네임 동의 항목 설정. 이메일 동의를 사용할 수 없다면 Supabase Kakao의 이메일 없는 사용자 허용 옵션을 검토.
- 네이티브 SDK 로그인이 아니라 시스템 브라우저를 이용한 OAuth 방식.

### 4. Google

[Google Cloud 인증 정보](https://console.cloud.google.com/apis/credentials)에서 OAuth 동의 화면과 웹 애플리케이션 OAuth Client를 준비합니다.

- 승인된 리디렉션 URI: https://dyrteyrpimesipypwdpo.supabase.co/auth/v1/callback
- Supabase Google Provider에 Client ID와 Client Secret 입력 후 활성화.
- OAuth 앱이 테스트 상태라면 사용할 계정을 테스트 사용자에 등록.

현재 확인 결과 이메일 가입은 활성화, 이메일 확인 필수, Google/Kakao는 비활성입니다.
제공자가 꺼져 있을 때 앱은 외부 오류 페이지로 이동하지 않고 안내를 표시합니다.
Supabase 기본 메일 발송 제한이 있으므로 운영 전 전용 SMTP도 설정합니다.

## 실행

개발 설정 파일에는 공개 가능한 Supabase publishable key만 있습니다.

```sh
flutter pub get
flutter run -d chrome --web-port 8318 --dart-define-from-file=config/development.json
flutter build web --pwa-strategy=none --no-web-resources-cdn --dart-define-from-file=config/development.json
flutter test
flutter analyze
```

Android/iOS는 같은 dart-define-from-file 옵션으로 실행합니다.
서버 API 키는 dart-define에 넣지 않습니다.

## 검증과 남은 범위

- Flutter 기존 6개 테스트 + 사진 정규화/입력 거부/로그인 필요/가입 양식/복구 화면 5개 테스트 통과.
- 실제 DB에서 회원 간 조회·수정·등록 격리, 비회원 조회 차단, 클라이언트의 한도 우회 차단, 20회 제한 검증. 테스트 레코드는 트랜잭션 롤백.
- 비로그인 함수 호출은 401로 거부되는 것 확인.
- 실제 이메일 수신/인증, Google/Kakao 로그인 완료, Gemini 응답 품질은 사용자 설정 후 확인 필요.
- iOS/Android 실기기 OAuth 복귀·카메라 권한은 아직 검증하지 않음.
- 도감 19종은 검증 전 샘플이고 이미지도 예시 도안. AI가 새 우표를 발견해도 공식 도감에 자동 등록하지 않음.
- 현재 자동 도감 후보 순위 검색/벡터 검색은 없음. AI 관찰을 보고 사용자가 기존 도감에서 선택.
- 게스트 수집함 자동 가져오기, 회원 탈퇴, 관리자 검수, 결제는 후속 범위.
- 새 사진은 비공개 저장소에 보관. 기존 공개 stamp-images도 비공개로 전환. 오래된 공개 URL이 있다면 운영자 확인 후 경로 이관 필요.
- 소유자 없는 기존 DB 기록 1건은 삭제하지 않았으며 일반 회원에게 노출되지 않음. 소유자를 확인하기 전 임의 계정에 귀속시키지 않음.
- DB 변경 원문은 supabase/schema.sql, 실행된 변경 이력은 Supabase migrations에서 확인. schema.sql은 기존 프로젝트 대상 변경문이며 새 DB용 전체 초기 스키마는 아님.
- 보안 Advisor의 유출 비밀번호 차단 설정은 아직 비활성. [설정 안내](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

공식 문서: [Kakao](https://supabase.com/docs/guides/auth/social-login/auth-kakao), [Google](https://supabase.com/docs/guides/auth/social-login/auth-google), [모바일 복귀](https://supabase.com/docs/guides/auth/native-mobile-deep-linking), [Gemini 구조화 응답](https://ai.google.dev/gemini-api/docs/structured-output).
