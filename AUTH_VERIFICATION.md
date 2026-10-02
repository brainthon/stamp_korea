# 로그인·계정별 데이터 검증 (2026-10-02)

## 확인 결과
| 항목 | 결과 | 범위 |
|---|---|---|
| 이메일 로그인 | 기존 로그인 세션과 로그아웃 확인 | 비밀번호 입력부터 재로그인까지는 사용자 인증 필요 |
| 구글 로그인 | Supabase 제공자 Disabled | 앱은 브라우저 OAuth 구현, 네이티브 SDK 미구현 |
| 카카오 로그인 | Supabase 제공자 Disabled | 앱은 브라우저 OAuth 구현 |
| 수집함·위시리스트 분리 | 실제 DB 권한 검증 통과 | 임시 A·B 사용자로 authenticated 역할과 JWT 주체를 변경해 검증 |
| 비회원 접근 | DB 접근 거부, 웹 방문자 홈 전환 확인 | 로그아웃 후 나의 수집 통계 숨김 |
| 계정 전환 UI | 미완료 | 실제 두 계정 로그인과 저장·재조회 검증 필요 |

테스트한 항목: A·B 본인 수집함 조회, 타인 위시리스트 조회 차단, 타인 수집함 수정·삭제 차단, 타인 소유자 지정 등록 및 소유권 변경 차단, 비회원 개인 테이블 접근 차단.
DB 검증용 사용자와 수집 기록·위시리스트는 하나의 트랜잭션에서 생성하고 전부 ROLLBACK했다. 인증 메일이나 공지를 발송하지 않았으며 기존 사용자 데이터를 수정하지 않았다.
기존 이메일 세션으로 마이페이지 확인 후 실제 로그아웃을 수행했다. 방문자 홈에서 개인 통계가 숨겨졌고 로그인 화면으로 진입했다. Google 버튼 요청 후 “로그인 제공자 설정을 확인해야 합니다.” 오류를 확인했다. 비밀번호 재로그인 및 OAuth 승인·콜백 왕복은 검증하지 않았다.

## 수정
- user_collections의 anon 권한 전부 제거.
- authenticated의 TRUNCATE/REFERENCES/TRIGGER 권한 제거. 필요한 SELECT/INSERT/UPDATE/DELETE 유지.
- RLS는 계속 본인 user_id에만 허용. TRUNCATE는 RLS로 제한되지 않아 명시적으로 권한 제거.
- 마이페이지와 인증 화면의 “위시리스트는 이 기기에 저장” 문구를 계정 저장으로 수정. 소스 수정이며 미리보기 재빌드는 이번 작업에서 하지 않았다.
- 변경 후 권한 조회와 DB 검증 통과. 보안 advisor는 기존 유출 비밀번호 보호 비활성화 경고 1건만 반환.
- 변경한 Dart 화면 2개만 정적 분석하여 오류 없음 확인. 안드로이드 빌드는 실행하지 않았다.
  안내: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## 구글 네이티브 로그인
앱의 Google SDK가 계정 선택·인증을 처리하고 Google ID token을 Supabase signInWithIdToken에 전달해 앱의 Supabase 세션을 만든다. iOS에서는 Google SDK 인증 과정에 시스템 인증 창이 나타날 수 있다. 웹 미리보기는 별도로 웹 OAuth를 유지한다.
현재 google_sign_in 패키지 및 네이티브 플랫폼 설정이 없다. 전환 완료 상태가 아니다.

필요한 사용자 설정:
1. Google Cloud / Google Auth Platform에서 우표모아 프로젝트 선택 및 로그인 동의 화면 설정. 테스트 상태라면 테스트 사용자 지정.
2. OAuth Web 클라이언트 ID: Supabase 인증용 serverClientId. 브라우저 OAuth callback은 https://dyrteyrpimesipypwdpo.supabase.co/auth/v1/callback.
3. OAuth iOS 클라이언트: 번들 ID com.stampkorea.app.stampKorea.
4. OAuth Android 클라이언트: 패키지 com.stampkorea.app.stamp_korea + 실제 빌드 서명 SHA-1. 개발/배포 서명은 별도 등록이 필요할 수 있다. 인증서 지문은 빌드를 재개하지 않고 별도로 추출할 수 있다.
5. Supabase Google 제공자에 사용할 클라이언트 ID들을 등록하고 활성화. OAuth client secret은 Supabase 대시보드에 직접 입력하며 앱이나 채팅에 넣지 않는다.
6. Kakao Developers 앱의 카카오 로그인 활성화·동의 항목·동일 Supabase callback URI 설정 및 Supabase Kakao 제공자 설정.
7. 설정 완료 후 사용자가 직접 로그인·동의를 완료하고 콜백 복귀 및 계정별 기록 왕복 검증.

클라이언트 ID는 앱 설정용 식별자이며 Gemini API 키와 다르다. Flutter 코드·iOS URL 스킴·Android 연동은 클라이언트 등록 후 진행 가능.

공식 참고:
- https://supabase.com/docs/guides/auth/social-login/auth-google
- https://supabase.com/docs/reference/dart/auth-signinwithidtoken
- https://pub.dev/packages/google_sign_in_android
- https://pub.dev/packages/google_sign_in_ios
