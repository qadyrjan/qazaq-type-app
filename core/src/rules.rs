#[derive(Debug, Clone, Copy, Default)]
pub struct InputRules;

impl InputRules {
    #[must_use]
    pub const fn new() -> Self {
        Self
    }

    #[must_use]
    pub fn single(self, key: char, uppercase: bool) -> Option<char> {
        let (lower, upper) = match key.to_ascii_lowercase() {
            'a' => ('а', 'А'),
            'b' => ('б', 'Б'),
            'c' => ('ц', 'Ц'),
            'd' => ('д', 'Д'),
            'e' => ('е', 'Е'),
            'f' => ('ф', 'Ф'),
            'g' => ('г', 'Г'),
            'h' | 'x' => ('х', 'Х'),
            'i' => ('и', 'И'),
            'j' => ('ж', 'Ж'),
            'k' => ('к', 'К'),
            'l' => ('л', 'Л'),
            'm' => ('м', 'М'),
            'n' => ('н', 'Н'),
            'o' => ('о', 'О'),
            'p' => ('п', 'П'),
            'q' => ('қ', 'Қ'),
            'r' => ('р', 'Р'),
            's' => ('с', 'С'),
            't' => ('т', 'Т'),
            'u' => ('у', 'У'),
            'v' => ('в', 'В'),
            'w' => ('ұ', 'Ұ'),
            'y' => ('ы', 'Ы'),
            'z' => ('з', 'З'),
            _ => return None,
        };
        Some(if uppercase { upper } else { lower })
    }

    #[must_use]
    pub fn double(self, key: char, uppercase: bool) -> Option<char> {
        let (lower, upper) = match key.to_ascii_lowercase() {
            'a' => ('ә', 'Ә'),
            's' => ('ш', 'Ш'),
            'c' => ('ч', 'Ч'),
            'z' => ('ж', 'Ж'),
            'n' => ('ң', 'Ң'),
            'o' => ('ө', 'Ө'),
            'u' => ('ү', 'Ү'),
            'y' => ('і', 'І'),
            'g' => ('ғ', 'Ғ'),
            'e' => ('э', 'Э'),
            ',' => ('я', 'Я'),
            '.' => ('ю', 'Ю'),
            '/' => ('ь', 'Ь'),
            _ => return None,
        };
        Some(if uppercase { upper } else { lower })
    }

    #[must_use]
    pub fn can_start_double(self, key: char) -> bool {
        key.eq_ignore_ascii_case(&'q') || self.double(key, false).is_some()
    }
}
