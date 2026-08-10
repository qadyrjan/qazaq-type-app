#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_plist="$project_dir/platforms/macos/GuideInstaller/Info.plist"
version=$(
    /usr/libexec/PlistBuddy -c \
        "Print :CFBundleShortVersionString" \
        "$source_plist"
)
profile="${QAZAQTYPE_NOTARY_PROFILE:-qazaqtype-notary}"
dmg="$project_dir/dist/QazaqType-$version-macOS-universal.dmg"

if [ ! -s "$dmg" ]; then
    echo "DMG not found: $dmg" >&2
    echo "Run scripts/build-macos-installer.sh first." >&2
    exit 1
fi

signature_details=$(codesign -dvv "$dmg" 2>&1)
case "$signature_details" in
    *"Authority=Developer ID Application:"*)
        ;;
    *)
        echo "Refusing to notarize a DMG not signed with Developer ID Application." >&2
        printf '%s\n' "$signature_details" >&2
        exit 1
        ;;
esac

codesign --verify --verbose=2 "$dmg"
xcrun notarytool submit "$dmg" \
    --keychain-profile "$profile" \
    --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature \
    --verbose=4 "$dmg"

dist_dir=$(dirname "$dmg")
output_name=$(basename "$dmg")
(cd "$dist_dir" && shasum -a 256 "$output_name" >"$output_name.sha256")

echo "Notarized and stapled: $dmg"
