//! Cyrillic (ЙЦУКЕН) typing.
//!
//! A user who is used to the Russian keyboard keeps every Russian letter in
//! its usual place. The nine Kazakh letters are typed by pressing the Russian
//! letter they usually substitute twice (`аа` → `ә`, `ии` → `і`, ...).
//!
//! The whole word is held as composition. Vowel harmony then resolves the
//! letters whose correct form depends on the rest of the word: `к` → `қ`/`к`,
//! `г` → `ғ`/`г`, and `уу` → `ұ`/`ү`. The word is committed at a word
//! boundary such as Space, so the displayed composition is always exactly the
//! text that will be committed.

/// What a physical key produces on the Russian (PC) keyboard.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum CyrillicKey {
    /// A lowercase Cyrillic letter.
    Letter(char),
    /// A digit or punctuation mark, already resolved for Shift.
    Symbol(char),
}

/// Maps a physical (US-position) key to the Russian PC keyboard.
pub(crate) fn cyrillic_key(key: char, shift: bool) -> Option<CyrillicKey> {
    let letter = match key {
        '`' => 'ё',
        'q' => 'й',
        'w' => 'ц',
        'e' => 'у',
        'r' => 'к',
        't' => 'е',
        'y' => 'н',
        'u' => 'г',
        'i' => 'ш',
        'o' => 'щ',
        'p' => 'з',
        '[' => 'х',
        ']' => 'ъ',
        'a' => 'ф',
        's' => 'ы',
        'd' => 'в',
        'f' => 'а',
        'g' => 'п',
        'h' => 'р',
        'j' => 'о',
        'k' => 'л',
        'l' => 'д',
        ';' => 'ж',
        '\'' => 'э',
        'z' => 'я',
        'x' => 'ч',
        'c' => 'с',
        'v' => 'м',
        'b' => 'и',
        'n' => 'т',
        'm' => 'ь',
        ',' => 'б',
        '.' => 'ю',
        _ => return cyrillic_symbol(key, shift).map(CyrillicKey::Symbol),
    };
    Some(CyrillicKey::Letter(letter))
}

fn cyrillic_symbol(key: char, shift: bool) -> Option<char> {
    let (plain, shifted) = match key {
        '1' => ('1', '!'),
        '2' => ('2', '"'),
        '3' => ('3', '№'),
        '4' => ('4', ';'),
        '5' => ('5', '%'),
        '6' => ('6', ':'),
        '7' => ('7', '?'),
        '8' => ('8', '*'),
        '9' => ('9', '('),
        '0' => ('0', ')'),
        '-' => ('-', '_'),
        '=' => ('=', '+'),
        '\\' => ('\\', '/'),
        '/' => ('.', ','),
        _ => return None,
    };
    Some(if shift { shifted } else { plain })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Harmony {
    Back,
    Front,
}

impl Harmony {
    const fn flipped(self) -> Self {
        match self {
            Self::Back => Self::Front,
            Self::Front => Self::Back,
        }
    }
}

fn letter_harmony(letter: char) -> Option<Harmony> {
    if matches!(letter, 'а' | 'о' | 'ы' | 'ұ' | 'я') {
        Some(Harmony::Back)
    } else if matches!(letter, 'ә' | 'ө' | 'і' | 'ү' | 'е' | 'э') {
        Some(Harmony::Front)
    } else {
        None
    }
}

/// Russian letters whose repeated press produces a Kazakh letter.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Repeatable {
    /// `а` → `ә` → `аа`
    A,
    /// `и` → `і` → `иі`
    I,
    /// `о` → `ө` → `оо`
    O,
    /// `н` → `ң` → `нн`
    N,
    /// `х` → `һ` → `хх`
    H,
    /// `у` → `ұ`/`ү` by harmony → the other one
    U,
    /// `қ`/`к` by harmony → `к` → doubled → `кк`
    K,
    /// `ғ`/`г` by harmony → `г` → doubled → `гг`
    G,
}

impl Repeatable {
    const fn for_letter(letter: char) -> Option<Self> {
        Some(match letter {
            'а' => Self::A,
            'и' => Self::I,
            'о' => Self::O,
            'н' => Self::N,
            'х' => Self::H,
            'у' => Self::U,
            'к' => Self::K,
            'г' => Self::G,
            _ => return None,
        })
    }

    const fn max_presses(self) -> u8 {
        match self {
            Self::K | Self::G => 4,
            _ => 3,
        }
    }
}

/// One letter position built from one or more presses of the same key.
#[derive(Debug, Clone, PartialEq, Eq)]
struct Unit {
    letter: char,
    repeatable: Option<Repeatable>,
    presses: u8,
    upper_first: bool,
    upper_rest: bool,
    from_auto_repeat: bool,
}

impl Unit {
    /// Harmony contributed by letters whose form does not depend on context.
    fn fixed_harmony(&self) -> Option<Harmony> {
        match (self.repeatable, self.presses) {
            (None, _) => letter_harmony(self.letter),
            (Some(Repeatable::A | Repeatable::O), 2) | (Some(Repeatable::I), 2 | 3) => {
                Some(Harmony::Front)
            }
            (Some(Repeatable::A | Repeatable::O), _) => Some(Harmony::Back),
            _ => None,
        }
    }

    /// Number of characters this unit renders as.
    fn width(&self) -> u8 {
        match (self.repeatable, self.presses) {
            (
                Some(Repeatable::A | Repeatable::I | Repeatable::O | Repeatable::N | Repeatable::H),
                3,
            )
            | (Some(Repeatable::K | Repeatable::G), 3 | 4) => 2,
            _ => 1,
        }
    }

    /// Writes the unit using its own resolved harmony (`ұ`/`ү`) and the
    /// harmony of its surroundings (`қ`/`к`, `ғ`/`г`).
    fn render_into(&self, output: &mut String, own: Harmony, context: Harmony) {
        let back = context == Harmony::Back;
        let (first, second) = match (self.repeatable, self.presses) {
            (Some(Repeatable::A), 2) => ('ә', None),
            (Some(Repeatable::I), 2) => ('і', None),
            (Some(Repeatable::I), 3) => ('и', Some('і')),
            (Some(Repeatable::O), 2) => ('ө', None),
            (Some(Repeatable::N), 2) => ('ң', None),
            (Some(Repeatable::H), 2) => ('һ', None),
            (Some(Repeatable::U), 2 | 3) => (if own == Harmony::Front { 'ү' } else { 'ұ' }, None),
            (Some(Repeatable::K), 1) => (if back { 'қ' } else { 'к' }, None),
            (Some(Repeatable::K), 3) => {
                let letter = if back { 'қ' } else { 'к' };
                (letter, Some(letter))
            }
            (Some(Repeatable::G), 1) => (if back { 'ғ' } else { 'г' }, None),
            (Some(Repeatable::G), 3) => {
                let letter = if back { 'ғ' } else { 'г' };
                (letter, Some(letter))
            }
            (
                Some(
                    Repeatable::A
                    | Repeatable::O
                    | Repeatable::N
                    | Repeatable::H
                    | Repeatable::K
                    | Repeatable::G,
                ),
                3 | 4,
            ) => (self.letter, Some(self.letter)),
            _ => (self.letter, None),
        };
        match second {
            Some(second) => {
                output.push(cased(first, self.upper_first));
                output.push(cased(second, self.upper_rest));
            }
            None => output.push(cased(first, self.upper_first || self.upper_rest)),
        }
    }
}

fn cased(letter: char, uppercase: bool) -> char {
    if uppercase {
        letter.to_uppercase().next().unwrap_or(letter)
    } else {
        letter
    }
}

/// Finds the nearest harmony before `index`, or after it when none precedes.
fn nearest(harmony: &[Option<Harmony>], index: usize) -> Option<Harmony> {
    harmony[..index]
        .iter()
        .rev()
        .find_map(|value| *value)
        .or_else(|| harmony[index + 1..].iter().find_map(|value| *value))
}

/// Common words that contain no vowel deciding their harmony.
///
/// When a word has no harmony evidence at all, the variant found here wins.
/// Pairs that are both real words (`тұр`/`түр`, `ұн`/`үн`) list only the
/// more common one; the other is reached with one more press of `у`.
const HARMONY_WORDS: &[&str] = &[
    "бұл", "ұл", "ұлт", "ұт", "ұр", "мұз", "мұң", "жұрт", "жұп", "жұт", "тұр", "тұз", "тұс", "сұр",
    "құс", "құл", "құм", "құр", "құрт", "құт", "бұт", "нұр", "үй", "үш", "үн", "жүр", "жүн", "жүз",
    "түн", "түп", "түс", "түй", "түк", "сүт", "сүй", "сүз", "күн", "күз", "күш", "күл", "күт",
    "күй", "гүл", "бүр", "үр",
];

/// The word currently being composed in Cyrillic mode.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct Word {
    units: Vec<Unit>,
}

impl Word {
    pub(crate) fn is_empty(&self) -> bool {
        self.units.is_empty()
    }

    pub(crate) fn clear(&mut self) {
        self.units.clear();
    }

    /// True when the last press was `й`, so a second `й` toggles the mode.
    pub(crate) fn ends_with_mode_key(&self) -> bool {
        self.units
            .last()
            .is_some_and(|unit| unit.letter == 'й' && !unit.from_auto_repeat)
    }

    pub(crate) fn remove_last(&mut self) {
        self.units.pop();
    }

    /// Adds one press of a lowercase Cyrillic letter.
    pub(crate) fn push(&mut self, letter: char, uppercase: bool, is_repeat: bool) {
        let repeatable = Repeatable::for_letter(letter);
        if let (Some(kind), Some(last)) = (repeatable, self.units.last_mut())
            && !is_repeat
            && !last.from_auto_repeat
            && last.repeatable == Some(kind)
            && last.presses < kind.max_presses()
        {
            last.presses += 1;
            last.upper_rest |= uppercase;
            return;
        }
        self.units.push(Unit {
            letter,
            repeatable,
            presses: 1,
            upper_first: uppercase,
            upper_rest: false,
            from_auto_repeat: is_repeat,
        });
    }

    /// Removes the last visible character.
    pub(crate) fn backspace(&mut self) {
        let Some(last) = self.units.last_mut() else {
            return;
        };
        if last.width() == 2 {
            last.presses -= 2;
            if last.presses == 1 {
                last.upper_rest = false;
            }
        } else {
            self.units.pop();
        }
    }

    /// Renders the word with every context-dependent letter resolved.
    pub(crate) fn render(&self) -> String {
        let fixed: Vec<_> = self.units.iter().map(Unit::fixed_harmony).collect();
        let fallback = if fixed.iter().any(Option::is_some) {
            Harmony::Back
        } else {
            self.dictionary_harmony(&fixed)
        };
        self.render_with(&fixed, fallback, true)
    }

    /// Looks the word up with explicit `ууу` flips ignored, so that a flip
    /// always turns the dictionary choice into the other letter.
    fn dictionary_harmony(&self, fixed: &[Option<Harmony>]) -> Harmony {
        let front = self
            .render_with(fixed, Harmony::Front, false)
            .to_lowercase();
        let back = self.render_with(fixed, Harmony::Back, false).to_lowercase();
        if front != back && HARMONY_WORDS.contains(&front.as_str()) {
            Harmony::Front
        } else {
            Harmony::Back
        }
    }

    fn render_with(&self, fixed: &[Option<Harmony>], fallback: Harmony, flip: bool) -> String {
        let mut harmony = fixed.to_vec();
        for (index, unit) in self.units.iter().enumerate() {
            if unit.repeatable == Some(Repeatable::U) && unit.presses >= 2 {
                let resolved = nearest(fixed, index).unwrap_or(fallback);
                harmony[index] = Some(if flip && unit.presses == 3 {
                    resolved.flipped()
                } else {
                    resolved
                });
            }
        }

        let mut output = String::new();
        for (index, unit) in self.units.iter().enumerate() {
            let context = nearest(&harmony, index).unwrap_or(fallback);
            let own = harmony[index].unwrap_or(fallback);
            unit.render_into(&mut output, own, context);
        }
        output
    }
}
