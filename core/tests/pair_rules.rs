mod common;

use common::{TextModel, engine, enter, expire, key};
use qazaqtype_core::{EngineAction, InputRules};

#[test]
fn all_double_rules_have_both_cases() {
    let rules = InputRules::new();
    let cases = [
        ('a', 'ә', 'Ә'),
        ('s', 'ш', 'Ш'),
        ('c', 'ч', 'Ч'),
        ('z', 'ж', 'Ж'),
        ('n', 'ң', 'Ң'),
        ('o', 'ө', 'Ө'),
        ('u', 'ү', 'Ү'),
        ('y', 'і', 'І'),
        ('g', 'ғ', 'Ғ'),
        ('e', 'э', 'Э'),
        (',', 'я', 'Я'),
        ('.', 'ю', 'Ю'),
        ('/', 'ь', 'Ь'),
    ];
    for (key, lower, upper) in cases {
        assert_eq!(rules.double(key, false), Some(lower), "lowercase {key}");
        assert_eq!(rules.double(key, true), Some(upper), "uppercase {key}");
    }
}

#[test]
fn fast_pair_replaces_and_commits_composition() {
    let mut engine = engine();
    assert_eq!(
        engine.handle_key(&key("s", 100)),
        vec![EngineAction::SetComposition("с".to_owned())]
    );
    assert_eq!(
        engine.handle_key(&key("s", 300)),
        vec![
            EngineAction::SetComposition("ш".to_owned()),
            EngineAction::CommitComposition
        ]
    );
    assert_eq!(engine.state().pending_key, None);
}

#[test]
fn uppercase_on_either_press_makes_uppercase_pair() {
    for uppercase_first in [false, true] {
        for uppercase_second in [false, true] {
            let mut engine = engine();
            let mut first = key("a", 0);
            first.shift = uppercase_first;
            let mut second = key("a", 100);
            second.shift = uppercase_second;
            engine.handle_key(&first);
            let actions = engine.handle_key(&second);
            let expected = if uppercase_first || uppercase_second {
                "Ә"
            } else {
                "ә"
            };
            assert_eq!(
                actions,
                vec![
                    EngineAction::SetComposition(expected.to_owned()),
                    EngineAction::CommitComposition
                ]
            );
        }
    }
}

#[test]
fn punctuation_pairs_work_and_shift_selects_uppercase() {
    let cases = [(",", "я"), (".", "ю"), ("/", "ь")];
    for (input, expected) in cases {
        let mut lowercase_engine = engine();
        let mut model = TextModel::default();
        enter(&mut lowercase_engine, &mut model, input, 0);
        enter(&mut lowercase_engine, &mut model, input, 100);
        assert_eq!(model.committed, expected);

        let mut uppercase_engine = engine();
        let mut first = key(input, 0);
        first.shift = true;
        uppercase_engine.handle_key(&first);
        let mut second = key(input, 100);
        second.shift = true;
        let actions = uppercase_engine.handle_key(&second);
        let uppercase_expected = match input {
            "," => "Я",
            "." => "Ю",
            "/" => "Ь",
            _ => unreachable!(),
        };
        assert_eq!(
            actions,
            vec![
                EngineAction::SetComposition(uppercase_expected.to_owned()),
                EngineAction::CommitComposition
            ]
        );
    }
}

#[test]
fn triples_match_from_left_to_right() {
    let cases = [("a", "әа"), ("s", "шс"), ("n", "ңн")];
    for (input, expected) in cases {
        let mut engine = engine();
        let mut model = TextModel::default();
        enter(&mut engine, &mut model, input, 0);
        enter(&mut engine, &mut model, input, 100);
        enter(&mut engine, &mut model, input, 200);
        expire(&mut engine, &mut model, 601);
        assert_eq!(model.committed, expected);
    }
}
