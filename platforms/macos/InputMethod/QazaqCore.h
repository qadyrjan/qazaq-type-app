#ifndef QAZAQTYPE_CORE_H
#define QAZAQTYPE_CORE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

typedef struct QazaqEngine QazaqEngine;

typedef struct {
    uint32_t kind;
    uint32_t mode;
    char *text;
} QazaqAction;

typedef struct {
    QazaqAction *actions;
    size_t len;
} QazaqActionList;

enum {
    QAZAQ_ACTION_SET_COMPOSITION = 1,
    QAZAQ_ACTION_COMMIT_COMPOSITION = 2,
    QAZAQ_ACTION_COMMIT_TEXT = 3,
    QAZAQ_ACTION_CLEAR_COMPOSITION = 4,
    QAZAQ_ACTION_SWITCH_MODE = 5,
    QAZAQ_ACTION_FORWARD_KEY = 6,
};

enum {
    QAZAQ_SPECIAL_SPACE = 1,
    QAZAQ_SPECIAL_ENTER = 2,
    QAZAQ_SPECIAL_TAB = 3,
    QAZAQ_SPECIAL_BACKSPACE = 4,
    QAZAQ_SPECIAL_DELETE = 5,
    QAZAQ_SPECIAL_ESCAPE = 6,
    QAZAQ_SPECIAL_ARROW = 7,
    QAZAQ_SPECIAL_HOME = 8,
    QAZAQ_SPECIAL_END = 9,
    QAZAQ_SPECIAL_PAGE_UP = 10,
    QAZAQ_SPECIAL_PAGE_DOWN = 11,
};

enum {
    QAZAQ_CONTEXT_CURSOR_MOVED = 1,
    QAZAQ_CONTEXT_FOCUS_LOST = 2,
    QAZAQ_CONTEXT_INPUT_METHOD_DEACTIVATED = 3,
    QAZAQ_CONTEXT_DESTROYED = 4,
    QAZAQ_CONTEXT_COMPOSITION_CANCELLED = 5,
};

QazaqEngine *qazaq_engine_new(void);
QazaqEngine *qazaq_engine_new_with_config(
    bool enabled,
    uint32_t default_mode,
    uint64_t threshold_ms
);
void qazaq_engine_free(QazaqEngine *engine);

QazaqActionList qazaq_engine_handle_key(
    QazaqEngine *engine,
    const char *key,
    uint64_t timestamp_ms,
    bool shift,
    bool caps_lock,
    bool is_repeat,
    uint64_t context_id
);

QazaqActionList qazaq_engine_handle_timeout(
    QazaqEngine *engine,
    uint64_t timestamp_ms,
    uint64_t context_id
);

QazaqActionList qazaq_engine_handle_special(
    QazaqEngine *engine,
    uint32_t special,
    uint64_t context_id
);

QazaqActionList qazaq_engine_handle_context(
    QazaqEngine *engine,
    uint32_t event
);

uint32_t qazaq_engine_mode(const QazaqEngine *engine);
QazaqActionList qazaq_engine_update_config(
    QazaqEngine *engine,
    bool enabled,
    uint32_t default_mode,
    uint64_t threshold_ms
);
void qazaq_action_list_free(QazaqActionList list);

#ifdef __OBJC__
@interface QazaqClientBridge : NSObject
+ (BOOL)setMarkedText:(NSString *)text client:(id)client;
+ (BOOL)insertText:(NSString *)text client:(id)client;
@end
#endif

#endif
