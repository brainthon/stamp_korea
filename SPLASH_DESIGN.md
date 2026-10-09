# 우표모아 시작 화면 (2026-10-09)

## 플랫폼 구조
- iOS: 노란색 정적 LaunchScreen.storyboard → 앱 초기화 → 최초 실행 브랜드 소개 또는 메인 화면. 시스템 시작 화면에는 글자나 로고가 없다.
- Android: 불투명 노란 배경과 정적 벡터 아이콘 → 앱 초기화 → 최초 실행 브랜드 소개 또는 메인 화면. Android 12 이상에는 windowSplashScreen 설정을 사용한다. 별도 시작 Activity는 추가하지 않는다.
- Android 아이콘은 288dp, 192dp 중앙 안전 원 안에 도안을 배치한다. 다크 모드에도 같은 배경과 도안을 사용한다.

## 앱 내부 브랜드 소개
- 우편 문양, 건축, 자연·새, 꽃을 표현한 우표 4장. 실제 발행 우표를 복제한 도안이 아니다.
- 우표가 기울어진 채 차례로 올라오며 겹치고, 40px 로고와 16px 문구가 나타난다.
- 애니메이션 900ms, 전환 150ms. 소개를 위한 추가 고정 대기는 없다. 앱 초기화가 더 오래 걸리면 완료까지 기다린다.
- SharedPreferences의 brand_intro_seen_v1으로 기기별 최초 실행에만 소개를 표시한다. 계정별 설정이 아니며 로그아웃해도 다시 표시하지 않는다. 앱 데이터 삭제 시 초기화된다.
- 이후 실행 및 OAuth 복귀는 초기화가 끝나면 즉시 진입한다. 동작 줄이기 설정에서는 최초 소개 및 전환 애니메이션을 생략한다.
- 저장소 읽기가 실패하면 소개를 생략한다.

## 검증 범위
Dart 정적 검사, 웹 빌드, 네이티브 XML 구문 검증. 실제 iOS·Android 빌드 및 기기별 잘림·전환·회전 확인은 별도로 필요하다. Android 빌드는 기존 사용자 중단 요청에 따라 실행하지 않았다.

## 공식 참고
- https://developer.apple.com/design/human-interface-guidelines/launching
- https://developer.android.com/develop/ui/views/launch/splash-screen
