use qazaqtype_core::InputRules;

#[test]
fn portable_json_manifest_matches_compiled_rules() {
    let manifest = include_str!("../../shared/rules.json");
    let rules = InputRules::new();

    for key in 'a'..='z' {
        let lower = rules.single(key, false).unwrap();
        let upper = rules.single(key, true).unwrap();
        let fragment = format!(r#""{key}": ["{lower}", "{upper}"]"#);
        assert!(
            manifest.contains(&fragment),
            "shared/rules.json is missing {fragment}"
        );
    }

    for key in [
        'a', 's', 'c', 'z', 'n', 'o', 'u', 'y', 'g', 'e', ',', '.', '/',
    ] {
        let lower = rules.double(key, false).unwrap();
        let upper = rules.double(key, true).unwrap();
        let fragment = format!(r#""{key}": ["{lower}", "{upper}"]"#);
        assert!(
            manifest.contains(&fragment),
            "shared/rules.json is missing {fragment}"
        );
    }

    assert!(manifest.contains(r#""mode_toggle": "qq""#));
    assert!(manifest.contains(r#""default_double_press_threshold_ms": 400"#));
    assert!(manifest.contains(r#""double_press_threshold_range_ms": [200, 800]"#));
}
