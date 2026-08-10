import Cocoa
import Carbon
import InputMethodKit

private let qazaqInputModeIdentifier =
    "kz.qazaqtype.inputmethod.QazaqType.Kazakh"
private let qazaqBundleIdentifier =
    "kz.qazaqtype.inputmethod.QazaqType"

private func inputSource(identifier: String) -> TISInputSource? {
    guard let sourceList = TISCreateInputSourceList(nil, true) else {
        return nil
    }
    return (sourceList.takeRetainedValue() as! [TISInputSource]).first {
        source in
        guard let pointer = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceID
        ) else {
            return false
        }
        let value = Unmanaged<CFString>
            .fromOpaque(pointer)
            .takeUnretainedValue()
        return value as String == identifier
    }
}

private func qazaqMainInputSource() -> TISInputSource? {
    inputSource(identifier: qazaqBundleIdentifier)
}

private func qazaqInputMode() -> TISInputSource? {
    inputSource(identifier: qazaqInputModeIdentifier)
}

private func registerInputSource() -> Int32 {
    let registerStatus = TISRegisterInputSource(
        Bundle.main.bundleURL as CFURL
    )
    guard registerStatus == noErr else {
        fputs(
            "TISRegisterInputSource failed: \(registerStatus)\n",
            stderr
        )
        return EXIT_FAILURE
    }

    guard qazaqMainInputSource() != nil else {
        fputs(
            "Registered QazaqType, but its main input source is unavailable\n",
            stderr
        )
        return EXIT_FAILURE
    }

    print("Registered input source: \(qazaqInputModeIdentifier)")
    return EXIT_SUCCESS
}

private func enableInputSource() -> Int32 {
    guard let mainSource = qazaqMainInputSource() else {
        fputs("QazaqType main input source was not found\n", stderr)
        return EXIT_FAILURE
    }
    let mainStatus = TISEnableInputSource(mainSource)
    guard mainStatus == noErr else {
        fputs("TISEnableInputSource failed: \(mainStatus)\n", stderr)
        return EXIT_FAILURE
    }

    if let mode = qazaqInputMode() {
        let modeStatus = TISEnableInputSource(mode)
        guard modeStatus == noErr else {
            fputs("TISEnableInputMode failed: \(modeStatus)\n", stderr)
            return EXIT_FAILURE
        }
    }
    print("Enabled input source: \(qazaqBundleIdentifier)")
    return EXIT_SUCCESS
}

private func selectInputSource() -> Int32 {
    guard let source = qazaqInputMode() else {
        fputs("QazaqType input mode was not found\n", stderr)
        return EXIT_FAILURE
    }
    let status = TISSelectInputSource(source)
    guard status == noErr else {
        fputs("TISSelectInputSource failed: \(status)\n", stderr)
        return EXIT_FAILURE
    }
    print("Selected input source: \(qazaqInputModeIdentifier)")
    return EXIT_SUCCESS
}

if CommandLine.arguments.contains("--register-input-source") {
    exit(registerInputSource())
}
if CommandLine.arguments.contains("--enable-input-source") {
    exit(enableInputSource())
}
if CommandLine.arguments.contains("--select-input-source") {
    exit(selectInputSource())
}

guard
    let connectionName = Bundle.main.object(
        forInfoDictionaryKey: "InputMethodConnectionName"
    ) as? String,
    let bundleIdentifier = Bundle.main.bundleIdentifier
else {
    exit(EXIT_FAILURE)
}

guard let inputMethodServer = IMKServer(
    name: connectionName,
    bundleIdentifier: bundleIdentifier
) else {
    exit(EXIT_FAILURE)
}

withExtendedLifetime(inputMethodServer) {
    NSApplication.shared.run()
}
