# 우표모아 소셜 로그인 설정·검증

2026-10-05 확인: Supabase 프로젝트 `dyrteyrpimesipypwdpo`의 이메일 로그인은 Enabled, Google·Kakao는 Disabled. 신규 가입과 이메일 확인은 활성화, 익명 가입과 수동 계정 연결은 비활성화되어 있다. 실제 로그인 복귀 설정은 Site URL `http://localhost:3000`, 추가 Redirect URL 없음으로 확인되었다. 이는 최초 확인 당시 상태이다. 이후 사용자가 카카오 앱 생성 및 REST API 키·Client Secret을 Supabase에 저장했다고 알려주었다. 사용자 승인 후 개발용 Site URL `http://127.0.0.1:8320/` 및 모바일·웹 복귀 주소 3개를 저장하고 대시보드 목록에서 확인했다.

## 사용자가 준비할 카카오 설정

1. https://developers.kakao.com/ 에서 로그인하고 **앱 → 앱 생성**을 선택한다. 앱 이름은 우표모아, 회사명·카테고리에는 실제 운영 정보를 입력한다. 대표 도메인이 없다면 임의의 타인 도메인을 입력하지 않는다. 필요한 필드 때문에 생성이 막히면 해당 항목을 확인한 뒤 진행한다. 앱 아이콘은 기존 로고를 사용할 수 있다(250KB 미만).
2. 만든 앱의 **앱 → 플랫폼 키 → REST API 키**를 연다. REST API 키가 Supabase의 Client ID 역할을 한다. Native App Key·JavaScript Key·Admin Key를 넣는 방식이 아니다.
3. 같은 REST API 키 설정의 **카카오 로그인 Redirect URI**에 다음 주소를 정확히 등록하고 저장한다.
   `https://dyrteyrpimesipypwdpo.supabase.co/auth/v1/callback`
4. REST API 키의 **Client Secret**을 확인하고 사용 상태를 활성화한다. 새 자격증명 입력·발급·저장은 사용자가 콘솔에서 직접 진행한다. 키와 시크릿을 채팅이나 Git에 기록하지 않는다.
5. **카카오 로그인 → 일반**에서 사용 설정을 ON으로 하고, **동의항목**에서 닉네임·프로필 사진 제공을 설정한다. 동의 목적은 회원 식별 및 프로필 표시로 입력한다. 이메일을 설정할 권한이 있다면 선택 동의로 설정한다. 이메일 동의항목을 설정할 수 없는 앱은 우선 이메일 없는 계정을 허용하는 방식으로 테스트한다. 실제 요청에서 동의항목 권한 오류가 발생하면 요청 scope와 앱 권한을 확인한다.
6. [Supabase Sign In / Providers](https://supabase.com/dashboard/project/dyrteyrpimesipypwdpo/auth/providers)에서 Kakao를 열고 사용자 본인이 다음 값을 입력·저장한다.
   - Kakao enabled: ON
   - REST API Key: 2번의 REST API 키
   - Client Secret Code: 4번의 시크릿
   - Allow users without an email: 이메일을 제공하지 않는 경우 ON. 개인정보를 추가 요청하지 않고 로그인할 수 있도록 하는 설정이다.
7. [Supabase URL Configuration](https://supabase.com/dashboard/project/dyrteyrpimesipypwdpo/auth/url-configuration)에 로그인 복귀 주소를 등록한다. 개발 단계 Site URL은 `http://127.0.0.1:8320/`. 추가 Redirect URLs에는 아래 주소를 각각 등록한다.
   - `http://127.0.0.1:8320/`
   - `http://localhost:8320/`
   - `io.supabase.stampkorea://login-callback/`
   출시 때에는 실제 서비스 HTTPS 주소를 Site URL과 허용 목록에 등록한다. 스마트폰에서 맥의 IP로 웹을 테스트할 때에는 실제 LAN 주소도 따로 등록해야 한다. localhost는 접속한 기기 자신을 가리킨다.
8. 앱에서 카카오 로그인 → 사용자 인증·동의 → 앱 복귀 → 내 정보·수집함 확인 → 로그아웃 → 재로그인을 테스트한다. 로그인 동의와 실제 사용자 인증은 사용자가 직접 완료한다.

## 카카오 이메일과 기존 계정

이메일이 없는 카카오 회원도 UID를 기준으로 수집함·위시리스트를 저장할 수 있다. 다만 기존 이메일 회원과 별도 UID가 생성될 수 있다. 동일한 소유자로 보인다는 이유로 수집 데이터를 합치거나 관리자 권한을 이전하지 않는다. 같은 검증된 이메일을 제공하는 로그인 수단의 자동 계정 연결 여부는 Supabase의 실제 identity 결과로 확인한다. 이메일이 다른 계정이나 이메일을 제공하지 않는 계정의 연결은 별도 기능으로 다룬다.

## 구글 다음 단계

현재 Google은 웹·모바일 외부 브라우저 OAuth 경로가 구현되어 있으나 프로젝트에서 비활성화되어 있다. Google Cloud에서 OAuth 동의 화면과 웹 OAuth Client ID·Client Secret을 준비하고, 승인된 리디렉션 URI에 동일한 Supabase callback 주소를 등록해야 한다. 이후 Supabase Google Provider를 설정하고 실제 로그인한다. iOS/Android의 네이티브 Google 계정 선택창을 쓰는 SDK 연동은 이번 작업에 포함되지 않았다. 이를 추가할 때에는 웹 Client ID와 iOS/Android 별도 OAuth 클라이언트 설정을 준비한다.

## 이번 코드 수정 및 검증 범위

- 이메일·카카오·구글의 앱 복귀 주소를 한 곳에서 관리하고, callback 코드·토큰·화면 query를 새 로그인 redirect 주소에 포함하지 않는다.
- PKCE 흐름을 명시하고 세션 교환·저장·복구는 Supabase Flutter SDK에 맡긴다. 인증 코드를 앱에서 중복 교환하지 않는다.
- 모바일 소셜 로그인은 외부 브라우저에서 인증한다. Google은 계정 선택을 요청한다.
- provider 비활성·로그인 취소·만료/검증 실패 callback을 구분해서 안내한다. provider의 원문 메시지·토큰·HTML은 표시하지 않는다.
- 이메일 가입 확인 메일 재발송 버튼을 추가한다. 확인되지 않은 로그인에는 재발송 안내를 제공한다.
- 로그아웃은 이 기기의 세션을 종료한다. 계정 변경 때 기존 수집함·위시리스트·사진 판독 상태는 기존 소유자 분리 및 세대 번호 검사로 정리된다.
- 검증 통과: `tool/verify_auth_flow.dart`, `tool/verify_wishlist_sync.dart`, 위시리스트 rollback SQL 테스트, 변경 Dart 파일 분석 및 웹 빌드. 계정 분리 SQL 재검증과 이메일 없는 계정 fixture 검증은 도구 실행 요청이 거절되어 완료하지 못했다. 실제 사용자 인증, 이메일 링크 복귀, 소셜 로그인 성공, 아이폰 앱 복귀는 위 외부 설정 완료 후 추가 검증해야 한다. 키가 없는 상태에서 로그인 성공을 검증했다고 표시하지 않는다.

출처: [Supabase Kakao](https://supabase.com/docs/guides/auth/social-login/auth-kakao), [Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls), [카카오 앱 설정](https://developers.kakao.com/docs/ko/app-setting/app), [카카오 로그인 설정](https://developers.kakao.com/docs/ko/kakaologin/prerequisite), [Supabase Google](https://supabase.com/docs/guides/auth/social-login/auth-google).


## 모바일 코드·딥링크 확인 결과

- `lib/services/auth_flow.dart`: 모바일 복귀 주소는 `io.supabase.stampkorea://login-callback/`.
- `lib/services/supabase_service.dart`: Kakao OAuth를 외부 브라우저에서 열고 PKCE 세션 처리는 Supabase SDK에 맡긴다.
- `ios/Runner/Info.plist`: `CFBundleURLSchemes`에 `io.supabase.stampkorea` 등록, Flutter 기본 딥링크 비활성화로 SDK와 중복 처리 방지.
- `android/app/src/main/AndroidManifest.xml`: VIEW/DEFAULT/BROWSABLE 필터에 같은 scheme과 `login-callback` host 등록. 기본 Flutter 딥링크는 비활성화.
- iOS plist 구문 검사와 로그인 리디렉션·오류 처리 검증 통과. 실제 기기에서 카카오 인증 후 복귀는 아직 검증하지 않았다. Android 빌드는 사용자의 중단 지시에 따라 실행하지 않았다.
- 카카오 콘솔에는 HTTPS Supabase callback을, Supabase Redirect URLs에는 앱 custom scheme을 등록한다. 두 주소는 역할이 다르다.
- 현재 방식은 Supabase 브라우저 OAuth이므로 카카오 Native App Key, `kakao{키}` URL scheme, Kakao Flutter SDK를 추가하지 않는다. 네이티브 카카오 SDK 방식은 별도 구현이다.
- 앱 코드는 준비되어 있지만 기존 설치본에는 최근 로그인 흐름 변경이 없을 수 있다. 최신 소스로 앱을 다시 설치한 후 로그인한다. iPhone 시뮬레이터 업데이트 스크립트는 `scripts/update_simulator.command`이다.


## 이메일이 다른 로그인 계정 연결 (2026-10-05)

마이페이지 → 로그인 계정 관리에서 서버가 반환한 이메일·카카오·Google identity 연결 상태를 확인한다. 기존 이메일 회원으로 로그인한 뒤 연결 버튼에서 해당 소셜 계정의 인증을 완료한다. 일반 signInWithOAuth와 달리 linkIdentity를 사용하므로 기존 회원 UID를 유지한다. 수집함·위시리스트·회원등급 저장 키는 변경하지 않는다.

Supabase Sign In / Providers의 Allow manual linking은 2026-10-05 사용자 승인 후 활성화·저장하고 켜진 상태를 확인했다. Google은 provider 자격증명 설정이 별도로 필요하다. 인증 페이지를 열었다는 이유만으로 연결 완료로 표시하지 않고 실제 서버 identities에 있어야 연결됨을 표시한다. 페이지를 열었을 때의 UID와 현재 UID가 다르면 이전 회원의 상태·버튼을 표시하지 않는다. 카카오는 인증할 계정을 다시 확인하도록 prompt=login을 요청하고, Google은 계정 선택을 요청한다.

이미 다른 회원에 연결된 소셜 계정은 오류로 안내한다. 회원 간 데이터 통합·삭제·계정 연결 해제는 포함되지 않았다. 로그인 상태에서 다른 계정을 인증하는 실제 연결 성공 및 이후 로그아웃·재로그인 검증은 사용자의 인증 완료 후 진행한다.
