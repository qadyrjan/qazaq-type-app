# macOS development

The first native adapter is an InputMethodKit background application. Apple
documents that an `IMKServer` manages client connections and creates one
`IMKInputController` per input session. The adapter overrides direct event
handling and applies core actions through InputMethodKit composition methods.

## Build

Requirements:

- macOS 12 or newer
- Xcode command-line tools
- Rust toolchain

```sh
./scripts/build-macos.sh
```

The unsigned development artifact is produced at:

```text
platforms/macos/build/QazaqType.app
```

The script applies an ad-hoc signature for local structural validation. It does
not install or register the input method.

For an installable development build, first create an Apple Development
certificate in Xcode and pass its full identity:

```sh
QAZAQTYPE_SIGN_IDENTITY="Apple Development: Name (TEAMID)" \
  ./scripts/install-macos.sh
```

The build script deliberately warns when it falls back to ad-hoc signing. An
ad-hoc signature has no stable Team ID and must not be treated as a successful
system-registration test.

The checked-in Xcode project exposes the native sources and delegates its build
to the same reproducible script:

```sh
xcodebuild -project platforms/macos/QazaqType.xcodeproj -target QazaqType
```

Run bundle-level validation with:

```sh
./scripts/test-macos.sh
```

## Adapter contract

- Hardware key codes are normalized to unmodified ASCII keys.
- `NSEvent.timestamp` and system uptime provide monotonic milliseconds.
- `NSEvent.isARepeat` prevents long presses from becoming double rules.
- Command, Control, and Option shortcuts first end pending composition and are
  then forwarded.
- InputMethodKit owns all marked-text and commit operations.
- No key or text content is logged.

## Local installation

After bundle validation:

```sh
./scripts/install-macos.sh
```

This installs only for the current user under `~/Library/Input Methods`, then
uses the public Text Input Source Services API to request registration and
enablement. A logout/login can still be required after installing a properly
development-signed build. The current test machine did not accept the ad-hoc
build into the input-source database even after reboot.
Remove it recoverably with:

```sh
./scripts/uninstall-macos.sh
```

The uninstall script moves the bundle to Trash rather than permanently
deleting it.

Check the actual Text Input Source Services database—not just the file on
disk—with:

```sh
./scripts/check-macos-input-source.sh
```

## Settings application

Build and validate the native settings application with:

```sh
./scripts/test-settings-macos.sh
```

The settings app and input method share the
`kz.qazaqtype.inputmethod.shared` preferences domain. After saving, the
settings app posts a distributed notification so active input sessions can
reload without requiring the settings process to remain open.

## Apple references

- [IMKServer](https://developer.apple.com/documentation/inputmethodkit/imkserver)
- [IMKInputController](https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller)
- [IMKServerInput](https://developer.apple.com/documentation/inputmethodkit/imkserverinput)
