import Carbon
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: register <path-to-input-method>\n", stderr)
    exit(EXIT_FAILURE)
}

let bundleURL = URL(
    fileURLWithPath: CommandLine.arguments[1],
    isDirectory: true
)
guard let bundleID = Bundle(url: bundleURL)?.bundleIdentifier else {
    fputs("input method has no bundle identifier\n", stderr)
    exit(EXIT_FAILURE)
}
let registerStatus = TISRegisterInputSource(bundleURL as CFURL)
guard registerStatus == noErr else {
    fputs("TISRegisterInputSource failed: \(registerStatus)\n", stderr)
    exit(registerStatus)
}

let filter = [
    kTISPropertyBundleID as String: bundleID
] as CFDictionary
guard let sourceList = TISCreateInputSourceList(filter, true) else {
    fputs(
        "registered bundle is not yet visible in the input-source cache; a logout/login may be required\n",
        stderr
    )
    exit(EXIT_SUCCESS)
}
let sources = sourceList.takeRetainedValue() as! [TISInputSource]

guard !sources.isEmpty else {
    fputs(
        "registered bundle did not expose \(bundleID); a logout/login may be required\n",
        stderr
    )
    exit(EXIT_SUCCESS)
}

var remaining = sources
for _ in 0..<2 {
    remaining = remaining.filter { source in
        TISEnableInputSource(source) != noErr
    }
}

guard remaining.isEmpty else {
    fputs("TISEnableInputSource failed for \(remaining.count) source(s)\n", stderr)
    exit(EXIT_FAILURE)
}

let selectableSource = sources.first { source in
    guard
        let type = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceType
        )
    else {
        return false
    }
    return Unmanaged<CFString>.fromOpaque(type).takeUnretainedValue()
        == kTISTypeKeyboardInputMode
}

if let selectableSource {
    let selectStatus = TISSelectInputSource(selectableSource)
    if selectStatus == noErr {
        print("Registered, enabled, and selected: \(bundleID)")
    } else {
        fputs(
            "registered and enabled; select QazaqType from the input menu"
                + " (automatic selection returned \(selectStatus))\n",
            stderr
        )
    }
} else {
    print("Registered and enabled: \(bundleID)")
}
