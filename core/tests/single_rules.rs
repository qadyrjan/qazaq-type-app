mod common;

use common::{CONTEXT, TextModel, engine, expire, key};
use qazaqtype_core::{EngineAction, InputRules};

#[test]
fn all_single_letter_rules_have_both_cases() {
    let rules = InputRules::new();
    let cases = [
        ('a', 'а', 'А'),
        ('b', 'б', 'Б'),
        ('c', 'ц', 'Ц'),
        ('d', 'д', 'Д'),
        ('e', 'е', 'Е'),
        ('f', 'ф', 'Ф'),
        ('g', 'г', 'Г'),
        ('h', 'х', 'Х'),
        ('i', 'и', 'И'),
        ('j', 'ж', 'Ж'),
        ('k', 'к', 'К'),
        ('l', 'л', 'Л'),
        ('m', 'м', 'М'),
        ('n', 'н', 'Н'),
        ('o', 'о', 'О'),
        ('p', 'п', 'П'),
        ('q', 'қ', 'Қ'),
        ('r', 'р', 'Р'),
        ('s', 'с', 'С'),
        ('t', 'т', 'Т'),
        ('u', 'у', 'У'),
        ('v', 'в', 'В'),
        ('w', 'ұ', 'Ұ'),
        ('x', 'х', 'Х'),
        ('y', 'ы', 'Ы'),
        ('z', 'з', 'З'),
    ];
    for (key, lower, upper) in cases {
        assert_eq!(rules.single(key, false), Some(lower), "lowercase {key}");
        assert_eq!(rules.single(key, true), Some(upper), "uppercase {key}");
    }
}

#[test]
fn shift_and_caps_lock_use_xor_for_letters() {
    let mut engine = engine();

    let mut shift = key("w", 0);
    shift.shift = true;
    assert_eq!(
        engine.handle_key(&shift),
        vec![EngineAction::CommitText("Ұ".to_owned())]
    );

    let mut caps = key("b", 10);
    caps.caps_lock = true;
    assert_eq!(
        engine.handle_key(&caps),
        vec![EngineAction::CommitText("Б".to_owned())]
    );

    let mut both = key("d", 20);
    both.shift = true;
    both.caps_lock = true;
    assert_eq!(
        engine.handle_key(&both),
        vec![EngineAction::CommitText("д".to_owned())]
    );
}

#[test]
fn pending_single_becomes_committed_after_timeout() {
    let mut engine = engine();
    let mut model = TextModel::default();
    model.apply(&engine.handle_key(&key("a", 0)));
    assert_eq!(model.visible_text(), "а");
    expire(&mut engine, &mut model, 401);
    assert_eq!(model.committed, "а");
    assert_eq!(model.composition, None);
    assert_eq!(engine.state().context_id, None);
    let _ = CONTEXT;
}
