#![allow(dead_code)]

use qazaqtype_core::{Engine, EngineAction, EngineConfig, KeyEvent};

pub const CONTEXT: u64 = 7;

pub fn engine() -> Engine {
    Engine::new(EngineConfig::default()).expect("default config must be valid")
}

pub fn key(value: &str, timestamp_ms: u64) -> KeyEvent {
    KeyEvent::new(value, timestamp_ms, CONTEXT)
}

#[derive(Debug, Default)]
pub struct TextModel {
    pub committed: String,
    pub composition: Option<String>,
}

impl TextModel {
    pub fn apply(&mut self, actions: &[EngineAction]) {
        for action in actions {
            match action {
                EngineAction::SetComposition(value) => self.composition = Some(value.clone()),
                EngineAction::CommitComposition => {
                    if let Some(value) = self.composition.take() {
                        self.committed.push_str(&value);
                    }
                }
                EngineAction::CommitText(value) => self.committed.push_str(value),
                EngineAction::ClearComposition => self.composition = None,
                EngineAction::SwitchMode(_) | EngineAction::ForwardKey => {}
            }
        }
    }

    pub fn visible_text(&self) -> String {
        format!(
            "{}{}",
            self.committed,
            self.composition.as_deref().unwrap_or_default()
        )
    }
}

pub fn enter(engine: &mut Engine, model: &mut TextModel, value: &str, timestamp_ms: u64) {
    let actions = engine.handle_key(&key(value, timestamp_ms));
    model.apply(&actions);
}

pub fn expire(engine: &mut Engine, model: &mut TextModel, now_ms: u64) {
    let actions = engine.handle_timeout(now_ms, CONTEXT);
    model.apply(&actions);
}
