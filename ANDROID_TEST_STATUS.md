# 안드로이드 실행·검사 기록

2026-10-02

- Android Studio, SDK 및 `Medium_Phone_API_36` 가상 기기를 확인했다.
- Android Studio Device Manager로 가상 기기를 시작했다. Flutter가 `sdk gphone64 arm64`를 실행 대상으로 인식했다.
- 우표모아 프로젝트를 별도 창에 열었다. `.idea/runConfigurations/main_dart.xml`의 `additionalArgs`에 `--dart-define-from-file=config/development.json`을 지정해 연결 설정을 전달하도록 했다.
- 최초 실행에서 Android Flutter 도구·패키지 다운로드를 확인했다. 실행 옵션을 수정하면서 첫 빌드를 중단했으며 exit 130은 이 중단 결과다.
- 올바른 실행 옵션으로 재시작한 뒤 `Running Gradle task 'assembleDebug'...`까지 확인했다. APK 생성/설치 완료는 확인하지 못했다.
- 직접 ADB 연결은 `could not install smartsocket listener: Operation not permitted` 오류로 실패했다. 이후 Android Studio UI 제어는 `noWindowsAvailable` 오류로 끊겼다. 이 결과만으로 Android Studio 앱 자체의 강제 종료라고 판단하지 않는다.
- 앱 홈·검색·상세·메뉴 이동 및 로그인 후 흐름 검사는 미실행이다. 에뮬레이터 실행과 앱 테스트 통과를 구분한다.

## 이어서 실행

Finder에서 `scripts/update_android.command`를 더블클릭한다. 기존 에뮬레이터 연결 또는 가상 기기 시작 → Android 시작 대기 → 연결 설정 포함 APK 빌드 → 재설치 → 앱 실행 순으로 진행한다. 로그인과 AI 기능은 실제 계정 로그인이 필요하다. 이 스크립트는 `zsh -n` 구문 검사만 통과했으며 실행 완료 검사는 아직 하지 못했다.

## 남은 확인

1. 스플래시와 방문자 홈: 미색 배경·흰색 네비게이션·가입 안내 줄바꿈 확인.
2. 도감: 2025년 검색, 테마 필터, 공식 이미지·발행 상세 정보 표시.
3. 하단 4개 메뉴 이동 및 방문자 로그인 진입.
4. 사용자 직접 로그인 후 위시리스트 저장/다른 기기 조회, 수집 상태 여러 개 등록, 프로필·알림 설정 저장.
5. 카메라/사진 선택과 실제 판독은 로그인 계정 및 사진 접근 권한이 준비된 뒤 검사.
6. 회원탈퇴는 현재 회원으로 시험하지 않는다. 별도 테스트 계정과 삭제 시점 확인을 거쳐 검사한다.
