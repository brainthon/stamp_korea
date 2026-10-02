#!/bin/zsh
set -e
cd "${0:A:h}/.."
FLUTTER_BIN=/Users/airm2/flutter/bin/flutter
open -a Simulator
SIM_ID=$(xcrun simctl list devices booted -j | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((x["udid"] for v in d["devices"].values() for x in v if x["state"]=="Booted" and "iPhone" in x["name"]),""))')
if [[ -z "$SIM_ID" ]]; then
  SIM_ID=$(xcrun simctl list devices available -j | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((x["udid"] for v in d["devices"].values() for x in v if "iPhone" in x["name"]),""))')
  if [[ -z "$SIM_ID" ]]; then
    echo '사용 가능한 iPhone 시뮬레이터가 없습니다. Xcode에서 iOS Simulator를 설치해주세요.'
    read '?Enter를 누르면 종료합니다.'
    exit 1
  fi
  xcrun simctl boot "$SIM_ID"
fi
xcrun simctl bootstatus "$SIM_ID" -b
"$FLUTTER_BIN" --suppress-analytics build ios --simulator --debug --no-pub --dart-define-from-file=config/development.json
APP_PATH="$PWD/build/ios/iphonesimulator/Runner.app"
APP_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_PATH/Info.plist")
xcrun simctl terminate "$SIM_ID" "$APP_ID" 2>/dev/null || true
xcrun simctl install "$SIM_ID" "$APP_PATH"
xcrun simctl launch "$SIM_ID" "$APP_ID"
echo '최신 우표모아 앱 설치 및 실행이 완료되었습니다.'
read '?Enter를 누르면 종료합니다.'
