#!/bin/zsh
set -eu
cd "${0:A:h}/.."
STAMP_FLUTTER=/Users/airm2/flutter/bin/flutter
STAMP_SDK=/Users/airm2/Library/Android/sdk
STAMP_ADB="$STAMP_SDK/platform-tools/adb"
STAMP_EMULATOR="$STAMP_SDK/emulator/emulator"
STAMP_LOG="${TMPDIR:-/private/tmp/}stamp-android-emulator.log"
function stamp_finish {
  local stamp_status=$?
  if (( stamp_status != 0 )); then
    print '\n실행이 완료되지 않았습니다. 위 오류를 확인해 주세요.'
  fi
  read '?Enter를 누르면 종료합니다.' || true
}
trap stamp_finish EXIT
[[ -f config/development.json ]] || { print 'config/development.json 연결 설정이 없습니다.'; exit 1; }
"$STAMP_ADB" start-server
STAMP_SERIAL=$("$STAMP_ADB" devices | /usr/bin/awk '$1 ~ /^emulator-/ && $2 == "device" {print $1; exit}')
if [[ -z "$STAMP_SERIAL" ]]; then
  STAMP_AVD=$("$STAMP_EMULATOR" -list-avds | /usr/bin/head -n 1)
  [[ -n "$STAMP_AVD" ]] || { print 'Android Studio Device Manager에서 가상 기기를 먼저 만들어 주세요.'; exit 1; }
  print "가상 기기 실행: $STAMP_AVD"
  nohup "$STAMP_EMULATOR" -avd "$STAMP_AVD" > "$STAMP_LOG" 2>&1 < /dev/null &
fi
for STAMP_ATTEMPT in {1..90}; do
  STAMP_SERIAL=$("$STAMP_ADB" devices | /usr/bin/awk '$1 ~ /^emulator-/ && $2 == "device" {print $1; exit}')
  if [[ -n "$STAMP_SERIAL" ]] && [[ $("$STAMP_ADB" -s "$STAMP_SERIAL" shell getprop sys.boot_completed 2>/dev/null | /usr/bin/tr -d '\r') == 1 ]]; then
    break
  fi
  sleep 2
done
[[ -n "$STAMP_SERIAL" ]] || { print "에뮬레이터 연결 실패. 로그: $STAMP_LOG"; exit 1; }
[[ $("$STAMP_ADB" -s "$STAMP_SERIAL" shell getprop sys.boot_completed | /usr/bin/tr -d '\r') == 1 ]] || { print '안드로이드 시작 시간이 초과되었습니다. 다시 실행해 주세요.'; exit 1; }
print '최신 우표모아 APK 빌드 중…'
"$STAMP_FLUTTER" --suppress-analytics build apk --debug --no-pub --dart-define-from-file=config/development.json
STAMP_APK="$PWD/build/app/outputs/flutter-apk/app-debug.apk"
[[ -f "$STAMP_APK" ]] || { print 'APK 파일이 생성되지 않았습니다.'; exit 1; }
"$STAMP_ADB" -s "$STAMP_SERIAL" install -r "$STAMP_APK"
"$STAMP_ADB" -s "$STAMP_SERIAL" shell am start -n com.stampkorea.app.stamp_korea/.MainActivity
print "\n최신 우표모아 앱 설치·실행 완료. APK: $STAMP_APK"
