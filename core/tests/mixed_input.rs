mod common;

use common::{TextModel, engine, enter, expire, key};
use qazaqtype_core::{EngineAction, EngineConfig, InputMode};

#[test]
fn qazaq_example_converts_as_documented() {
    let mut engine = engine();
    let mut model = TextModel::default();
    for (index, input) in ["q", "a", "z", "a", "q"].into_iter().enumerate() {
        enter(&mut engine, &mut model, input, index as u64 * 500);
    }
    expire(&mut engine, &mut model, 2401);
    assert_eq!(model.committed, "қазақ");
}

#[test]
fn auto_repeat_is_never_a_double_press() {
    let mut engine = engine();
    let mut model = TextModel::default();
    enter(&mut engine, &mut model, "s", 0);
    for timestamp in [50, 100, 150, 200, 250] {
        let mut repeated = key("s", timestamp);
        repeated.is_repeat = true;
        model.apply(&engine.handle_key(&repeated));
    }
    assert_eq!(model.committed, "сссссс");
    assert!(!model.committed.contains('ш'));
}

#[test]
fn unrelated_key_commits_pending_before_new_text() {
    let mut engine = engine();
    assert_eq!(
        engine.handle_key(&key("a", 0)),
        vec![EngineAction::SetComposition("а".to_owned())]
    );
    assert_eq!(
        engine.handle_key(&key("b", 100)),
        vec![
            EngineAction::CommitComposition,
            EngineAction::CommitText("б".to_owned())
        ]
    );
}

#[test]
fn invalid_threshold_is_rejected() {
    for threshold in [0, 199, 801, 10_000] {
        let config = EngineConfig {
            double_press_threshold_ms: threshold,
            ..EngineConfig::default()
        };
        assert!(qazaqtype_core::Engine::new(config).is_err());
    }
}

#[test]
fn disabled_engine_forwards_everything() {
    let config = EngineConfig {
        enabled: false,
        default_mode: InputMode::Kazakh,
        double_press_threshold_ms: 400,
    };
    let mut engine = qazaqtype_core::Engine::new(config).unwrap();
    assert_eq!(
        engine.handle_key(&key("a", 0)),
        vec![EngineAction::ForwardKey]
    );
}
