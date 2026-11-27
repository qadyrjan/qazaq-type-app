# Input rules

## Keyboards

The user chooses one keyboard in the settings app, the installer, or the
QazaqType input menu:

- **Latin** (default): supported Latin keys convert to Kazakh Cyrillic, as
  described in the sections below.
- **Cyrillic (ЙЦУКЕН)**: for people used to the Russian keyboard. See
  [Cyrillic keyboard](#cyrillic-keyboard).

## Modes

KZ mode converts supported Latin keys to Kazakh Cyrillic. EN mode forwards
ordinary keys unchanged. A fast `qq` at the start of a word toggles the mode
and commits neither `q`. Inside a Kazakh word a fast `qq` is the common `ққ`
(халыққа, шыққан). In EN mode a fast `qq` toggles anywhere.

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

## Cyrillic keyboard

Every key produces what it produces on the Russian PC keyboard (Russian –
PC), including punctuation: `/` is `.`, Shift+`/` is `,`, Shift+`2` is `"`.
The physical key position decides the letter, independent of the user's other
installed layouts.

The nine Kazakh letters are typed by pressing the Russian letter people
usually substitute for them twice:

| Keys | Result | Third press |
|---|---|---|
| `аа` | `ә` | `ааа` → `аа` |
| `ии` | `і` | `иии` → `иі` (жиі, биік) |
| `оо` | `ө` | `ооо` → `оо` (зоопарк) |
| `нн` | `ң` | `ннн` → `нн` (күннен) |
| `хх` | `һ` | `ххх` → `хх` |
| `уу` | `ұ` or `ү` by harmony | `ууу` → the other one |
| `к` | `қ` in a back-vowel word, `к` in a front-vowel word | `кк` → always `к`; `ккк` → `ққ`/`кк`; `кккк` → `кк` |
| `г` | `ғ` in a back-vowel word, `г` in a front-vowel word | `гг` → always `г`; `ггг` → `ғғ`/`гг`; `гггг` → `гг` |

### Composition

The whole word is held as composition and redrawn after every key, so the
composition is always exactly what will be committed. Space, Enter, Tab,
Escape, navigation keys, digits, punctuation, cursor movement, and focus loss
commit the word. Backspace removes the last visible letter of the word and is
consumed. Auto-repeat never combines presses. Timing is not used.

### Harmony

Back vowels are `а о ы ұ я`; front vowels are `ә ө і ү е э`; `и у ю ё` are
neutral.

- `уу` takes the class of the nearest non-neutral vowel before it, or after it
  when none precedes (`жуумыс` → жұмыс, `туурии` → түрі).
- `к` and `г` take the class of the nearest vowel before them, including a
  resolved `ұ`/`ү`, or after them when none precedes (`казак` → қазақ,
  `мектеп`, `алга` → алға).
- A word with no deciding vowel at all is looked up in a short list of common
  words (`буул` → бұл, `куун` → күн, `гуул` → гүл); otherwise it is treated as
  back. `ууу` always gives the other choice.

Russian loanwords with back vowels are not detected: type `кк`/`гг` for their
`к`/`г` (`ккомпания`, `технологгия`). Russian text should be typed with the
system Russian layout.

### Mode switch

`йй` (the physical `qq`) commits the current word and switches to EN mode. In
EN mode a fast `qq` switches back.
