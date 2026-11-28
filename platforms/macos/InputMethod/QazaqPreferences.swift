import Foundation

struct QazaqRuntimeConfig {
    let enabled: Bool
    let defaultMode: UInt32
    let thresholdMilliseconds: UInt64
    let showModeNotification: Bool
    /// `QazaqPreferences.latinLayout` or `QazaqPreferences.cyrillicLayout`.
    let layout: UInt32
    /// Whether the settings helper looks for a new release once a day.
    let checkForUpdates: Bool
}

enum QazaqPreferences {
    static let suiteName = "kz.qazaqtype.inputmethod.shared"
    static let changedNotification = Notification.Name(
        "kz.qazaqtype.settings.changed"
    )

    /// Latin keys convert to Kazakh (`q` → `қ`, `aa` → `ә`).
    static let latinLayout: UInt32 = 0
    /// Russian ЙЦУКЕН keyboard; Kazakh letters by double press (`аа` → `ә`).
    static let cyrillicLayout: UInt32 = 1

    private enum Key {
        static let enabled = "enabled"
        static let defaultMode = "defaultMode"
        static let thresholdMilliseconds = "doublePressThresholdMilliseconds"
        static let showModeNotification = "showModeNotification"
        static let layout = "keyboardLayout"
        static let checkForUpdates = "checkForUpdates"
        static let lastUpdateCheck = "lastUpdateCheck"
        static let language = "interfaceLanguage"
    }

    private static let updateCheckInterval: TimeInterval = 24 * 60 * 60

    private enum LayoutValue {
        static let latin = "latin"
        static let cyrillic = "cyrillic"
    }

    static func load() -> QazaqRuntimeConfig {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return defaultsConfig
        }

        let enabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        let mode = defaults.object(forKey: Key.defaultMode) as? String ?? "KZ"
        let storedThreshold = defaults.object(
            forKey: Key.thresholdMilliseconds
        ) as? Int ?? 400
        let threshold = min(800, max(200, storedThreshold))
        let showNotification = defaults.object(
            forKey: Key.showModeNotification
        ) as? Bool ?? true
        let layout = defaults.object(forKey: Key.layout) as? String
        let checkForUpdates = defaults.object(
            forKey: Key.checkForUpdates
        ) as? Bool ?? true

        return QazaqRuntimeConfig(
            enabled: enabled,
            defaultMode: mode == "EN" ? 1 : 0,
            thresholdMilliseconds: UInt64(threshold),
            showModeNotification: showNotification,
            layout: layout == LayoutValue.cyrillic ? cyrillicLayout : latinLayout,
            checkForUpdates: checkForUpdates
        )
    }

    static func save(_ config: QazaqRuntimeConfig) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        defaults.set(config.enabled, forKey: Key.enabled)
        defaults.set(config.defaultMode == 1 ? "EN" : "KZ", forKey: Key.defaultMode)
        defaults.set(
            Int(config.thresholdMilliseconds),
            forKey: Key.thresholdMilliseconds
        )
        defaults.set(
            config.showModeNotification,
            forKey: Key.showModeNotification
        )
        defaults.set(layoutValue(config.layout), forKey: Key.layout)
        defaults.set(config.checkForUpdates, forKey: Key.checkForUpdates)
        postChanged()
    }

    /// Returns true at most once a day while update checks are enabled, and
    /// records the attempt so other input sessions do not repeat it.
    static func claimDailyUpdateCheck(now: Date = Date()) -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName),
              defaults.object(forKey: Key.checkForUpdates) as? Bool ?? true
        else {
            return false
        }
        let last = defaults.double(forKey: Key.lastUpdateCheck)
        guard now.timeIntervalSince1970 - last >= updateCheckInterval else {
            return false
        }
        defaults.set(now.timeIntervalSince1970, forKey: Key.lastUpdateCheck)
        return true
    }

    static func loadLanguage() -> QazaqLanguage {
        let value = UserDefaults(suiteName: suiteName)?
            .string(forKey: Key.language)
        return value.flatMap(QazaqLanguage.init(rawValue:)) ?? .system
    }

    /// Changes only the interface language, keeping every other setting.
    static func saveLanguage(_ language: QazaqLanguage) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        defaults.set(language.rawValue, forKey: Key.language)
        postChanged()
    }

    /// Changes only the keyboard layout, keeping every other setting.
    static func saveLayout(_ layout: UInt32) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        defaults.set(layoutValue(layout), forKey: Key.layout)
        postChanged()
    }

    private static func layoutValue(_ layout: UInt32) -> String {
        layout == cyrillicLayout ? LayoutValue.cyrillic : LayoutValue.latin
    }

    private static func postChanged() {
        DistributedNotificationCenter.default().postNotificationName(
            changedNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private static let defaultsConfig = QazaqRuntimeConfig(
        enabled: true,
        defaultMode: 0,
        thresholdMilliseconds: 400,
        showModeNotification: true,
        layout: latinLayout,
        checkForUpdates: true
    )
}
