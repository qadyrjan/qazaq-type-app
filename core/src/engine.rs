use crate::case::effective_uppercase;
use crate::{
    ConfigError, ContextEvent, EngineAction, EngineConfig, EngineState, InputMode, InputRules,
    KeyEvent, SpecialKey,
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
            actions.push(EngineAction::ForwardKey);
            return actions;
        };
        let uppercase = effective_uppercase(key, event.shift, event.caps_lock);

        if event.is_repeat {
            self.commit_pending(&mut actions);
            self.process_single(key, uppercase, event, false, &mut actions);
            return actions;
        }

        if self.pending_expired(event.timestamp_ms) {
            self.commit_pending(&mut actions);
        }

        if let (Some(pending_key), Some(pending_since)) =
            (self.state.pending_key, self.state.pending_since_ms)
        {
            let elapsed = event.timestamp_ms.checked_sub(pending_since);
            let is_fast_match = elapsed
                .is_some_and(|value| value <= self.config.double_press_threshold_ms)
                && pending_key == key;

            if is_fast_match && key == 'q' {
                self.state.clear_pending();
                actions.push(EngineAction::ClearComposition);
                self.state.mode = match self.state.mode {
                    InputMode::Kazakh => InputMode::English,
                    InputMode::English => InputMode::Kazakh,
                };
                actions.push(EngineAction::SwitchMode(self.state.mode));
                return actions;
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
                return actions;
            }

            self.commit_pending(&mut actions);
        }

        self.process_single(key, uppercase, event, true, &mut actions);
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
        if self.state.pending_key.is_none() {
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
        if self.state.pending_key.is_some() {
            self.state.clear_pending();
            actions.push(EngineAction::ClearComposition);
        }
        if self.state.mode != mode {
            self.state.mode = mode;
            actions.push(EngineAction::SwitchMode(mode));
        }
        actions
    }

    /// Replaces the runtime configuration after validating it.
    ///
    /// Any pending composition is cancelled so that the old timing policy
    /// cannot leak into the new configuration.
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
        if self.state.pending_key.is_some() {
            self.state.clear_pending();
            actions.push(EngineAction::ClearComposition);
        }
        self.config = config;
        Ok(actions)
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
        if self.state.pending_key.is_some() {
            actions.push(EngineAction::CommitComposition);
            self.state.clear_pending();
        }
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
