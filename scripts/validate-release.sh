#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
cd "$repo_dir"

test -f LICENSE
test -f NOTICE
test -f KablayIL/Resources/PrivacyInfo.xcprivacy
test -f README.md
test -f docs/gallery.md
test -f docs/offline-behavior.md
test "$(find docs/app-store/screenshots -type f \( -name '*.png' -o -name '*.jpg' \) | wc -l | tr -d ' ')" = "25"
test -f docs/app-store/screenshots/pro-01-workspace.jpg

for screenshot in docs/app-store/screenshots/{01-catalog,02-smart-search,03-request,04-specialist}.png; do
  test -f "$screenshot"
  test "$(sips -g pixelWidth "$screenshot" | awk '/pixelWidth/ { print $2 }')" = "1320"
  test "$(sips -g pixelHeight "$screenshot" | awk '/pixelHeight/ { print $2 }')" = "2868"
done

app_icon="KablayIL/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
test -f "$app_icon"
test "$(sips -g pixelWidth "$app_icon" | awk '/pixelWidth/ { print $2 }')" = "1024"
test "$(sips -g pixelHeight "$app_icon" | awk '/pixelHeight/ { print $2 }')" = "1024"
test "$(sips -g hasAlpha "$app_icon" | awk '/hasAlpha/ { print $2 }')" = "no"

grep -q 'MARKETING_VERSION: "1.0.0"' project.yml
grep -q 'CURRENT_PROJECT_VERSION: "44"' project.yml
grep -q 'PRODUCT_BUNDLE_IDENTIFIER: il.co.kablay.app' project.yml
grep -q 'ITSAppUsesNonExemptEncryption: false' project.yml
grep -q '<string>production</string>' KablayIL/KablayIL.entitlements
grep -q 'applinks:kablay.co.il' KablayIL/KablayIL.entitlements
grep -q 'NOT AN OPEN-SOURCE LICENSE' LICENSE

# App Store Connect requires a supported release toolchain. This machine selects
# Xcode-beta by default, so reject it before building an archive.
xcode_output="$(xcodebuild -version)"
xcode_version="$(printf '%s\n' "$xcode_output" | awk 'NR == 1 { print $2 }')"
xcode_build="$(printf '%s\n' "$xcode_output" | awk 'NR == 2 { print $3 }')"
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"

if [[ "${xcode_version%%.*}" -lt 26 ]]; then
  echo "Xcode ${xcode_version} is too old; App Store uploads need Xcode 26 or newer." >&2
  exit 1
fi
if [[ "${sdk_version%%.*}" -lt 26 ]]; then
  echo "iphoneos SDK ${sdk_version} is too old; App Store uploads need the iOS 26 SDK." >&2
  exit 1
fi
# Xcode 27.0 release shares 27A266a with its release candidate. A trailing
# letter alone therefore cannot distinguish a beta from a shipping Xcode.
if [[ "$xcode_build" == *[a-z] && "$xcode_build" != "27A266a" ]]; then
  echo "Xcode ${xcode_version} (${xcode_build}) is a beta; select the release Xcode:" >&2
  echo "  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/validate-release.sh" >&2
  exit 1
fi
echo "Toolchain: Xcode ${xcode_version} (${xcode_build}), iphoneos SDK ${sdk_version}."

xcodegen generate
plutil -lint KablayIL/Info.plist KablayIL/Resources/PrivacyInfo.xcprivacy KablayIL/KablayIL.entitlements

xcodebuild \
  -project KablayIL.xcodeproj \
  -scheme KablayIL \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$repo_dir/build/ReleaseValidation" \
  CODE_SIGNING_ALLOWED=NO \
  build

app_dir="$repo_dir/build/ReleaseValidation/Build/Products/Release-iphonesimulator/KablayIL.app"
test -f "$app_dir/PrivacyInfo.xcprivacy"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$app_dir/Info.plist")" = "1.0.0"
test "$(plutil -extract CFBundleVersion raw -o - "$app_dir/Info.plist")" = "44"
test "$(plutil -extract KABLAY_API_BASE_URL raw -o - "$app_dir/Info.plist")" = "https://api.kablay.co.il"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' "$app_dir/Info.plist")" = "kablay"
test "$(plutil -extract KABLAY_TRIAGE_BASE_URL raw -o - "$app_dir/Info.plist")" = "https://kablay-triage.sergii-ziborov.workers.dev"
test "$(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations~ipad' "$app_dir/Info.plist" | grep -c UIInterfaceOrientation)" = "4"

echo 'KABLAY IL release validation passed.'
