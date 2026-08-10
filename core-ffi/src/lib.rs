//! Stable C ABI for native `QazaqType` platform adapters.

use std::ffi::{CStr, CString, c_char};
use std::ptr;

use qazaqtype_core::{
    ContextEvent, Engine, EngineAction, EngineConfig, InputMode, KeyEvent, SpecialKey,
};

pub const ACTION_SET_COMPOSITION: u32 = 1;
pub const ACTION_COMMIT_COMPOSITION: u32 = 2;
pub const ACTION_COMMIT_TEXT: u32 = 3;
pub const ACTION_CLEAR_COMPOSITION: u32 = 4;
pub const ACTION_SWITCH_MODE: u32 = 5;
pub const ACTION_FORWARD_KEY: u32 = 6;

#[repr(C)]
pub struct QazaqAction {
    pub kind: u32,
    pub mode: u32,
    pub text: *mut c_char,
}

#[repr(C)]
pub struct QazaqActionList {
    pub actions: *mut QazaqAction,
    pub len: usize,
}

impl QazaqActionList {
    const fn empty() -> Self {
        Self {
            actions: ptr::null_mut(),
            len: 0,
        }
    }
}

/// Creates a default KZ-mode engine.
#[unsafe(no_mangle)]
pub extern "C" fn qazaq_engine_new() -> *mut Engine {
    qazaq_engine_new_with_config(true, 0, 400)
}

/// Creates an engine from platform-owned settings.
#[unsafe(no_mangle)]
pub extern "C" fn qazaq_engine_new_with_config(
    enabled: bool,
    default_mode: u32,
    threshold_ms: u64,
) -> *mut Engine {
    let config = EngineConfig {
        enabled,
        default_mode: decode_mode(default_mode),
        double_press_threshold_ms: threshold_ms,
    };
    match Engine::new(config) {
        Ok(engine) => Box::into_raw(Box::new(engine)),
        Err(_) => ptr::null_mut(),
    }
}

/// Destroys an engine created by [`qazaq_engine_new`].
///
/// # Safety
///
/// `engine` must be null or a live pointer returned by `qazaq_engine_new` that
/// has not already been freed.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qazaq_engine_free(engine: *mut Engine) {
    if !engine.is_null() {
        // SAFETY: Required by this function's pointer ownership contract.
        unsafe { drop(Box::from_raw(engine)) };
    }
}

/// Processes one normalized printable key.
///
/// # Safety
///
/// `engine` must point to a live engine and `key` must point to a valid,
/// NUL-terminated UTF-8 string for the duration of the call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qazaq_engine_handle_key(
    engine: *mut Engine,
    key: *const c_char,
    timestamp_ms: u64,
    shift: bool,
    caps_lock: bool,
    is_repeat: bool,
    context_id: u64,
) -> QazaqActionList {
    if engine.is_null() || key.is_null() {
        return QazaqActionList::empty();
    }
    // SAFETY: The caller guarantees both pointers are live for this call.
    let engine = unsafe { &mut *engine };
    // SAFETY: The caller guarantees `key` is a NUL-terminated C string.
    let Ok(key) = unsafe { CStr::from_ptr(key) }.to_str() else {
        return QazaqActionList::empty();
    };
    let event = KeyEvent {
        key: key.to_owned(),
        timestamp_ms,
        shift,
        caps_lock,
        is_repeat,
        context_id,
    };
    into_ffi_actions(engine.handle_key(&event))
}

/// Processes a monotonic timeout callback.
///
/// # Safety
///
/// `engine` must point to a live engine.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qazaq_engine_handle_timeout(
    engine: *mut Engine,
    timestamp_ms: u64,
    context_id: u64,
) -> QazaqActionList {
    if engine.is_null() {
        return QazaqActionList::empty();
    }
    // SAFETY: Required by this function's pointer contract.
    let engine = unsafe { &mut *engine };
    into_ffi_actions(engine.handle_timeout(timestamp_ms, context_id))
}

/// Processes a special key identified by its stable numeric code.
///
/// # Safety
///
/// `engine` must point to a live engine.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qazaq_engine_handle_special(
    engine: *mut Engine,
    special: u32,
    context_id: u64,
) -> QazaqActionList {
    if engine.is_null() {
        return QazaqActionList::empty();
    }
    let Some(special) = decode_special(special) else {
        return QazaqActionList::empty();
    };
    // SAFETY: Required by this function's pointer contract.
    let engine = unsafe { &mut *engine };
    into_ffi_actions(engine.handle_special_key(special, context_id))
}

/// Processes an input-context lifecycle event.
///
/// # Safety
///
/// `engine` must point to a live engine.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qazaq_engine_handle_context(
    engine: *mut Engine,
    event: u32,
) -> QazaqActionList {
    if engine.is_null() {
        return QazaqActionList::empty();
    }
    let Some(event) = decode_context_event(event) else {
        return QazaqActionList::empty();
    };
    // SAFETY: Required by this function's pointer contract.
    let engine = unsafe { &mut *engine };
    into_ffi_actions(engine.handle_context_event(event))
}

/// Returns the current mode (`0` for KZ, `1` for EN).
///
/// # Safety
///
/// `engine` must be null or point to a live engine.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qazaq_engine_mode(engine: *const Engine) -> u32 {
    if engine.is_null() {
        return 0;
    }
    // SAFETY: Required by this function's pointer contract.
    match unsafe { &*engine }.state().mode {
        InputMode::Kazakh => 0,
        InputMode::English => 1,
    }
}

/// Applies new settings to an existing engine.
///
/// # Safety
///
/// `engine` must point to a live engine.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qazaq_engine_update_config(
    engine: *mut Engine,
    enabled: bool,
    default_mode: u32,
    threshold_ms: u64,
) -> QazaqActionList {
    if engine.is_null() {
        return QazaqActionList::empty();
    }
    let config = EngineConfig {
        enabled,
        default_mode: decode_mode(default_mode),
        double_press_threshold_ms: threshold_ms,
    };
    // SAFETY: Required by this function's pointer contract.
    let engine = unsafe { &mut *engine };
    match engine.update_config(config) {
        Ok(actions) => into_ffi_actions(actions),
        Err(_) => QazaqActionList::empty(),
    }
}

/// Releases every allocation owned by an action list.
///
/// # Safety
///
/// `list` must be empty or be the unmodified value returned by one of this
/// module's action-producing functions, and it must be freed exactly once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn qazaq_action_list_free(list: QazaqActionList) {
    if list.actions.is_null() {
        return;
    }
    let slice = ptr::slice_from_raw_parts_mut(list.actions, list.len);
    // SAFETY: Required by this function's ownership contract.
    let actions = unsafe { Box::from_raw(slice) };
    for action in actions {
        if !action.text.is_null() {
            // SAFETY: Text pointers are created by `CString::into_raw` below.
            unsafe { drop(CString::from_raw(action.text)) };
        }
    }
}

fn into_ffi_actions(actions: Vec<EngineAction>) -> QazaqActionList {
    if actions.is_empty() {
        return QazaqActionList::empty();
    }
    let actions: Box<[_]> = actions
        .into_iter()
        .map(into_ffi_action)
        .collect::<Vec<_>>()
        .into_boxed_slice();
    let len = actions.len();
    QazaqActionList {
        actions: Box::into_raw(actions).cast::<QazaqAction>(),
        len,
    }
}

fn into_ffi_action(action: EngineAction) -> QazaqAction {
    match action {
        EngineAction::SetComposition(text) => ffi_action(ACTION_SET_COMPOSITION, 0, Some(text)),
        EngineAction::CommitComposition => ffi_action(ACTION_COMMIT_COMPOSITION, 0, None),
        EngineAction::CommitText(text) => ffi_action(ACTION_COMMIT_TEXT, 0, Some(text)),
        EngineAction::ClearComposition => ffi_action(ACTION_CLEAR_COMPOSITION, 0, None),
        EngineAction::SwitchMode(mode) => ffi_action(
            ACTION_SWITCH_MODE,
            u32::from(mode == InputMode::English),
            None,
        ),
        EngineAction::ForwardKey => ffi_action(ACTION_FORWARD_KEY, 0, None),
    }
}

fn ffi_action(kind: u32, mode: u32, text: Option<String>) -> QazaqAction {
    let text = text
        .and_then(|value| CString::new(value).ok())
        .map_or(ptr::null_mut(), CString::into_raw);
    QazaqAction { kind, mode, text }
}

fn decode_special(value: u32) -> Option<SpecialKey> {
    Some(match value {
        1 => SpecialKey::Space,
        2 => SpecialKey::Enter,
        3 => SpecialKey::Tab,
        4 => SpecialKey::Backspace,
        5 => SpecialKey::Delete,
        6 => SpecialKey::Escape,
        7 => SpecialKey::Arrow,
        8 => SpecialKey::Home,
        9 => SpecialKey::End,
        10 => SpecialKey::PageUp,
        11 => SpecialKey::PageDown,
        _ => return None,
    })
}

fn decode_context_event(value: u32) -> Option<ContextEvent> {
    Some(match value {
        1 => ContextEvent::CursorMoved,
        2 => ContextEvent::FocusLost,
        3 => ContextEvent::InputMethodDeactivated,
        4 => ContextEvent::ContextDestroyed,
        5 => ContextEvent::CompositionCancelled,
        _ => return None,
    })
}

const fn decode_mode(value: u32) -> InputMode {
    if value == 1 {
        InputMode::English
    } else {
        InputMode::Kazakh
    }
}
