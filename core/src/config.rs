use crate::InputMode;

pub const MIN_DOUBLE_PRESS_THRESHOLD_MS: u64 = 200;
pub const MAX_DOUBLE_PRESS_THRESHOLD_MS: u64 = 800;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EngineConfig {
    pub enabled: bool,
    pub default_mode: InputMode,
    pub double_press_threshold_ms: u64,
}

impl Default for EngineConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            default_mode: InputMode::Kazakh,
            double_press_threshold_ms: 400,
        }
    }
}

impl EngineConfig {
    /// Validates the user-controlled configuration.
    ///
    /// # Errors
    ///
    /// Returns [`ConfigError`] when the double-press threshold is outside the
    /// supported inclusive range.
    pub fn validate(self) -> Result<Self, ConfigError> {
        if !(MIN_DOUBLE_PRESS_THRESHOLD_MS..=MAX_DOUBLE_PRESS_THRESHOLD_MS)
            .contains(&self.double_press_threshold_ms)
        {
            return Err(ConfigError::DoublePressThresholdOutOfRange {
                value: self.double_press_threshold_ms,
                min: MIN_DOUBLE_PRESS_THRESHOLD_MS,
                max: MAX_DOUBLE_PRESS_THRESHOLD_MS,
            });
        }
        Ok(self)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConfigError {
    DoublePressThresholdOutOfRange { value: u64, min: u64, max: u64 },
}

impl std::fmt::Display for ConfigError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::DoublePressThresholdOutOfRange { value, min, max } => {
                write!(
                    formatter,
                    "double-press threshold {value}ms is outside {min}ms..={max}ms"
                )
            }
        }
    }
}

impl std::error::Error for ConfigError {}
