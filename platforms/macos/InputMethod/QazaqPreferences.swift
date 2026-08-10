import Foundation

struct QazaqRuntimeConfig {
    let enabled: Bool
    let defaultMode: UInt32
    let thresholdMilliseconds: UInt64
    let showModeNotification: Bool
}

enum QazaqPreferences {
    static let suiteName = "kz.qazaqtype.inputmethod.shared"
    static let changedNotification = Notification.Name(
        "kz.qazaqtype.settings.changed"
    )

    private enum Key {
        static let enabled = "enabled"
        static let defaultMode = "defaultMode"
        static let thresholdMilliseconds = "doublePressThresholdMilliseconds"
        static let showModeNotification = "showModeNotification"
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

        return QazaqRuntimeConfig(
            enabled: enabled,
            defaultMode: mode == "EN" ? 1 : 0,
            thresholdMilliseconds: UInt64(threshold),
            showModeNotification: showNotification
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
        showModeNotification: true
    )
}

