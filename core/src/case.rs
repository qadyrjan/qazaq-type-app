pub(crate) fn effective_uppercase(key: char, shift: bool, caps_lock: bool) -> bool {
    if key.is_ascii_alphabetic() {
        shift ^ caps_lock
    } else {
        shift
    }
}
