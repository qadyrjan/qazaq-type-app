mod common;

use common::{TextModel, engine, enter, expire};

#[test]
fn threshold_is_inclusive_for_key_events() {
    let mut engine = engine();
    let mut model = TextModel::default();
    enter(&mut engine, &mut model, "s", 0);
    enter(&mut engine, &mut model, "s", 400);
    assert_eq!(model.committed, "ш");
}

#[test]
fn timeout_does_not_win_at_exact_boundary() {
    let mut engine = engine();
    let mut model = TextModel::default();
    enter(&mut engine, &mut model, "s", 0);
    expire(&mut engine, &mut model, 400);
    assert_eq!(model.composition.as_deref(), Some("с"));
    enter(&mut engine, &mut model, "s", 400);
    assert_eq!(model.committed, "ш");
}

#[test]
fn one_millisecond_over_threshold_is_slow() {
    let mut engine = engine();
    let mut model = TextModel::default();
    enter(&mut engine, &mut model, "s", 0);
    enter(&mut engine, &mut model, "s", 401);
    expire(&mut engine, &mut model, 802);
    assert_eq!(model.committed, "сс");
}

#[test]
fn backwards_timestamp_cannot_match() {
    let mut engine = engine();
    let mut model = TextModel::default();
    enter(&mut engine, &mut model, "a", 100);
    enter(&mut engine, &mut model, "a", 99);
    expire(&mut engine, &mut model, 500);
    assert_eq!(model.committed, "аа");
}
