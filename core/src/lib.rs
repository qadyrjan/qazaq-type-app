//! Platform-independent conversion engine for `QazaqType`.

mod case;
mod config;
mod cyrillic;
mod engine;
mod rules;
mod state;

pub use config::{ConfigError, EngineConfig, KeyboardLayout};
pub use engine::Engine;
pub use rules::InputRules;
pub use state::{ContextEvent, EngineAction, EngineState, InputMode, KeyEvent, SpecialKey};
