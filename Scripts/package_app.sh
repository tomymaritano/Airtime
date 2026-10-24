#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/version.env"

DIST="$ROOT/dist"
APP="$DIST/DevWifiBar.app"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
APP_ENTITLEMENTS="$ROOT/Sources/DevWifiBar/DevWifiBar.entitlements"
WIDGET_ENTITLEMENTS="$ROOT/Sources/DevWifiBarWidgets/DevWifiBarWidgets.entitlements"

rm -rf "$DIST"
mkdir -p "$MACOS_DIR" "$CONTENTS/Resources"

if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  swift build -c release --product DevWifiBar --arch arm64
  swift build -c release --product DevWifiBar --arch x86_64
  ARM_BIN="$(swift build -c release --product DevWifiBar --arch arm64 --show-bin-path)/DevWifiBar"
  X86_BIN="$(swift build -c release --product DevWifiBar --arch x86_64 --show-bin-path)/DevWifiBar"
  lipo -create -output "$MACOS_DIR/DevWifiBar" "$ARM_BIN" "$X86_BIN"
else
  swift build -c release --product DevWifiBar
  BIN="$(swift build -c release --product DevWifiBar --show-bin-path)/DevWifiBar"
  cp "$BIN" "$MACOS_DIR/DevWifiBar"
fi

chmod +x "$MACOS_DIR/DevWifiBar"
cp "$ROOT/Sources/DevWifiBar/Info.plist" "$CONTENTS/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi
if [[ -d "$ROOT/Sources/DevWifiBar/Resources/Providers" ]]; then
  mkdir -p "$CONTENTS/Resources/Providers"
  cp "$ROOT/Sources/DevWifiBar/Resources/Providers/"*.png "$CONTENTS/Resources/Providers/"
fi

if [[ -x /usr/libexec/PlistBuddy ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$CONTENTS/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$CONTENTS/Info.plist"
fi

printf 'APPL????' > "$CONTENTS/PkgInfo"

embed_widgets() {
  if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
    echo "Skipping widgets: full Xcode / xcodebuild not available"
    return 0
  fi

  if [[ ! -f "$ROOT/DevWifiBar.xcodeproj/project.pbxproj" ]]; then
    if command -v xcodegen >/dev/null 2>&1; then
      (cd "$ROOT" && xcodegen generate)
    else
      echo "Skipping widgets: xcodegen not found"
      return 0
    fi
  fi

  local only_active=YES
  if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    only_active=NO
  fi

  if ! xcodebuild \
      -project "$ROOT/DevWifiBar.xcodeproj" \
      -scheme DevWifiBarWidgets \
      -configuration Release \
      -derivedDataPath "$ROOT/.build/xcode" \
      MARKETING_VERSION="$VERSION" \
      CURRENT_PROJECT_VERSION="$VERSION" \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGN_STYLE=Manual \
      ONLY_ACTIVE_ARCH="$only_active" \
      build
  then
    echo "Widget build failed; packaging app only"
    return 0
  fi

  local appex
  appex="$(find "$ROOT/.build/xcode/Build/Products" -name 'DevWifiBarWidgets.appex' -print -quit || true)"
  if [[ -z "$appex" ]]; then
    echo "Widget .appex not found after build"
    return 0
  fi

  mkdir -p "$CONTENTS/PlugIns"
  rm -rf "$CONTENTS/PlugIns/DevWifiBarWidgets.appex"
  cp -R "$appex" "$CONTENTS/PlugIns/DevWifiBarWidgets.appex"
  codesign --force --sign - --entitlements "$WIDGET_ENTITLEMENTS" "$CONTENTS/PlugIns/DevWifiBarWidgets.appex"
  echo "Embedded DevWifiBarWidgets.appex"
}

embed_widgets

signing_identity() {
  if [[ -n "${DEVELOPER_ID:-}" ]]; then
    printf '%s\n' "$DEVELOPER_ID"
    return 0
  fi
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Developer ID Application/ { print $2; exit }'
}

sign_app() {
  local identity="$1"
  # Keep at least one element. bash 3.2 with set -u treats an empty "${array[@]}" as unbound.
  local -a args
  args=(--force --sign "$identity")
  if [[ "$identity" != "-" ]]; then
    args+=(--options runtime --timestamp)
  fi
  if [[ -d "$CONTENTS/PlugIns/DevWifiBarWidgets.appex" ]]; then
    codesign "${args[@]}" --entitlements "$WIDGET_ENTITLEMENTS" \
      "$CONTENTS/PlugIns/DevWifiBarWidgets.appex"
    codesign "${args[@]}" --entitlements "$APP_ENTITLEMENTS" "$APP"
  else
    codesign --deep "${args[@]}" --entitlements "$APP_ENTITLEMENTS" "$APP"
  fi
}

can_notarize() {
  [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]] \
    || [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]
}

notarize_zip() {
  local zip="$1"
  if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    echo "Notarizing $zip with profile $NOTARY_KEYCHAIN_PROFILE"
    xcrun notarytool submit "$zip" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
  else
    echo "Notarizing $zip with Apple ID $APPLE_ID"
    xcrun notarytool submit "$zip" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait
  fi
}

IDENTITY="$(signing_identity || true)"
if [[ -n "$IDENTITY" ]]; then
  echo "Signing with $IDENTITY"
  sign_app "$IDENTITY"
else
  if [[ "${REQUIRE_NOTARIZE:-0}" == "1" ]]; then
    echo "REQUIRE_NOTARIZE=1 but no Developer ID Application identity" >&2
    exit 1
  fi
  echo "No Developer ID Application identity; ad-hoc sign (Gatekeeper will warn)"
  sign_app "-"
fi

ZIP="$DIST/DevWifiBar-${VERSION}.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "$IDENTITY" && "$IDENTITY" != "-" ]] && can_notarize; then
  notarize_zip "$ZIP"
  xcrun stapler staple "$APP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "Notarized and stapled $APP"
elif [[ -n "$IDENTITY" && "$IDENTITY" != "-" ]]; then
  if [[ "${REQUIRE_NOTARIZE:-0}" == "1" ]]; then
    echo "REQUIRE_NOTARIZE=1 but missing NOTARY_KEYCHAIN_PROFILE or APPLE_ID / APPLE_APP_SPECIFIC_PASSWORD / APPLE_TEAM_ID" >&2
    exit 1
  fi
  echo "Signed but not notarized. Run Scripts/setup_notary.sh once, then:"
  echo "  NOTARY_KEYCHAIN_PROFILE=devwibar-notary ./Scripts/package_app.sh"
fi

echo "Built $APP"
echo "Zipped $ZIP"
codesign -dv --verbose=2 "$APP" 2>&1 | head -20 || true

