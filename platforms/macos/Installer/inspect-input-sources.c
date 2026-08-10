#include <Carbon/Carbon.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

static bool copy_string_property(
    TISInputSourceRef source,
    CFStringRef key,
    char *buffer,
    CFIndex capacity
) {
    CFStringRef value = (CFStringRef)TISGetInputSourceProperty(source, key);
    if (value == NULL || CFGetTypeID(value) != CFStringGetTypeID()) {
        buffer[0] = '\0';
        return false;
    }
    return CFStringGetCString(value, buffer, capacity, kCFStringEncodingUTF8);
}

static void print_string_array_property(
    TISInputSourceRef source,
    CFStringRef key
) {
    CFArrayRef values = (CFArrayRef)TISGetInputSourceProperty(source, key);
    if (values == NULL || CFGetTypeID(values) != CFArrayGetTypeID()) {
        fputs("-", stdout);
        return;
    }

    CFIndex count = CFArrayGetCount(values);
    for (CFIndex index = 0; index < count; ++index) {
        CFStringRef value = (CFStringRef)CFArrayGetValueAtIndex(values, index);
        char buffer[256] = "";
        if (
            value != NULL
            && CFGetTypeID(value) == CFStringGetTypeID()
            && CFStringGetCString(
                value,
                buffer,
                sizeof(buffer),
                kCFStringEncodingUTF8
            )
        ) {
            if (index > 0) {
                putchar(',');
            }
            fputs(buffer, stdout);
        }
    }
}

int main(int argc, const char *argv[]) {
    const char *needle = argc > 1 ? argv[1] : "";
    bool should_select = argc > 2 && strcmp(argv[2], "--select") == 0;
    bool should_disable = argc > 2 && strcmp(argv[2], "--disable") == 0;
    CFArrayRef sources = TISCreateInputSourceList(NULL, true);
    if (sources == NULL) {
        fputs("TISCreateInputSourceList returned NULL\n", stderr);
        return 1;
    }

    CFIndex count = CFArrayGetCount(sources);
    for (CFIndex index = 0; index < count; ++index) {
        TISInputSourceRef source =
            (TISInputSourceRef)CFArrayGetValueAtIndex(sources, index);
        char identifier[512];
        char bundle[512];
        char type[256];
        char category[256];
        char localized_name[512];
        char mode_identifier[512];
        copy_string_property(
            source,
            kTISPropertyInputSourceID,
            identifier,
            sizeof(identifier)
        );
        copy_string_property(
            source,
            kTISPropertyBundleID,
            bundle,
            sizeof(bundle)
        );
        copy_string_property(
            source,
            kTISPropertyInputSourceType,
            type,
            sizeof(type)
        );
        copy_string_property(
            source,
            kTISPropertyInputSourceCategory,
            category,
            sizeof(category)
        );
        copy_string_property(
            source,
            kTISPropertyLocalizedName,
            localized_name,
            sizeof(localized_name)
        );
        copy_string_property(
            source,
            kTISPropertyInputModeID,
            mode_identifier,
            sizeof(mode_identifier)
        );

        if (
            needle[0] != '\0'
            && strstr(identifier, needle) == NULL
            && strstr(bundle, needle) == NULL
        ) {
            continue;
        }

        CFBooleanRef enabled = (CFBooleanRef)TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceIsEnabled
        );
        CFBooleanRef selected = (CFBooleanRef)TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceIsSelected
        );
        CFBooleanRef select_capable = (CFBooleanRef)TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceIsSelectCapable
        );
        CFBooleanRef enable_capable = (CFBooleanRef)TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceIsEnableCapable
        );
        CFBooleanRef ascii_capable = (CFBooleanRef)TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceIsASCIICapable
        );
        printf(
            "id=%s\tbundle=%s\ttype=%s\tcategory=%s\tenabled=%s"
            "\tselected=%s\tselectCapable=%s\tenableCapable=%s"
            "\tasciiCapable=%s\tname=%s\tmode=%s\tlanguages=",
            identifier,
            bundle,
            type,
            category,
            enabled == kCFBooleanTrue ? "true" : "false",
            selected == kCFBooleanTrue ? "true" : "false",
            select_capable == kCFBooleanTrue ? "true" : "false",
            enable_capable == kCFBooleanTrue ? "true" : "false",
            ascii_capable == kCFBooleanTrue ? "true" : "false",
            localized_name,
            mode_identifier
        );
        print_string_array_property(source, kTISPropertyInputSourceLanguages);
        putchar('\n');
        if (should_select && select_capable == kCFBooleanTrue) {
            OSStatus select_status = TISSelectInputSource(source);
            printf("selectStatus=%d\tid=%s\n", select_status, identifier);
        }
        if (should_disable && enable_capable == kCFBooleanTrue) {
            OSStatus disable_status = TISDisableInputSource(source);
            printf("disableStatus=%d\tid=%s\n", disable_status, identifier);
        }
    }

    CFRelease(sources);
    return 0;
}
