# HEIC 사진 불러오기

아이폰 HEIC/HEIF 사진은 JPEG로 변환한 후 기존 사진 정규화·영역 추출·판독 경로에 전달한다. 확장자만 변경하지 않으며, 실제 ftyp 브랜드로 형식을 감지한다. JPG/PNG는 기존 처리 경로를 유지한다. 20MB 입력 제한, 변환 후 최대 1600px, JPEG 재인코딩을 통한 위치 정보 제거도 유지한다.

- iOS 앱: `stamp_korea/photo_import` 채널에서 ImageIO 썸네일 변환을 사용한다. 사진 방향을 적용하고 JPEG로 재인코딩한다. 네이티브 코드 변경이므로 기존 설치 앱은 다시 빌드·설치해야 한다.
- 웹: HEIC 선택 시 작업 스레드에서 변환한다. 브라우저 내장 디코더를 먼저 시도하고, 실패하면 고정 버전 `heic-to@1.6.5`를 CDN에서 불러온다. CDN에는 코드 요청만 보내며 사진은 전송하지 않는다. 변환 라이브러리를 내려받기 위한 인터넷 연결이 필요할 수 있다. 작업 완료·실패·55초 초과 시 작업 스레드를 종료한다.
- Android 네이티브 앱의 HEIC 변환은 이번 변경에 포함하지 않았다. JPG/PNG 또는 웹을 이용할 수 있다. Android 빌드는 실행하지 않았다.

검증: 실제 `IMG_6969.heic` 형식 감지 통과, Apple ImageIO를 이용한 실제 HEIC→738×1600 JPEG 변환 통과(맥에서 실행), Dart 분석 통과, 웹 브리지의 전달 복사·성공·실패·스레드 정리·용량 제한 테스트 통과, iOS Swift 소스 문법 검사 통과. 아이폰의 실제 앱 MethodChannel 흐름과 웹의 실제 HEIC 디코더 다운로드·변환은 실기기/브라우저에서 추가 확인이 필요하다. 웹 브리지 테스트는 실제 디코더 실행을 대신하지 않는다.

[heic-to 사용 문서](https://github.com/hoppergee/heic-to) · [Flutter image_picker 문서](https://pub.dev/packages/image_picker)
