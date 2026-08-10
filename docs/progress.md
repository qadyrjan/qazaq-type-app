# Development progress

## Phase 1 — shared core

Status: complete

Implemented:

- Rust workspace and dependency-free shared engine
- complete single-key and double-press rule tables
- Shift/Caps Lock case handling
- inclusive monotonic double-press timing
- KZ/EN mode and fast `qq` switching
- timeout, automatic-repeat, triple-press, and context isolation behavior
- special-key and lifecycle cleanup behavior
- validated runtime configuration
- portable JSON rule and test-case manifests
- automated formatting, linting, and test script

Validation:

```text
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features
cargo test --workspace
```

## Phase 2 — first native platform

Status: in progress

Implemented:

- dependency-free Rust C ABI with ownership tests
- Swift `IMKServer` entry point and per-session `IMKInputController`
- physical key normalization, modifier and repeat handling
- ordered marked-text, commit, clear, forward, and mode actions
- monotonic timeout dispatch
- lifecycle cleanup hooks
- valid ad-hoc-signed macOS input-method bundle
- Xcode project wrapper and command-line build/validation scripts
- current-user installation and recoverable uninstallation scripts
- development bundle installed under the current user's Input Methods directory
- public input-source registration requested, but macOS still does not create
  a TIS database entry after reboot
- remaining verified environment blocker: no Apple Development or Developer ID
  signing identity is installed; the current ad-hoc build has no Team ID

Still required:

- local installation and input-source registration test
- system-level typing tests across standard macOS text clients
- mode indicator and configuration reload
- production signing, universal binary, installer, and uninstaller

## Phase 3 — settings

Status: in progress

Implemented:

- shared user preferences domain
- enable/disable conversion
- KZ or EN default mode
- 200–800ms double-press threshold
- mode-notification preference
- distributed configuration-change notification
- live input-controller configuration reload
- native SwiftUI settings application
- Kazakh default interface, rule reference, privacy, and about tabs

Still required:

- mode notification presentation
- author, website, and Instagram metadata
- settings localization for Chinese and English
