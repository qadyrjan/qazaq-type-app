use qazaqtype_core::{Engine, EngineAction, EngineConfig, InputMode, KeyEvent};

#[test]
fn updating_config_clears_pending_composition() {
    let mut engine = Engine::new(EngineConfig::default()).unwrap();
    engine.handle_key(&KeyEvent::new("a", 0, 1));
    let updated = EngineConfig {
        double_press_threshold_ms: 600,
        ..EngineConfig::default()
    };
    assert_eq!(
        engine.update_config(updated).unwrap(),
        vec![EngineAction::ClearComposition]
    );
    assert_eq!(engine.config(), updated);
}

#[test]
fn explicit_mode_change_clears_pending_text() {
    let mut engine = Engine::new(EngineConfig::default()).unwrap();
    engine.handle_key(&KeyEvent::new("q", 0, 1));
    assert_eq!(
        engine.set_mode(InputMode::English),
        vec![
            EngineAction::ClearComposition,
            EngineAction::SwitchMode(InputMode::English)
        ]
    );
}
