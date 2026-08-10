#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_bundle="$project_dir/platforms/macos/build/QazaqType.app"
input_methods_dir="${HOME:?}/Library/Input Methods"
destination="$input_methods_dir/QazaqType.app"
registrar="$project_dir/platforms/macos/build/qazaqtype-register"
module_cache="$project_dir/platforms/macos/build/InstallerModuleCache"

"$project_dir/scripts/build-macos.sh"
mkdir -p "$input_methods_dir"
ditto "$source_bundle" "$destination"
codesign --verify --strict "$destination"
mkdir -p "$module_cache"
xcrun swiftc \
    -module-cache-path "$module_cache" \
    -Xcc "-fmodules-cache-path=$module_cache" \
    "$project_dir/platforms/macos/Installer/register.swift" \
    -framework Carbon \
    -o "$registrar"
"$registrar" "$destination"
touch "$input_methods_dir"

echo "Installed: $destination"
echo "QazaqType registration was requested through the macOS public API."

if codesign -dvv "$destination" 2>&1 | grep -q 'TeamIdentifier=not set'; then
    echo "warning: the installed build has no Team ID and may be rejected by the input-source scanner." >&2
fi
