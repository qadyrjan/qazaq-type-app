#!/bin/sh
set -eu

cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features
cargo test --workspace

