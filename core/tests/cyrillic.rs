mod common;

use common::{CONTEXT, TextModel};
use qazaqtype_core::{
    ContextEvent, Engine, EngineAction, EngineConfig, InputMode, KeyEvent, KeyboardLayout,
    SpecialKey,
};

const RUSSIAN_KEYS: &[(char, &str)] = &[
    ('ё', "`"),
    ('й', "q"),
    ('ц', "w"),
    ('у', "e"),
    ('к', "r"),
    ('е', "t"),
    ('н', "y"),
    ('г', "u"),
    ('ш', "i"),
    ('щ', "o"),
    ('з', "p"),
    ('х', "["),
    ('ъ', "]"),
    ('ф', "a"),
    ('ы', "s"),
    ('в', "d"),
    ('а', "f"),
    ('п', "g"),
    ('р', "h"),
    ('о', "j"),
    ('л', "k"),
    ('д', "l"),
    ('ж', ";"),
    ('э', "'"),
    ('я', "z"),
    ('ч', "x"),
    ('с', "c"),
    ('м', "v"),
    ('и', "b"),
    ('т', "n"),
    ('ь', "m"),
    ('б', ","),
    ('ю', "."),
];

fn cyrillic_engine() -> Engine {
    Engine::new(EngineConfig {
        layout: KeyboardLayout::Cyrillic,
        ..EngineConfig::default()
    })
    .unwrap()
}

fn press(letter: char) -> KeyEvent {
    let lower = letter.to_lowercase().next().unwrap();
    let (_, key) = RUSSIAN_KEYS
        .iter()
        .find(|(cyrillic, _)| *cyrillic == lower)
        .unwrap_or_else(|| panic!("no Russian key for {letter}"));
    let mut event = KeyEvent::new(*key, 0, CONTEXT);
    event.shift = letter != lower;
    event
}

/// Types Russian keyboard letters; a space is the Space key and `<` is
/// Backspace. Returns the committed text followed by any open composition.
fn type_keys(engine: &mut Engine, keys: &str) -> String {
    let mut model = TextModel::default();
    for (index, letter) in keys.chars().enumerate() {
        let actions = match letter {
            ' ' => {
                // Space commits the word, then the forwarded key inserts it.
                model.apply(&engine.handle_special_key(SpecialKey::Space, CONTEXT));
                model.committed.push(' ');
                continue;
            }
            '<' => engine.handle_special_key(SpecialKey::Backspace, CONTEXT),
            _ => {
                let mut event = press(letter);
                event.timestamp_ms = index as u64 * 50;
                engine.handle_key(&event)
            }
        };
        model.apply(&actions);
    }
    model.visible_text()
}

fn typed(keys: &str) -> String {
    type_keys(&mut cyrillic_engine(), keys)
}

#[test]
fn russian_letters_stay_in_place() {
    assert_eq!(typed("привет мир "), "привет мир ");
    assert_eq!(typed("съешь щей ёж "), "съешь щей ёж ");
}

#[test]
fn double_press_gives_kazakh_letters() {
    assert_eq!(typed("саалем "), "сәлем ");
    assert_eq!(typed("оомиир "), "өмір ");
    assert_eq!(typed("мениинн "), "менің ");
    assert_eq!(typed("Аллахх "), "Аллаһ ");
}

#[test]
fn third_press_gives_the_literal_double() {
    assert_eq!(typed("зооопаркк "), "зоопарк ");
    assert_eq!(typed("куунннен "), "күннен ");
    assert_eq!(typed("Казакстанннынн "), "Қазақстанның ");
}

#[test]
fn triple_i_gives_i_followed_by_kazakh_i() {
    assert_eq!(typed("жиии "), "жиі ");
    assert_eq!(typed("бииик "), "биік ");
    assert_eq!(typed("кииим "), "киім ");
}

#[test]
fn k_and_g_follow_vowel_harmony() {
    assert_eq!(typed("казак "), "қазақ ");
    assert_eq!(typed("Казакстан "), "Қазақстан ");
    assert_eq!(typed("кел "), "кел ");
    assert_eq!(typed("мектеп "), "мектеп ");
    assert_eq!(typed("галым "), "ғалым ");
    assert_eq!(typed("алга "), "алға ");
    assert_eq!(typed("егер "), "егер ");
    assert_eq!(typed("республика "), "республика ");
}

#[test]
fn double_k_and_g_force_the_plain_letter() {
    assert_eq!(typed("ккомпания "), "компания ");
    assert_eq!(typed("технологгия "), "технология ");
}

#[test]
fn triple_k_doubles_the_harmonised_letter() {
    assert_eq!(typed("халыккка "), "халыққа ");
    assert_eq!(typed("шыкккан "), "шыққан ");
    assert_eq!(typed("еккен "), "екен ");
    assert_eq!(typed("екккен "), "еккен ");
}

#[test]
fn double_u_follows_vowel_harmony() {
    assert_eq!(typed("жуумыс "), "жұмыс ");
    assert_eq!(typed("туурии "), "түрі ");
    assert_eq!(typed("буугиин "), "бүгін ");
    assert_eq!(typed("куурылыс "), "құрылыс ");
}

#[test]
fn single_u_stays_u() {
    assert_eq!(typed("ауыл "), "ауыл ");
    assert_eq!(typed("оку "), "оқу ");
}

#[test]
fn dictionary_decides_words_without_vowel_evidence() {
    assert_eq!(typed("буул "), "бұл ");
    assert_eq!(typed("куун "), "күн ");
    assert_eq!(typed("гуул "), "гүл ");
    assert_eq!(typed("ууй "), "үй ");
    assert_eq!(typed("туур "), "тұр ");
}

#[test]
fn third_u_press_flips_the_choice() {
    assert_eq!(typed("тууур "), "түр ");
    assert_eq!(typed("кууурмет "), "құрмет ");
}

#[test]
fn uppercase_follows_shift() {
    assert_eq!(typed("Аалем "), "Әлем ");
    assert_eq!(typed("аАлем "), "Әлем ");
    assert_eq!(typed("КАЗАК "), "ҚАЗАҚ ");
}

#[test]
fn caps_lock_uppercases_letters() {
    let mut engine = cyrillic_engine();
    let mut model = TextModel::default();
    for letter in ['к', 'а', 'а'] {
        let mut event = press(letter);
        event.caps_lock = true;
        model.apply(&engine.handle_key(&event));
    }
    model.apply(&engine.handle_special_key(SpecialKey::Space, CONTEXT));
    assert_eq!(model.committed, "КӘ");
}

#[test]
fn whole_word_is_composed_until_a_boundary() {
    let mut engine = cyrillic_engine();
    engine.handle_key(&press('к'));
    assert_eq!(
        engine.handle_key(&press('е')),
        vec![EngineAction::SetComposition("ке".to_owned())]
    );
    assert_eq!(
        engine.handle_special_key(SpecialKey::Space, CONTEXT),
        vec![EngineAction::CommitComposition, EngineAction::ForwardKey]
    );
    assert!(!engine.state().has_composition());
}

#[test]
fn composition_is_updated_as_later_letters_decide_harmony() {
    let mut engine = cyrillic_engine();
    assert_eq!(
        engine.handle_key(&press('к')),
        vec![EngineAction::SetComposition("қ".to_owned())]
    );
    assert_eq!(
        engine.handle_key(&press('е')),
        vec![EngineAction::SetComposition("ке".to_owned())]
    );
}

#[test]
fn backspace_removes_the_last_visible_letter() {
    assert_eq!(typed("саа<"), "с");
    assert_eq!(typed("саа<а"), "са");
    assert_eq!(typed("зооо<"), "зо");
    assert_eq!(typed("а<"), "");
    assert_eq!(typed("а< "), " ");
}

#[test]
fn backspace_on_last_letter_clears_composition() {
    let mut engine = cyrillic_engine();
    engine.handle_key(&press('а'));
    assert_eq!(
        engine.handle_special_key(SpecialKey::Backspace, CONTEXT),
        vec![EngineAction::ClearComposition]
    );
    assert_eq!(
        engine.handle_special_key(SpecialKey::Backspace, CONTEXT),
        vec![EngineAction::ForwardKey]
    );
}

#[test]
fn punctuation_follows_the_russian_layout() {
    let mut engine = cyrillic_engine();
    let mut model = TextModel::default();
    for letter in ['с', 'а', 'а', 'л', 'е', 'м'] {
        model.apply(&engine.handle_key(&press(letter)));
    }
    let mut comma = KeyEvent::new("/", 0, CONTEXT);
    comma.shift = true;
    model.apply(&engine.handle_key(&comma));
    model.apply(&engine.handle_key(&KeyEvent::new("/", 0, CONTEXT)));
    let mut quote = KeyEvent::new("2", 0, CONTEXT);
    quote.shift = true;
    model.apply(&engine.handle_key(&quote));
    model.apply(&engine.handle_key(&KeyEvent::new("7", 0, CONTEXT)));
    assert_eq!(model.visible_text(), "сәлем,.\"7");
}

#[test]
fn symbol_commits_the_word_before_itself() {
    let mut engine = cyrillic_engine();
    engine.handle_key(&press('а'));
    assert_eq!(
        engine.handle_key(&KeyEvent::new("1", 0, CONTEXT)),
        vec![
            EngineAction::CommitComposition,
            EngineAction::CommitText("1".to_owned())
        ]
    );
}

#[test]
fn double_short_i_switches_mode_and_keeps_the_word() {
    let mut engine = cyrillic_engine();
    let text = type_keys(&mut engine, "саалемйй");
    assert_eq!(text, "сәлем");
    assert_eq!(engine.state().mode, InputMode::English);
    assert!(!engine.state().has_composition());

    let actions = engine.handle_key(&KeyEvent::new("f", 0, CONTEXT));
    assert_eq!(actions, vec![EngineAction::ForwardKey]);
}

#[test]
fn double_short_i_on_empty_word_only_switches() {
    let mut engine = cyrillic_engine();
    engine.handle_key(&press('й'));
    assert_eq!(
        engine.handle_key(&press('й')),
        vec![
            EngineAction::ClearComposition,
            EngineAction::SwitchMode(InputMode::English)
        ]
    );
}

#[test]
fn fast_qq_switches_back_from_english() {
    let mut engine = cyrillic_engine();
    engine.set_mode(InputMode::English);
    engine.handle_key(&KeyEvent::new("q", 0, CONTEXT));
    engine.handle_key(&KeyEvent::new("q", 100, CONTEXT));
    assert_eq!(engine.state().mode, InputMode::Kazakh);
    assert_eq!(type_keys(&mut engine, "саалем "), "сәлем ");
}

#[test]
fn auto_repeat_never_builds_kazakh_letters() {
    let mut engine = cyrillic_engine();
    let mut model = TextModel::default();
    model.apply(&engine.handle_key(&press('а')));
    for _ in 0..3 {
        let mut repeated = press('а');
        repeated.is_repeat = true;
        model.apply(&engine.handle_key(&repeated));
    }
    assert_eq!(model.visible_text(), "аааа");
}

#[test]
fn cursor_movement_commits_and_destruction_clears() {
    let mut engine = cyrillic_engine();
    engine.handle_key(&press('а'));
    assert_eq!(
        engine.handle_context_event(ContextEvent::CursorMoved),
        vec![EngineAction::CommitComposition]
    );

    engine.handle_key(&press('а'));
    assert_eq!(
        engine.handle_context_event(ContextEvent::ContextDestroyed),
        vec![EngineAction::ClearComposition]
    );
}

#[test]
fn escape_commits_the_word_instead_of_losing_it() {
    let mut engine = cyrillic_engine();
    engine.handle_key(&press('а'));
    assert_eq!(
        engine.handle_special_key(SpecialKey::Escape, CONTEXT),
        vec![EngineAction::CommitComposition, EngineAction::ForwardKey]
    );
}

#[test]
fn switching_layout_commits_the_open_word() {
    let mut engine = cyrillic_engine();
    engine.handle_key(&press('а'));
    assert_eq!(
        engine.update_config(EngineConfig::default()).unwrap(),
        vec![EngineAction::CommitComposition]
    );
    assert_eq!(engine.config().layout, KeyboardLayout::Latin);
}

#[test]
fn new_context_drops_the_old_word() {
    let mut engine = cyrillic_engine();
    engine.handle_key(&press('а'));
    let mut other = press('б');
    other.context_id = 99;
    assert_eq!(
        engine.handle_key(&other),
        vec![
            EngineAction::ClearComposition,
            EngineAction::SetComposition("б".to_owned())
        ]
    );
}
