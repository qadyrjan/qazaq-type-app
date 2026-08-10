#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bundle="$project_dir/platforms/macos/build/QazaqType Installer.app"
embedded="$bundle/Contents/Resources/QazaqType.app"
installer_executable="$bundle/Contents/MacOS/QazaqType Installer"
input_executable="$embedded/Contents/MacOS/QazaqType"
version=$(
    /usr/libexec/PlistBuddy -c \
        "Print :CFBundleShortVersionString" \
        "$project_dir/platforms/macos/GuideInstaller/Info.plist"
)

QAZAQTYPE_ARCHS="x86_64 arm64" \
    "$project_dir/scripts/build-macos-installer.sh" >/dev/null

plutil -lint "$bundle/Contents/Info.plist"
plutil -lint "$embedded/Contents/Info.plist"
test "$(
    plutil -extract CFBundleIdentifier raw "$bundle/Contents/Info.plist"
)" = "kz.qazaqtype.installer"
test "$(
    plutil -extract CFBundleIdentifier raw "$embedded/Contents/Info.plist"
)" = "kz.qazaqtype.inputmethod.QazaqType"
test "$(lipo -archs "$installer_executable")" = "x86_64 arm64"
test "$(lipo -archs "$input_executable")" = "x86_64 arm64"
codesign --verify --deep --strict "$bundle"
test -s "$project_dir/dist/QazaqType-$version-macOS-universal.dmg"
test -s "$project_dir/dist/QazaqType-$version-macOS-universal.dmg.sha256"
