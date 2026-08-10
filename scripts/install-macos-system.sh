#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_bundle="$project_dir/platforms/macos/build/QazaqType.app"
system_input_methods="/Library/Input Methods"
destination="$system_input_methods/QazaqType.app"
user_destination="${HOME:?}/Library/Input Methods/QazaqType.app"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$project_dir/scripts/build-macos.sh"

sudo mkdir -p "$system_input_methods"

if [ -e "$destination" ]; then
    existing_identifier=$(
        plutil -extract CFBundleIdentifier raw \
            "$destination/Contents/Info.plist" 2>/dev/null || true
    )
    existing_team=$(
        codesign -dvv "$destination" 2>&1 \
            | sed -n 's/^TeamIdentifier=//p'
    )
    case "$existing_identifier" in
        kz.qazaqtype.inputmethod|kz.qazaqtype.inputmethod.QazaqType)
            ;;
        *)
            echo "Refusing to replace an unrelated bundle: $destination" >&2
            exit 1
            ;;
    esac
    case "$existing_team" in
        84N74QBQ63|5YX83877Q3)
            ;;
        *)
            echo "Refusing to replace QazaqType signed by another team." >&2
            exit 1
            ;;
    esac

    backup="${HOME:?}/.Trash/QazaqType-system.app.$(date +%Y%m%d%H%M%S)"
    "$lsregister" -u "$destination" 2>/dev/null || true
    sudo mv "$destination" "$backup"
    sudo chown -R "$(id -u):$(id -g)" "$backup"
    echo "Moved the previous system copy to: $backup"
fi

sudo ditto "$source_bundle" "$destination"
sudo chown -R root:wheel "$destination"
codesign --verify --strict "$destination"

if [ -e "$user_destination" ]; then
    backup="${HOME:?}/.Trash/QazaqType-user.app.$(date +%Y%m%d%H%M%S)"
    "$lsregister" -u "$user_destination" 2>/dev/null || true
    mv "$user_destination" "$backup"
    echo "Moved the user-level copy to: $backup"
fi

"$lsregister" -f "$destination"
"$destination/Contents/MacOS/QazaqType" --register-input-source
"$destination/Contents/MacOS/QazaqType" --enable-input-source
if ! "$destination/Contents/MacOS/QazaqType" --select-input-source; then
    echo "QazaqType was enabled, but macOS deferred selection until the next login." >&2
fi
sudo touch "$system_input_methods"

echo "Installed system-wide: $destination"
echo "QazaqType registration and activation completed."
