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
}

impl EngineState {
    #[must_use]
    pub const fn new(mode: InputMode) -> Self {
        Self {
            mode,
            pending_key: None,
            pending_since_ms: None,
            composition: None,
            context_id: None,
            pending_uppercase: false,
        }
    }

    pub(crate) fn clear_pending(&mut self) {
        self.pending_key = None;
        self.pending_since_ms = None;
        self.composition = None;
        self.context_id = None;
        self.pending_uppercase = false;
    }
}
