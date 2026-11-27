#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
macos_dir="$project_dir/platforms/macos"
source_dir="$macos_dir/GuideInstaller"
build_dir="$macos_dir/build"
bundle_dir="$build_dir/QazaqType Installer.app"
executable_dir="$bundle_dir/Contents/MacOS"
resources_dir="$bundle_dir/Contents/Resources"
architecture_build_dir="$build_dir/InstallerArchitectureBuild"
dist_dir="$project_dir/dist"
input_method_plist="$macos_dir/InputMethod/Info.plist"
version=$(
    /usr/libexec/PlistBuddy -c \
        "Print :CFBundleShortVersionString" \
        "$input_method_plist"
)
build_number=$(
    /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$input_method_plist"
)
output_name="QazaqType-$version-macOS-universal.dmg"
output_dmg="$dist_dir/$output_name"
architectures="${QAZAQTYPE_ARCHS:-x86_64 arm64}"

if [ -n "${QAZAQTYPE_SIGN_IDENTITY:-}" ]; then
    sign_identity="$QAZAQTYPE_SIGN_IDENTITY"
else
    available_identities=$(security find-identity -v -p codesigning 2>/dev/null)
    sign_identity=$(
        printf '%s\n' "$available_identities" \
            | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
            | head -n 1
    )
    if [ -z "$sign_identity" ]; then
        sign_identity=$(
            printf '%s\n' "$available_identities" \
                | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
                | head -n 1
        )
    fi
    sign_identity="${sign_identity:--}"
fi

QAZAQTYPE_ARCHS="$architectures" \
QAZAQTYPE_SIGN_IDENTITY="$sign_identity" \
    "$project_dir/scripts/build-macos.sh" >/dev/null

echo "Signing identity: $sign_identity"

mkdir -p \
    "$executable_dir" \
    "$resources_dir" \
    "$architecture_build_dir" \
    "$dist_dir"
cp "$source_dir/Info.plist" "$bundle_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $version" \
    -c "Set :CFBundleVersion $build_number" \
    "$bundle_dir/Contents/Info.plist"
ditto "$build_dir/QazaqType.app" "$resources_dir/QazaqType.app"
cp \
    "$build_dir/QazaqType.app/Contents/Resources/QazaqType.tiff" \
    "$resources_dir/QazaqType.tiff"
printf %s 'APPL????' >"$bundle_dir/Contents/PkgInfo"

architecture_binaries=""
for architecture in $architectures; do
    case "$architecture" in
        x86_64)
            swift_target="x86_64-apple-macosx12.0"
            ;;
        arm64)
            swift_target="arm64-apple-macosx12.0"
            ;;
        *)
            echo "Unsupported installer architecture: $architecture" >&2
            exit 1
            ;;
    esac

    architecture_dir="$architecture_build_dir/$architecture"
    module_cache="$architecture_dir/ModuleCache"
    architecture_binary="$architecture_dir/QazaqTypeInstaller"
    mkdir -p "$architecture_dir" "$module_cache"

    CLANG_MODULE_CACHE_PATH="$module_cache" \
    SWIFT_MODULECACHE_PATH="$module_cache" \
    xcrun swiftc \
        -O \
        -parse-as-library \
        -target "$swift_target" \
        -module-cache-path "$module_cache" \
        -Xcc "-fmodules-cache-path=$module_cache" \
        "$macos_dir/InputMethod/QazaqPreferences.swift" \
        "$source_dir/QazaqTypeInstaller.swift" \
        -framework AppKit \
        -framework Carbon \
        -framework SwiftUI \
        -o "$architecture_binary"
    architecture_binaries="$architecture_binaries $architecture_binary"
done

set -- $architecture_binaries
if [ "$#" -eq 1 ]; then
    cp "$1" "$executable_dir/QazaqType Installer"
else
    xcrun lipo -create "$@" -output "$executable_dir/QazaqType Installer"
fi

plutil -lint "$bundle_dir/Contents/Info.plist"
if [ "$sign_identity" = "-" ]; then
    codesign \
        --force \
        --options runtime \
        --sign "$sign_identity" \
        "$bundle_dir"
else
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --sign "$sign_identity" \
        "$bundle_dir"
fi
codesign --verify --deep --strict "$bundle_dir"

staging_dir=$(mktemp -d "$build_dir/QazaqTypeDMG.XXXXXX")
ditto "$bundle_dir" "$staging_dir/QazaqType Installer.app"
hdiutil create \
    -volname "QazaqType $version" \
    -srcfolder "$staging_dir" \
    -ov \
    -format UDZO \
    "$output_dmg" >/dev/null

if [ "$sign_identity" != "-" ]; then
    codesign \
        --force \
        --timestamp \
        --sign "$sign_identity" \
        "$output_dmg"
fi

(cd "$dist_dir" && shasum -a 256 "$output_name" >"$output_name.sha256")
echo "$output_dmg"
