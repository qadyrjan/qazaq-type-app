#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bundle="$project_dir/platforms/macos/build/QazaqType Settings.app"
plist="$bundle/Contents/Info.plist"
executable="$bundle/Contents/MacOS/QazaqType Settings"

"$project_dir/scripts/build-settings-macos.sh"
plutil -lint "$plist"
test "$(plutil -extract CFBundleIdentifier raw "$plist")" = "kz.qazaqtype.settings"
test -x "$executable"
codesign --verify --strict "$bundle"

