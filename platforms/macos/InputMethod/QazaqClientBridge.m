#import "QazaqCore.h"
#import <Carbon/Carbon.h>

@implementation QazaqClientBridge

+ (BOOL)setMarkedText:(NSString *)text client:(id)client {
    if (![client respondsToSelector:
            @selector(setMarkedText:selectionRange:replacementRange:)]) {
        return NO;
    }
    [(id<IMKTextInput>)client setMarkedText:text
                             selectionRange:NSMakeRange(text.length, 0)
                           replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    return YES;
}

+ (BOOL)insertText:(NSString *)text client:(id)client {
    if (![client respondsToSelector:@selector(insertText:replacementRange:)]) {
        return NO;
    }
    [(id<IMKTextInput>)client insertText:text
                        replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    return YES;
}

@end
