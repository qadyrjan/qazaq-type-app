#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
macos_dir="$project_dir/platforms/macos"
settings_dir="$macos_dir/Settings"
input_method_dir="$macos_dir/InputMethod"
build_dir="$macos_dir/build"
bundle_dir="$build_dir/QazaqType Settings.app"
executable_dir="$bundle_dir/Contents/MacOS"
resources_dir="$bundle_dir/Contents/Resources"
module_cache="$build_dir/SettingsModuleCache"

"$project_dir/scripts/build-macos.sh" >/dev/null

mkdir -p "$executable_dir" "$resources_dir" "$module_cache"
cp "$settings_dir/Info.plist" "$bundle_dir/Contents/Info.plist"
cp \
    "$build_dir/QazaqType.app/Contents/Resources/QazaqType.tiff" \
    "$resources_dir/QazaqType.tiff"
printf %s 'APPL????' >"$bundle_dir/Contents/PkgInfo"

CLANG_MODULE_CACHE_PATH="$module_cache" \
SWIFT_MODULECACHE_PATH="$module_cache" \
xcrun swiftc \
    -O \
    -module-cache-path "$module_cache" \
    -Xcc "-fmodules-cache-path=$module_cache" \
    "$input_method_dir/QazaqPreferences.swift" \
    "$settings_dir/QazaqTypeSettings.swift" \
    -framework AppKit \
    -framework SwiftUI \
    -o "$executable_dir/QazaqType Settings"

if [ -n "${QAZAQTYPE_SIGN_IDENTITY:-}" ]; then
    sign_identity="$QAZAQTYPE_SIGN_IDENTITY"
else
    sign_identity=$(
        security find-identity -v -p codesigning 2>/dev/null \
            | sed -n \
                -e 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
                -e 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
            | head -n 1
    )
    sign_identity="${sign_identity:--}"
fi

plutil -lint "$bundle_dir/Contents/Info.plist"
codesign --force --sign "$sign_identity" "$bundle_dir"
codesign --verify --strict "$bundle_dir"

echo "$bundle_dir"
