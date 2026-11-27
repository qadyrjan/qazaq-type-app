#!/bin/sh
set -eu

# The settings app is built and signed inside the input method bundle by
# build-macos.sh. This script copies it out for running it on its own.

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_dir="$project_dir/platforms/macos/build"
embedded="$build_dir/QazaqType.app/Contents/Helpers/QazaqType Settings.app"
bundle_dir="$build_dir/QazaqType Settings.app"

"$project_dir/scripts/build-macos.sh" >/dev/null

rm -rf "$bundle_dir"
ditto "$embedded" "$bundle_dir"
codesign --verify --strict "$bundle_dir"

echo "$bundle_dir"
