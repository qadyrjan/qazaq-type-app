#!/bin/sh
set -eu

destination="${HOME:?}/Library/Input Methods/QazaqType.app"

if [ ! -e "$destination" ]; then
    echo "QazaqType is not installed."
    exit 0
fi

trash_destination="${HOME:?}/.Trash/QazaqType.app.$(date +%Y%m%d%H%M%S)"
mv "$destination" "$trash_destination"
touch "${HOME:?}/Library/Input Methods"

echo "Moved the installed input method to: $trash_destination"
echo "Log out and back in if QazaqType remains visible in Input Sources."

