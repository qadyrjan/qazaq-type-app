# QazaqType

QazaqType is an offline Kazakh system input method for macOS and Windows.

The project uses a platform-independent Rust conversion engine. Native adapters
will connect that engine to:

- macOS InputMethodKit
- Windows Text Services Framework (TSF)

QazaqType does not use global keyboard hooks, clipboard replacement, simulated
deletion, per-application integrations, or remote text processing.

## Current status

Phase 1 is complete: the shared conversion core and its automated tests are
implemented. Native input method targets are intentionally not part of this
phase. See the [development progress](docs/progress.md).

## Build and test

```sh
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features
cargo test --workspace
```

Or run:

```sh
./scripts/test-core.sh
```

Build and structurally validate the current macOS InputMethodKit prototype:

```sh
./scripts/test-macos.sh
```

Build the native macOS settings application:

```sh
./scripts/test-settings-macos.sh
```

## Repository layout

- `core/`: shared Rust conversion state machine
- `shared/`: portable rule and localization data
- `platforms/`: native macOS and Windows adapters (future phases)
- `docs/`: architecture, behavior, privacy, and development notes
- `scripts/`: build and validation entry points

See [architecture](docs/architecture.md) and
[input rules](docs/input-rules.md) before changing engine behavior.
