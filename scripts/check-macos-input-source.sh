#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_file="$project_dir/platforms/macos/Installer/inspect-input-sources.c"
inspector="$project_dir/platforms/macos/build/inspect-input-sources"

xcrun clang "$source_file" -framework Carbon -o "$inspector"
matches=$("$inspector" qazaq 2>/dev/null)

if [ -z "$matches" ]; then
    echo "QazaqType is not present in the macOS Text Input Source database." >&2
    exit 1
fi

printf '%s\n' "$matches"

