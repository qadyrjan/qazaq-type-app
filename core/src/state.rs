use crate::cyrillic::Word;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputMode {
    Kazakh,
    English,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KeyEvent {
    /// Physical printable key represented by its unmodified ASCII value.
    pub key: String,
    /// Timestamp from a monotonic clock.
    pub timestamp_ms: u64,
    pub shift: bool,
    pub caps_lock: bool,
    pub is_repeat: bool,
    pub context_id: u64,
}

impl KeyEvent {
    #[must_use]
    pub fn new(key: impl Into<String>, timestamp_ms: u64, context_id: u64) -> Self {
        Self {
            key: key.into(),
            timestamp_ms,
            shift: false,
            caps_lock: false,
            is_repeat: false,
            context_id,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpecialKey {
    Space,
    Enter,
    Tab,
    Backspace,
    Delete,
    Escape,
    Arrow,
    Home,
    End,
    PageUp,
    PageDown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContextEvent {
    CursorMoved,
    FocusLost,
    InputMethodDeactivated,
    ContextDestroyed,
    CompositionCancelled,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EngineAction {
    SetComposition(String),
    CommitComposition,
    CommitText(String),
    ClearComposition,
    SwitchMode(InputMode),
    ForwardKey,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EngineState {
    pub mode: InputMode,
    pub pending_key: Option<char>,
    pub pending_since_ms: Option<u64>,
    pub composition: Option<String>,
    pub context_id: Option<u64>,
    pub(crate) pending_uppercase: bool,
    /// Whether the pending Latin key was pressed at the start of a word.
    pub(crate) pending_at_word_start: bool,
    /// Whether the next printable key starts a new word.
    pub(crate) at_word_start: bool,
    /// The word being composed in Cyrillic mode.
    pub(crate) word: Word,
}

impl EngineState {
    #[must_use]
    pub fn new(mode: InputMode) -> Self {
        Self {
            mode,
            pending_key: None,
            pending_since_ms: None,
            composition: None,
            context_id: None,
            pending_uppercase: false,
            pending_at_word_start: false,
            at_word_start: true,
            word: Word::default(),
        }
    }

    /// Whether any composition (Latin pending key or Cyrillic word) is open.
    #[must_use]
    pub fn has_composition(&self) -> bool {
        self.pending_key.is_some() || !self.word.is_empty()
    }

    pub(crate) fn clear_pending(&mut self) {
        self.pending_key = None;
        self.pending_since_ms = None;
        self.composition = None;
        self.context_id = None;
        self.pending_uppercase = false;
        self.pending_at_word_start = false;
        self.word.clear();
    }
}
