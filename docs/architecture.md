# Architecture

## Boundaries

The shared Rust crate owns all deterministic input behavior:

- single-key and double-press conversion rules
- case resolution
- monotonic-time comparison
- KZ/EN mode
- pending composition state
- context isolation and cleanup decisions

Native platform adapters own operating-system integration:

- receiving normalized keyboard and lifecycle events
- obtaining monotonic timestamps and repeat flags
- assigning a stable ID to each input context
- applying ordered `EngineAction` values through the official composition API
- scheduling a timeout callback
- displaying mode state and reloading settings

The core never calls InputMethodKit, TSF, networking, logging, or storage APIs.

The compiled source of truth for conversion rules is `core/src/rules.rs`.
`shared/rules.json` is the portable manifest for future settings and platform
tooling. An integration test checks that every compiled mapping is represented
in the manifest, so rule changes cannot silently leave it behind.

## Event flow

```text
native key event
       |
       v
normalize physical printable key + modifiers + context ID
       |
       v
Engine::handle_key
       |
       v
ordered EngineAction list
       |
       v
native composition/commit/forward operations
```

`SetComposition` replaces the current marked text. `CommitComposition` commits
that marked text. `ClearComposition` cancels it. The adapter must apply actions
in order.

## Timeout contract

A second key at exactly the configured threshold is a fast match. Therefore
`handle_timeout` commits only when elapsed time is strictly greater than the
threshold. Platform adapters should schedule the callback for the first
monotonic instant after the deadline and cancel stale callbacks.

## Context safety

Every printable event contains a platform-assigned `context_id`. If a pending
composition receives an event from another ID, the engine cancels the stale
composition before processing the new key. The adapter should still report
focus loss while the old client is valid so its composition can be committed.

No input text may be logged or sent outside the device.
