use std::ffi::{CStr, CString};

use qazaqtype_core_ffi::{
    ACTION_CLEAR_COMPOSITION, ACTION_COMMIT_COMPOSITION, ACTION_SET_COMPOSITION,
    ACTION_SWITCH_MODE, LAYOUT_CYRILLIC, LAYOUT_LATIN, qazaq_action_list_free, qazaq_engine_free,
    qazaq_engine_handle_key, qazaq_engine_mode, qazaq_engine_new, qazaq_engine_new_with_config,
    qazaq_engine_update_config,
};

#[test]
fn c_abi_round_trips_actions_and_text() {
    // SAFETY: This test observes the ownership contract of every FFI function.
    unsafe {
        let engine = qazaq_engine_new();
        assert!(!engine.is_null());
        let q = CString::new("q").unwrap();

        let first = qazaq_engine_handle_key(engine, q.as_ptr(), 0, false, false, false, 1);
        assert_eq!(first.len, 1);
        let first_action = &*first.actions;
        assert_eq!(first_action.kind, ACTION_SET_COMPOSITION);
        assert_eq!(CStr::from_ptr(first_action.text).to_str().unwrap(), "қ");
        qazaq_action_list_free(first);

        let second = qazaq_engine_handle_key(engine, q.as_ptr(), 100, false, false, false, 1);
        assert_eq!(second.len, 2);
        let actions = std::slice::from_raw_parts(second.actions, second.len);
        assert_eq!(actions[0].kind, ACTION_CLEAR_COMPOSITION);
        assert_eq!(actions[1].kind, ACTION_SWITCH_MODE);
        assert_eq!(actions[1].mode, 1);
        assert_eq!(qazaq_engine_mode(engine), 1);
        qazaq_action_list_free(second);

        qazaq_engine_free(engine);
    }
}

#[test]
fn c_abi_accepts_valid_config_and_rejects_invalid_threshold() {
    // SAFETY: This test observes the ownership contract of every FFI function.
    unsafe {
        let invalid = qazaq_engine_new_with_config(true, 0, 199, LAYOUT_LATIN);
        assert!(invalid.is_null());

        let engine = qazaq_engine_new_with_config(true, 1, 600, LAYOUT_LATIN);
        assert!(!engine.is_null());
        assert_eq!(qazaq_engine_mode(engine), 1);

        let q = CString::new("q").unwrap();
        let pending = qazaq_engine_handle_key(engine, q.as_ptr(), 0, false, false, false, 1);
        qazaq_action_list_free(pending);

        let updated = qazaq_engine_update_config(engine, false, 0, 300, LAYOUT_LATIN);
        assert_eq!(updated.len, 1);
        let action = &*updated.actions;
        assert_eq!(action.kind, ACTION_CLEAR_COMPOSITION);
        qazaq_action_list_free(updated);
        qazaq_engine_free(engine);
    }
}

#[test]
fn c_abi_selects_the_cyrillic_layout() {
    // SAFETY: This test observes the ownership contract of every FFI function.
    unsafe {
        let engine = qazaq_engine_new_with_config(true, 0, 400, LAYOUT_CYRILLIC);
        assert!(!engine.is_null());
        // Physical `f` is `а` on the Russian keyboard; pressed twice it is `ә`.
        let f = CString::new("f").unwrap();
        let first = qazaq_engine_handle_key(engine, f.as_ptr(), 0, false, false, false, 1);
        qazaq_action_list_free(first);
        let second = qazaq_engine_handle_key(engine, f.as_ptr(), 900, false, false, false, 1);
        assert_eq!(second.len, 1);
        let action = &*second.actions;
        assert_eq!(action.kind, ACTION_SET_COMPOSITION);
        assert_eq!(CStr::from_ptr(action.text).to_str().unwrap(), "ә");
        qazaq_action_list_free(second);

        let switched = qazaq_engine_update_config(engine, true, 0, 400, LAYOUT_LATIN);
        assert_eq!(switched.len, 1);
        assert_eq!((*switched.actions).kind, ACTION_COMMIT_COMPOSITION);
        qazaq_action_list_free(switched);
        qazaq_engine_free(engine);
    }
}
