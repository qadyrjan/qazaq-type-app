#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bundle="$project_dir/platforms/macos/build/QazaqType.app"
plist="$bundle/Contents/Info.plist"
pkg_info="$bundle/Contents/PkgInfo"
executable="$bundle/Contents/MacOS/QazaqType"
icon="$bundle/Contents/Resources/QazaqType.tiff"

"$project_dir/scripts/build-macos.sh"

plutil -lint "$plist"
test "$(
    plutil -extract CFBundleIdentifier raw "$plist"
)" = "kz.qazaqtype.inputmethod.QazaqType"
test "$(plutil -extract InputMethodServerControllerClass raw "$plist")" = "QazaqInputController"
test "$(
    plutil -extract \
        ComponentInputModeDict.tsVisibleInputModeOrderedArrayKey.0 \
        raw \
        "$plist"
)" = "kz.qazaqtype.inputmethod.QazaqType.Kazakh"
test "$(
    /usr/libexec/PlistBuddy -c \
        "Print :ComponentInputModeDict:tsInputModeListKey:kz.qazaqtype.inputmethod.QazaqType.Kazakh:tsInputModeDefaultStateKey" \
        "$plist"
)" = "true"
test "$(
    /usr/libexec/PlistBuddy -c \
        "Print :ComponentInputModeDict:tsInputModeListKey:kz.qazaqtype.inputmethod.QazaqType.Kazakh:TISInputSourceID" \
        "$plist"
)" = "kz.qazaqtype.inputmethod.QazaqType.Kazakh"
test "$(
    plutil -extract InputMethodConnectionName raw "$plist"
)" = "QazaqType_Connection"
test "$(plutil -extract TISIntendedLanguage raw "$plist")" = "kk"
test "$(
    plutil -extract tsInputMethodCharacterRepertoireKey.0 raw "$plist"
)" = "Cyrl"
test "$(
    plutil -extract tsInputMethodCharacterRepertoireKey.1 raw "$plist"
)" = "Latn"
test -s "$bundle/Contents/Resources/en.lproj/InfoPlist.strings"
test -x "$executable"
test -s "$icon"
test "$(wc -c <"$pkg_info" | tr -d ' ')" = "8"
test "$(tr -d '\n' <"$pkg_info")" = "APPL????"
codesign --verify --strict "$bundle"
nm -gU "$executable" | grep -q "_qazaq_engine_handle_key"
