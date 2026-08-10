# Input rules

## Modes

KZ mode converts supported Latin keys to Kazakh Cyrillic. EN mode forwards
ordinary keys unchanged. In either mode, a fast `qq` toggles the mode and
commits neither `q`.

The first `q` is temporarily composed in EN mode so that the engine can
distinguish fast `qq` from literal text without deleting committed content.

## Timing

- Default threshold: 400ms
- Configurable range: 200ms through 800ms
- A pair at exactly the threshold matches
- A pair one millisecond beyond the threshold does not match
- Timestamps must come from a monotonic clock
- Automatic-repeat events never match a double-press rule

## Case

For letters, effective uppercase is `Shift XOR Caps Lock`. A double-press result
is uppercase when either constituent press is effectively uppercase. For
punctuation pairs, Shift on either press selects the uppercase result; Caps Lock
does not affect punctuation.

## Composition

Keys that may start a double rule are held as marked/composition text. A
different next key first commits the pending composition and is then processed.
An expired timeout commits the composition.

Pairs match left to right:

- `aaa` becomes `әа`
- `ssss` becomes `шш`
- `nnn` becomes `ңн`
- fast `qqq` toggles mode with the first two keys and processes the third in
  the new mode

## Special events

- Backspace cancels pending composition and is consumed.
- Escape cancels pending composition and is consumed.
- Space, Enter, Tab, Delete, navigation, Home, End, Page Up, and Page Down
  commit pending composition before being forwarded.
- Cursor movement, focus loss, and input-method deactivation commit pending
  composition.
- Context destruction and external composition cancellation clear pending
  composition.
- An explicit mode or configuration change clears pending composition.

These rules prevent a later key from modifying text at an old cursor or in a
different input context.

