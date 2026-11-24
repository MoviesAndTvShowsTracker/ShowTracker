#!/bin/bash
# Fast screen review: incremental build, install, open each screen by launch
# argument, screenshot, tile into one sheet. ~30 s instead of a UI-test run.
#
#   ios/scripts/shots.sh                      # light, all screens
#   APPEARANCE=dark ios/scripts/shots.sh      # dark
#   SCREENS="stats" WAIT=6 ios/scripts/shots.sh
#   API=http://localhost:5001 ios/scripts/shots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DEV=${DEV:-booted}
OUT=${OUT:-/tmp/marquee-shots}
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/Marquee-shots}
SCREENS=${SCREENS:-home films tv search you stats}
APP=com.jimil.marquee

xcodebuild -project Marquee.xcodeproj -scheme Marquee -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" build -quiet 2>&1 \
  | grep -E "error:" || true
xcrun simctl install "$DEV" "$DD/Build/Products/Debug-iphonesimulator/Marquee.app"

mkdir -p "$OUT"
rm -f "$OUT"/s-*.png
args=()
[ -n "${API:-}" ] && args+=(-apiBaseURL "$API")
# simctl ui appearance does not reliably switch the sim; force the app theme instead.
[ -n "${APPEARANCE:-}" ] && args+=(-marquee.appearance "$APPEARANCE")
for screen in $SCREENS; do
  xcrun simctl terminate "$DEV" "$APP" 2>/dev/null || true
  xcrun simctl launch "$DEV" "$APP" "-startTab=$screen" "${args[@]+"${args[@]}"}" >/dev/null
  sleep "${WAIT:-4}"
  xcrun simctl io "$DEV" screenshot "$OUT/s-$screen.png" >/dev/null 2>&1
done
n=$(ls "$OUT"/s-*.png | wc -l | tr -d ' ')
ffmpeg -loglevel error -y -pattern_type glob -i "$OUT/s-*.png" -vf "scale=240:-1,tile=${n}x1" "$OUT/sheet.png"
echo "$OUT/sheet.png"
