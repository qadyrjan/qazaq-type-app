#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
macos_dir="$project_dir/platforms/macos"
source_dir="$macos_dir/InputMethod"
build_dir="$macos_dir/build"
bundle_dir="$build_dir/QazaqType.app"
executable_dir="$bundle_dir/Contents/MacOS"
resources_dir="$bundle_dir/Contents/Resources"
module_cache="$build_dir/ModuleCache"
icon_generator="$build_dir/generate-icon"
architecture_build_dir="$build_dir/ArchitectureBuild"
architectures="${QAZAQTYPE_ARCHS:-$(uname -m)}"

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

cd "$project_dir"
mkdir -p \
    "$executable_dir" \
    "$resources_dir" \
    "$module_cache" \
    "$architecture_build_dir"
# An interrupted codesign process can leave this generated staging file behind.
# It must not be included in the next bundle signature.
rm -f "$executable_dir/QazaqType.cstemp"
cp "$source_dir/Info.plist" "$bundle_dir/Contents/Info.plist"
ditto "$source_dir/Resources" "$resources_dir"
printf %s 'APPL????' >"$bundle_dir/Contents/PkgInfo"
CLANG_MODULE_CACHE_PATH="$module_cache" \
SWIFT_MODULECACHE_PATH="$module_cache" \
xcrun swiftc \
    -module-cache-path "$module_cache" \
    -Xcc "-fmodules-cache-path=$module_cache" \
    "$macos_dir/Resources/generate-icon.swift" \
    -framework AppKit \
    -o "$icon_generator"
"$icon_generator" \
    "$resources_dir/QazaqType.tiff" \
    "$resources_dir/QazaqTypeMenuTemplate.tiff"

architecture_binaries=""
for architecture in $architectures; do
    case "$architecture" in
        x86_64)
            rust_target="x86_64-apple-darwin"
            swift_target="x86_64-apple-macosx12.0"
            ;;
        arm64)
            rust_target="aarch64-apple-darwin"
            swift_target="arm64-apple-macosx12.0"
            ;;
        *)
            echo "Unsupported macOS architecture: $architecture" >&2
            exit 1
            ;;
    esac

    cargo build \
        --release \
        --target "$rust_target" \
        -p qazaqtype-core-ffi

    architecture_dir="$architecture_build_dir/$architecture"
    architecture_module_cache="$architecture_dir/ModuleCache"
    architecture_binary="$architecture_dir/QazaqType"
    client_bridge_object="$architecture_dir/QazaqClientBridge.o"
    mkdir -p "$architecture_dir" "$architecture_module_cache"

    xcrun clang \
        -O2 \
        -target "$swift_target" \
        -fmodules \
        -fmodules-cache-path="$architecture_module_cache" \
        -c "$source_dir/QazaqClientBridge.m" \
        -o "$client_bridge_object"

    CLANG_MODULE_CACHE_PATH="$architecture_module_cache" \
    SWIFT_MODULECACHE_PATH="$architecture_module_cache" \
    xcrun swiftc \
        -O \
        -target "$swift_target" \
        -module-cache-path "$architecture_module_cache" \
        -Xcc "-fmodules-cache-path=$architecture_module_cache" \
        -import-objc-header "$source_dir/QazaqCore.h" \
        "$source_dir/main.swift" \
        "$source_dir/QazaqPreferences.swift" \
        "$source_dir/QazaqInputController.swift" \
        "$client_bridge_object" \
        "$project_dir/target/$rust_target/release/libqazaqtype_core_ffi.a" \
        -framework Carbon \
        -framework Cocoa \
        -framework InputMethodKit \
        -o "$architecture_binary"
    architecture_binaries="$architecture_binaries $architecture_binary"
done

set -- $architecture_binaries
if [ "$#" -eq 1 ]; then
    cp "$1" "$executable_dir/QazaqType"
else
    xcrun lipo -create "$@" -output "$executable_dir/QazaqType"
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
codesign --verify --strict "$bundle_dir"

if [ "$sign_identity" = "-" ]; then
    echo "warning: QazaqType is ad-hoc signed and has no stable Team ID." >&2
    echo "warning: set QAZAQTYPE_SIGN_IDENTITY to an Apple Development or Developer ID identity for system registration." >&2
fi

echo "$bundle_dir"
