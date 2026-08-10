#!/bin/sh
set -eu

profile="${QAZAQTYPE_NOTARY_PROFILE:-qazaqtype-notary}"
team_id="${QAZAQTYPE_TEAM_ID:-5YX83877Q3}"

if [ "$#" -gt 1 ]; then
    echo "usage: $0 [apple-id-email]" >&2
    exit 2
fi

apple_id="${1:-}"
if [ -z "$apple_id" ]; then
    printf "Apple ID email: "
    IFS= read -r apple_id
fi

if [ -z "$apple_id" ]; then
    echo "Apple ID email is required." >&2
    exit 2
fi

echo "The next prompt requests an app-specific password."
echo "It is stored by notarytool in your login keychain, not in this project."
xcrun notarytool store-credentials "$profile" \
    --apple-id "$apple_id" \
    --team-id "$team_id"

echo "Saved notarization profile: $profile"
