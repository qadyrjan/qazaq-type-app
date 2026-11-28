#!/bin/sh
set -eu

lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
user_dir="${HOME:?}/Library/Input Methods"
system_dir="/Library/Input Methods"

pkill -9 -f "/Input Methods/QazaqType.app/Contents/" 2>/dev/null || true

for bundle in "$user_dir/QazaqType.app" "$system_dir/QazaqType.app" /Users/Shared/QazaqType*.app; do
    [ -e "$bundle" ] || continue
    "$lsregister" -u "$bundle" 2>/dev/null || true
    if rm -rf "$bundle" 2>/dev/null && [ ! -e "$bundle" ]; then
        echo "Removed: $bundle"
    else
        sudo rm -rf "$bundle"
        echo "Removed with administrator rights: $bundle"
    fi
done
touch "$user_dir" 2>/dev/null || true

echo "Log out and back in if QazaqType remains visible in Input Sources."
