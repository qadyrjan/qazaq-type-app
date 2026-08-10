mod common;

use common::{CONTEXT, TextModel, engine, enter, expire, key};
use qazaqtype_core::{EngineAction, InputMode};

#[test]
fn fast_qq_switches_without_committing_characters() {
    let mut engine = engine();
    let mut model = TextModel::default();
    enter(&mut engine, &mut model, "q", 0);
    let actions = engine.handle_key(&key("q", 100));
    model.apply(&actions);
    assert_eq!(
        actions,
        vec![
            EngineAction::ClearComposition,
            EngineAction::SwitchMode(InputMode::English)
        ]
    );
    assert_eq!(model.visible_text(), "");
    assert_eq!(engine.state().mode, InputMode::English);
}

#[test]
fn fast_qq_switches_back_from_english() {
    let mut engine = engine();
    engine.set_mode(InputMode::English);
    engine.handle_key(&key("q", 0));
    assert_eq!(
        engine.handle_key(&key("q", 100)),
        vec![
            EngineAction::ClearComposition,
            EngineAction::SwitchMode(InputMode::Kazakh)
        ]
    );
}

#[test]
fn slow_qq_is_text_in_both_modes() {
    let mut kz = engine();
    let mut kz_text = TextModel::default();
    enter(&mut kz, &mut kz_text, "q", 0);
    enter(&mut kz, &mut kz_text, "q", 600);
    expire(&mut kz, &mut kz_text, 1001);
    assert_eq!(kz_text.committed, "ққ");

    let mut en = engine();
    en.set_mode(InputMode::English);
    let mut en_text = TextModel::default();
    enter(&mut en, &mut en_text, "q", 0);
    enter(&mut en, &mut en_text, "q", 600);
    expire(&mut en, &mut en_text, 1001);
    assert_eq!(en_text.committed, "qq");
}

#[test]
fn rapid_qqq_handles_third_key_in_new_mode() {
    let mut engine = engine();
    let mut model = TextModel::default();
    enter(&mut engine, &mut model, "q", 0);
    enter(&mut engine, &mut model, "q", 100);
    enter(&mut engine, &mut model, "q", 200);
    expire(&mut engine, &mut model, 601);
    assert_eq!(engine.state().mode, InputMode::English);
    assert_eq!(model.committed, "q");
    let _ = CONTEXT;
}

#[test]
fn english_mode_forwards_non_q_keys_unchanged() {
    let mut engine = engine();
    engine.set_mode(InputMode::English);
    for (index, input) in ["Q", "a", "z", "a", "q", "T", "y", "p", "e"]
        .into_iter()
        .enumerate()
    {
        let actions = engine.handle_key(&key(input, index as u64 * 500));
        if input.eq_ignore_ascii_case("q") {
            assert!(matches!(
                actions.last(),
                Some(EngineAction::SetComposition(_))
            ));
            engine.handle_timeout(index as u64 * 500 + 401, CONTEXT);
        } else {
            assert_eq!(actions.last(), Some(&EngineAction::ForwardKey));
        }
    }
}
