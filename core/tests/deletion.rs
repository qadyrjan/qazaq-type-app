mod common;

use common::{CONTEXT, engine, key};
use qazaqtype_core::{ContextEvent, EngineAction, SpecialKey};

#[test]
fn backspace_clears_pending_composition_and_is_consumed() {
    let mut engine = engine();
    engine.handle_key(&key("a", 0));
    assert_eq!(
        engine.handle_special_key(SpecialKey::Backspace, CONTEXT),
        vec![EngineAction::ClearComposition]
    );
    assert_eq!(engine.state().pending_key, None);
}

#[test]
fn backspace_without_composition_is_forwarded() {
    let mut engine = engine();
    assert_eq!(
        engine.handle_special_key(SpecialKey::Backspace, CONTEXT),
        vec![EngineAction::ForwardKey]
    );
}

#[test]
fn escape_cancels_pending_composition() {
    let mut engine = engine();
    engine.handle_key(&key("s", 0));
    assert_eq!(
        engine.handle_special_key(SpecialKey::Escape, CONTEXT),
        vec![EngineAction::ClearComposition]
    );
}

#[test]
fn cursor_keys_commit_before_forwarding() {
    for special in [
        SpecialKey::Space,
        SpecialKey::Enter,
        SpecialKey::Tab,
        SpecialKey::Delete,
        SpecialKey::Arrow,
        SpecialKey::Home,
        SpecialKey::End,
        SpecialKey::PageUp,
        SpecialKey::PageDown,
    ] {
        let mut engine = engine();
        engine.handle_key(&key("a", 0));
        assert_eq!(
            engine.handle_special_key(special, CONTEXT),
            vec![EngineAction::CommitComposition, EngineAction::ForwardKey],
            "{special:?}"
        );
    }
}

#[test]
fn lifecycle_events_never_leave_pending_state() {
    for event in [
        ContextEvent::CursorMoved,
        ContextEvent::FocusLost,
        ContextEvent::InputMethodDeactivated,
        ContextEvent::ContextDestroyed,
        ContextEvent::CompositionCancelled,
    ] {
        let mut engine = engine();
        engine.handle_key(&key("a", 0));
        let actions = engine.handle_context_event(event);
        assert!(!actions.is_empty(), "{event:?}");
        assert_eq!(engine.state().pending_key, None, "{event:?}");
    }
}

#[test]
fn new_context_cancels_old_composition_before_processing() {
    let mut engine = engine();
    engine.handle_key(&key("a", 0));
    let mut other = key("b", 100);
    other.context_id = 99;
    assert_eq!(
        engine.handle_key(&other),
        vec![
            EngineAction::ClearComposition,
            EngineAction::CommitText("б".to_owned())
        ]
    );
}
