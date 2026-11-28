import Cocoa
import InputMethodKit

@objc(QazaqInputController)
final class QazaqInputController: IMKInputController {
    private static let contextID: UInt64 = 1

    private var engine: OpaquePointer?
    private var composition = ""
    private var timeout: DispatchWorkItem?
    private var preferencesObserver: NSObjectProtocol?
    private var runtimeConfig = QazaqPreferences.load()

    override init!(
        server: IMKServer!,
        delegate: Any!,
        client inputClient: Any!
    ) {
        engine = qazaq_engine_new_with_config(
            runtimeConfig.enabled,
            runtimeConfig.defaultMode,
            runtimeConfig.thresholdMilliseconds,
            runtimeConfig.layout
        )
        super.init(server: server, delegate: delegate, client: inputClient)
        preferencesObserver = DistributedNotificationCenter.default().addObserver(
            forName: QazaqPreferences.changedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadPreferences()
        }
    }

    deinit {
        timeout?.cancel()
        if let preferencesObserver {
            DistributedNotificationCenter.default().removeObserver(
                preferencesObserver
            )
        }
        qazaq_engine_free(engine)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let engine else {
            return false
        }

        let shortcutModifiers = event.modifierFlags.intersection([.command, .control, .option])
        if !shortcutModifiers.isEmpty {
            let actions = qazaq_engine_handle_context(
                engine,
                UInt32(QAZAQ_CONTEXT_CURSOR_MOVED)
            )
            _ = apply(actions, sender: sender)
            return false
        }

        if let special = Self.specialKeyCode(for: event) {
            let actions = qazaq_engine_handle_special(
                engine,
                special,
                Self.contextID
            )
            return apply(actions, sender: sender)
        }

        guard let key = Self.printableKey(for: event) else {
            // Keys the engine does not know (function keys, keypad) must not
            // leave a word composed while the application inserts text.
            let actions = qazaq_engine_handle_context(
                engine,
                UInt32(QAZAQ_CONTEXT_CURSOR_MOVED)
            )
            _ = apply(actions, sender: sender)
            return false
        }

        let timestamp = UInt64(event.timestamp * 1_000)
        let shift = event.modifierFlags.contains(.shift)
        let capsLock = event.modifierFlags.contains(.capsLock)
        let actions = key.withCString {
            qazaq_engine_handle_key(
                engine,
                $0,
                timestamp,
                shift,
                capsLock,
                event.isARepeat,
                Self.contextID
            )
        }
        return apply(actions, sender: sender)
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "QazaqType")
        let latin = NSMenuItem(
            title: L(.menuLatin),
            action: #selector(selectLatinLayout(_:)),
            keyEquivalent: ""
        )
        latin.state = runtimeConfig.layout == QazaqPreferences.latinLayout ? .on : .off
        let cyrillic = NSMenuItem(
            title: L(.menuCyrillic),
            action: #selector(selectCyrillicLayout(_:)),
            keyEquivalent: ""
        )
        cyrillic.state = runtimeConfig.layout == QazaqPreferences.cyrillicLayout ? .on : .off
        menu.addItem(latin)
        menu.addItem(cyrillic)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: L(.menuSettings),
                action: #selector(openSettings(_:)),
                keyEquivalent: ""
            )
        )
        return menu
    }

    @objc func openSettings(_ sender: Any!) {
        NSWorkspace.shared.openApplication(
            at: Self.settingsURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    private static var settingsURL: URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/QazaqType Settings.app")
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        // The input method never uses the network itself. Once a day it asks
        // the settings helper, a separate process, to look for a release.
        guard QazaqPreferences.claimDailyUpdateCheck() else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--check-for-updates"]
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.promptsUserIfNeeded = false
        NSWorkspace.shared.openApplication(
            at: Self.settingsURL,
            configuration: configuration
        )
    }

    @objc func selectLatinLayout(_ sender: Any!) {
        QazaqPreferences.saveLayout(QazaqPreferences.latinLayout)
        reloadPreferences()
    }

    @objc func selectCyrillicLayout(_ sender: Any!) {
        QazaqPreferences.saveLayout(QazaqPreferences.cyrillicLayout)
        reloadPreferences()
    }

    override func composedString(_ sender: Any!) -> Any! {
        // InputMethodKit calls this Objective-C entry point while updating the
        // marked range. Returning a native NSString avoids a Swift Any bridge
        // crash seen on Intel Macs running macOS Ventura.
        composition as NSString
    }

    override func commitComposition(_ sender: Any!) {
        guard let engine else {
            return
        }
        let actions = qazaq_engine_handle_context(
            engine,
            UInt32(QAZAQ_CONTEXT_FOCUS_LOST)
        )
        _ = apply(actions, sender: sender)
    }

    override func deactivateServer(_ sender: Any!) {
        guard let engine else {
            super.deactivateServer(sender)
            return
        }
        let actions = qazaq_engine_handle_context(
            engine,
            UInt32(QAZAQ_CONTEXT_INPUT_METHOD_DEACTIVATED)
        )
        _ = apply(actions, sender: sender)
        super.deactivateServer(sender)
    }

    override func inputControllerWillClose() {
        timeout?.cancel()
        if let engine {
            let actions = qazaq_engine_handle_context(
                engine,
                UInt32(QAZAQ_CONTEXT_DESTROYED)
            )
            qazaq_action_list_free(actions)
        }
        super.inputControllerWillClose()
    }

    private func apply(_ list: QazaqActionList, sender: Any!) -> Bool {
        defer { qazaq_action_list_free(list) }
        guard let actions = list.actions else {
            return false
        }

        var shouldForward = false
        for index in 0..<list.len {
            let action = actions[index]
            switch action.kind {
            case UInt32(QAZAQ_ACTION_SET_COMPOSITION):
                composition = action.text.map { String(cString: $0) } ?? ""
                setMarkedText(composition, sender: sender)
                scheduleTimeout(sender: sender)

            case UInt32(QAZAQ_ACTION_COMMIT_COMPOSITION):
                timeout?.cancel()
                insertText(composition, sender: sender)
                composition = ""

            case UInt32(QAZAQ_ACTION_COMMIT_TEXT):
                timeout?.cancel()
                let text = action.text.map { String(cString: $0) } ?? ""
                insertText(text, sender: sender)
                composition = ""

            case UInt32(QAZAQ_ACTION_CLEAR_COMPOSITION):
                timeout?.cancel()
                composition = ""
                setMarkedText("", sender: sender)

            case UInt32(QAZAQ_ACTION_SWITCH_MODE):
                timeout?.cancel()

            case UInt32(QAZAQ_ACTION_FORWARD_KEY):
                shouldForward = true

            default:
                break
            }
        }
        return !shouldForward
    }

    private func setMarkedText(_ text: String, sender: Any!) {
        let target = client() ?? sender
        _ = QazaqClientBridge.setMarkedText(text, client: target)
    }

    private func insertText(_ text: String, sender: Any!) {
        let target = client() ?? sender
        _ = QazaqClientBridge.insertText(text, client: target)
    }

    private func scheduleTimeout(sender: Any!) {
        timeout?.cancel()
        let work = DispatchWorkItem { [weak self, weak senderObject = sender as AnyObject] in
            guard let self, let engine = self.engine, let senderObject else {
                return
            }
            let now = UInt64(ProcessInfo.processInfo.systemUptime * 1_000)
            let actions = qazaq_engine_handle_timeout(
                engine,
                now,
                Self.contextID
            )
            _ = self.apply(actions, sender: senderObject)
        }
        timeout = work
        let delay = Double(runtimeConfig.thresholdMilliseconds + 1) / 1_000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func reloadPreferences() {
        guard let engine else {
            return
        }
        runtimeConfig = QazaqPreferences.load()
        let actions = qazaq_engine_update_config(
            engine,
            runtimeConfig.enabled,
            runtimeConfig.defaultMode,
            runtimeConfig.thresholdMilliseconds,
            runtimeConfig.layout
        )
        _ = apply(actions, sender: client())
    }

    private static func printableKey(for event: NSEvent) -> String? {
        physicalKeys[event.keyCode]
    }

    private static func specialKeyCode(for event: NSEvent) -> UInt32? {
        switch event.keyCode {
        case 49: return UInt32(QAZAQ_SPECIAL_SPACE)
        case 36, 76: return UInt32(QAZAQ_SPECIAL_ENTER)
        case 48: return UInt32(QAZAQ_SPECIAL_TAB)
        case 51: return UInt32(QAZAQ_SPECIAL_BACKSPACE)
        case 117: return UInt32(QAZAQ_SPECIAL_DELETE)
        case 53: return UInt32(QAZAQ_SPECIAL_ESCAPE)
        case 123...126: return UInt32(QAZAQ_SPECIAL_ARROW)
        case 115: return UInt32(QAZAQ_SPECIAL_HOME)
        case 119: return UInt32(QAZAQ_SPECIAL_END)
        case 116: return UInt32(QAZAQ_SPECIAL_PAGE_UP)
        case 121: return UInt32(QAZAQ_SPECIAL_PAGE_DOWN)
        default: return nil
        }
    }

    /// Physical ANSI key positions as unmodified US characters. The engine
    /// maps them to Latin rules or to the Russian ЙЦУКЕН layout itself, so
    /// the result never depends on the user's other installed layouts.
    private static let physicalKeys: [UInt16: String] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f", 5: "g",
        4: "h", 34: "i", 38: "j", 40: "k", 37: "l", 46: "m",
        45: "n", 31: "o", 35: "p", 12: "q", 15: "r", 1: "s",
        17: "t", 32: "u", 9: "v", 13: "w", 7: "x", 16: "y", 6: "z",
        43: ",", 47: ".", 44: "/",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        27: "-", 24: "=", 33: "[", 30: "]", 42: "\\",
        41: ";", 39: "'", 50: "`", 10: "`",
    ]
}
