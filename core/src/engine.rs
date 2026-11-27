use crate::case::effective_uppercase;
use crate::cyrillic::{CyrillicKey, cyrillic_key};
use crate::{
    ConfigError, ContextEvent, EngineAction, EngineConfig, EngineState, InputMode, InputRules,
    KeyEvent, KeyboardLayout, SpecialKey,
};

#[derive(Debug, Clone)]
pub struct Engine {
    config: EngineConfig,
    rules: InputRules,
    state: EngineState,
}

impl Engine {
    /// Creates an engine with validated configuration.
    ///
    /// # Errors
    ///
    /// Returns [`ConfigError`] when `config` contains an unsupported value.
    pub fn new(config: EngineConfig) -> Result<Self, ConfigError> {
        let config = config.validate()?;
        Ok(Self {
            config,
            rules: InputRules::new(),
            state: EngineState::new(config.default_mode),
        })
    }

    #[must_use]
    pub const fn state(&self) -> &EngineState {
        &self.state
    }

    #[must_use]
    pub const fn config(&self) -> EngineConfig {
        self.config
    }

    pub fn handle_key(&mut self, event: &KeyEvent) -> Vec<EngineAction> {
        let mut actions = Vec::new();
        self.clear_stale_context(event.context_id, &mut actions);

        if !self.config.enabled {
            actions.push(EngineAction::ForwardKey);
            return actions;
        }

        let Some(key) = normalized_key(&event.key) else {
            self.commit_pending(&mut actions);
            self.state.at_word_start = true;
            actions.push(EngineAction::ForwardKey);
            return actions;
        };

        if self.config.layout == KeyboardLayout::Cyrillic && self.state.mode == InputMode::Kazakh {
            self.handle_cyrillic_key(key, event, &mut actions);
        } else {
            self.handle_latin_key(key, event, &mut actions);
        }
        actions
    }

    pub fn handle_timeout(&mut self, now_ms: u64, context_id: u64) -> Vec<EngineAction> {
        if self.state.context_id != Some(context_id) {
            return Vec::new();
        }
        if self.pending_expired(now_ms) {
            let mut actions = Vec::new();
            self.commit_pending(&mut actions);
            return actions;
        }
        Vec::new()
    }

    pub fn handle_special_key(&mut self, key: SpecialKey, context_id: u64) -> Vec<EngineAction> {
        let mut actions = Vec::new();
        self.clear_stale_context(context_id, &mut actions);
        if !matches!(key, SpecialKey::Backspace | SpecialKey::Delete) {
            self.state.at_word_start = true;
        }

        if !self.state.word.is_empty() {
            if key == SpecialKey::Backspace {
                self.state.word.backspace();
                self.show_word(&mut actions);
            } else {
                self.commit_pending(&mut actions);
                actions.push(EngineAction::ForwardKey);
            }
            return actions;
        }

        match (key, self.state.pending_key.is_some()) {
            (SpecialKey::Backspace | SpecialKey::Escape, true) => {
                self.state.clear_pending();
                actions.push(EngineAction::ClearComposition);
            }
            (_, true) => {
                self.commit_pending(&mut actions);
                actions.push(EngineAction::ForwardKey);
            }
            (_, false) => actions.push(EngineAction::ForwardKey),
        }
        actions
    }

    pub fn handle_context_event(&mut self, event: ContextEvent) -> Vec<EngineAction> {
        self.state.at_word_start = true;
        if !self.state.has_composition() {
            return Vec::new();
        }
        match event {
            ContextEvent::CursorMoved
            | ContextEvent::FocusLost
            | ContextEvent::InputMethodDeactivated => {
                let mut actions = Vec::new();
                self.commit_pending(&mut actions);
                actions
            }
            ContextEvent::ContextDestroyed | ContextEvent::CompositionCancelled => {
                self.state.clear_pending();
                vec![EngineAction::ClearComposition]
            }
        }
    }

    pub fn set_mode(&mut self, mode: InputMode) -> Vec<EngineAction> {
        let mut actions = Vec::new();
        self.end_pending_for_change(&mut actions);
        if self.state.mode != mode {
            self.state.mode = mode;
            actions.push(EngineAction::SwitchMode(mode));
        }
        actions
    }

    /// Replaces the runtime configuration after validating it.
    ///
    /// A pending Latin key is cancelled so that the old timing policy cannot
    /// leak into the new configuration. A composed Cyrillic word is already
    /// fully resolved, so it is committed instead of being lost.
    ///
    /// # Errors
    ///
    /// Returns [`ConfigError`] when `config` contains an unsupported value.
    pub fn update_config(
        &mut self,
        config: EngineConfig,
    ) -> Result<Vec<EngineAction>, ConfigError> {
        let config = config.validate()?;
        let mut actions = Vec::new();
        self.end_pending_for_change(&mut actions);
        self.config = config;
        Ok(actions)
    }

    fn handle_cyrillic_key(
        &mut self,
        key: char,
        event: &KeyEvent,
        actions: &mut Vec<EngineAction>,
    ) {
        match cyrillic_key(key, event.shift) {
            Some(CyrillicKey::Letter('й'))
                if !event.is_repeat && self.state.word.ends_with_mode_key() =>
            {
                self.state.word.remove_last();
                self.show_word(actions);
                self.commit_pending(actions);
                self.toggle_mode(actions);
            }
            Some(CyrillicKey::Letter(letter)) => {
                if self.state.word.is_empty() {
                    self.state.context_id = Some(event.context_id);
                }
                let uppercase = event.shift ^ event.caps_lock;
                self.state.word.push(letter, uppercase, event.is_repeat);
                self.show_word(actions);
                self.state.at_word_start = false;
            }
            Some(CyrillicKey::Symbol(symbol)) => {
                self.commit_pending(actions);
                actions.push(EngineAction::CommitText(symbol.to_string()));
                self.state.at_word_start = true;
            }
            None => {
                self.commit_pending(actions);
                actions.push(EngineAction::ForwardKey);
                self.state.at_word_start = true;
            }
        }
    }

    /// Replaces the composition with the current Cyrillic word.
    fn show_word(&mut self, actions: &mut Vec<EngineAction>) {
        if self.state.word.is_empty() {
            self.state.clear_pending();
            actions.push(EngineAction::ClearComposition);
        } else {
            let text = self.state.word.render();
            self.state.composition = Some(text.clone());
            actions.push(EngineAction::SetComposition(text));
        }
    }

    fn handle_latin_key(&mut self, key: char, event: &KeyEvent, actions: &mut Vec<EngineAction>) {
        let uppercase = effective_uppercase(key, event.shift, event.caps_lock);

        if event.is_repeat {
            self.commit_pending(actions);
            self.process_single(key, uppercase, event, false, actions);
            self.state.at_word_start = !key.is_ascii_alphabetic();
            return;
        }

        if self.pending_expired(event.timestamp_ms) {
            self.commit_pending(actions);
        }

        if let (Some(pending_key), Some(pending_since)) =
            (self.state.pending_key, self.state.pending_since_ms)
        {
            let elapsed = event.timestamp_ms.checked_sub(pending_since);
            let is_fast_match = elapsed
                .is_some_and(|value| value <= self.config.double_press_threshold_ms)
                && pending_key == key;

            if is_fast_match && key == 'q' {
                if self.state.mode == InputMode::English || self.state.pending_at_word_start {
                    self.state.clear_pending();
                    actions.push(EngineAction::ClearComposition);
                    self.toggle_mode(actions);
                    return;
                }
                // Inside a Kazakh word a fast `qq` is the common `ққ`
                // (халыққа, шыққан), never a mode switch.
                let pending_uppercase = self.state.pending_uppercase;
                if let (Some(first), Some(second)) = (
                    self.rules.single(key, pending_uppercase),
                    self.rules.single(key, uppercase),
                ) {
                    let text = format!("{first}{second}");
                    self.state.composition = Some(text.clone());
                    actions.push(EngineAction::SetComposition(text));
                    actions.push(EngineAction::CommitComposition);
                    self.state.clear_pending();
                    self.state.at_word_start = false;
                    return;
                }
            }

            if is_fast_match
                && self.state.mode == InputMode::Kazakh
                && let Some(output) = self
                    .rules
                    .double(key, self.state.pending_uppercase || uppercase)
            {
                self.state.composition = Some(output.to_string());
                actions.push(EngineAction::SetComposition(output.to_string()));
                actions.push(EngineAction::CommitComposition);
                self.state.clear_pending();
                self.state.at_word_start = !key.is_ascii_alphabetic();
                return;
            }

            self.commit_pending(actions);
        }

        self.process_single(key, uppercase, event, true, actions);
        self.state.at_word_start = !key.is_ascii_alphabetic();
    }

    fn toggle_mode(&mut self, actions: &mut Vec<EngineAction>) {
        self.state.mode = match self.state.mode {
            InputMode::Kazakh => InputMode::English,
            InputMode::English => InputMode::Kazakh,
        };
        self.state.at_word_start = true;
        actions.push(EngineAction::SwitchMode(self.state.mode));
    }

    fn process_single(
        &mut self,
        key: char,
        uppercase: bool,
        event: &KeyEvent,
        allow_pending: bool,
        actions: &mut Vec<EngineAction>,
    ) {
        match self.state.mode {
            InputMode::English => {
                if allow_pending && key == 'q' {
                    let composition = if uppercase { "Q" } else { "q" };
                    self.set_pending(key, uppercase, composition.to_owned(), event, actions);
                } else {
                    actions.push(EngineAction::ForwardKey);
                }
            }
            InputMode::Kazakh => {
                if let Some(output) = self.rules.single(key, uppercase) {
                    if allow_pending && self.rules.can_start_double(key) {
                        self.set_pending(key, uppercase, output.to_string(), event, actions);
                    } else {
                        actions.push(EngineAction::CommitText(output.to_string()));
                    }
                } else if allow_pending && self.rules.double(key, uppercase).is_some() {
                    self.set_pending(key, uppercase, key.to_string(), event, actions);
                } else {
                    actions.push(EngineAction::ForwardKey);
                }
            }
        }
    }

    fn set_pending(
        &mut self,
        key: char,
        uppercase: bool,
        composition: String,
        event: &KeyEvent,
        actions: &mut Vec<EngineAction>,
    ) {
        self.state.pending_key = Some(key);
        self.state.pending_since_ms = Some(event.timestamp_ms);
        self.state.composition = Some(composition.clone());
        self.state.context_id = Some(event.context_id);
        self.state.pending_uppercase = uppercase;
        self.state.pending_at_word_start = self.state.at_word_start;
        actions.push(EngineAction::SetComposition(composition));
    }

    fn pending_expired(&self, now_ms: u64) -> bool {
        self.state.pending_since_ms.is_some_and(|since| {
            now_ms
                .checked_sub(since)
                .is_none_or(|elapsed| elapsed > self.config.double_press_threshold_ms)
        })
    }

    fn commit_pending(&mut self, actions: &mut Vec<EngineAction>) {
        if self.state.has_composition() {
            actions.push(EngineAction::CommitComposition);
            self.state.clear_pending();
        }
    }

    /// Ends composition before a mode or configuration change.
    fn end_pending_for_change(&mut self, actions: &mut Vec<EngineAction>) {
        if !self.state.word.is_empty() {
            self.commit_pending(actions);
        } else if self.state.pending_key.is_some() {
            self.state.clear_pending();
            actions.push(EngineAction::ClearComposition);
        }
        self.state.at_word_start = true;
    }

    fn clear_stale_context(&mut self, context_id: u64, actions: &mut Vec<EngineAction>) {
        if self.state.context_id.is_some_and(|id| id != context_id) {
            self.state.clear_pending();
            actions.push(EngineAction::ClearComposition);
        }
    }
}

fn normalized_key(key: &str) -> Option<char> {
    let mut chars = key.chars();
    let key = chars.next()?;
    if chars.next().is_some() || !key.is_ascii() {
        return None;
    }
    Some(key.to_ascii_lowercase())
}
