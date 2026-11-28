import AppKit
import Carbon
import SwiftUI

private enum InstallerConstants {
    static let inputMethodBundleIdentifier =
        "kz.qazaqtype.inputmethod.QazaqType"
    static let inputModeIdentifier =
        "kz.qazaqtype.inputmethod.QazaqType.Kazakh"
    static let legacyInputMethodBundleIdentifier =
        "kz.qazaqtype.inputmethod"
    static let settingsBundleIdentifier = "kz.qazaqtype.settings"
    static let lsregister =
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
}

private enum InstallerStage {
    case welcome
    case installing
    case needsLoginRefresh
    case needsActivation
    case updateAvailable
    case ready
    case failed
}

private final class InstallerModel: ObservableObject {
    @Published private(set) var stage: InstallerStage = .welcome
    @Published private(set) var isInstalled = false
    @Published private(set) var isRegistered = false
    @Published private(set) var isEnabled = false
    @Published private(set) var isSelected = false
    @Published private(set) var hasLegacySystemInstallation = false
    @Published private(set) var installedVersion: String?
    @Published private(set) var embeddedVersion: String?
    private var isUpdating = false
    @Published private(set) var detail =
        "Орнату алдында жұмысыңызды сақтаңыз. Алғашқы орнатудан кейін macOS жүйеден шығып, қайта кіруді сұрауы мүмкін."

    private let fileManager = FileManager.default

    init() {
        refreshState()
    }

    var primaryButtonTitle: String {
        switch stage {
        case .welcome:
            if hasLegacySystemInstallation {
                return "Жаңарту"
            }
            return isInstalled ? "Қайта орнату" : "Орнату"
        case .installing:
            return "Орнатылуда…"
        case .needsLoginRefresh:
            return "Қайта орнату"
        case .needsActivation:
            return "QazaqType-ты қосу"
        case .updateAvailable:
            return "Жаңарту"
        case .ready:
            return "Қайта тексеру"
        case .failed:
            return "Қайталау"
        }
    }

    var canRunPrimaryAction: Bool {
        stage != .installing
    }

    var stageTitle: String {
        switch stage {
        case .welcome:
            return "QazaqType-қа қош келдіңіз"
        case .installing:
            return "Енгізу әдісі орнатылуда"
        case .needsLoginRefresh:
            return "Жүйеге қайта кіру қажет"
        case .needsActivation:
            return "Енгізу әдісін қосу"
        case .updateAvailable:
            return "Жаңа нұсқа қолжетімді"
        case .ready:
            return "QazaqType пайдалануға дайын"
        case .failed:
            return "Орнату аяқталмады"
        }
    }

    var stageDescription: String {
        switch stage {
        case .welcome:
            return "Intel және Apple чипті Mac компьютерлеріне арналған дербес қазақша енгізу әдісі."
        case .installing:
            return "QazaqType көшіріліп, тіркеліп және macOS жүйесінде қосылуда."
        case .needsLoginRefresh:
            return "macOS QazaqType-ты енгізу әдістері тізіміне әлі қоспады. Алдымен «Қайта орнату» түймесін басыңыз. Көмектеспесе, жүйеден шығып, қайта кіріңіз де, орнатқышты қайта ашыңыз."
        case .needsActivation:
            return "macOS растау сұрағын көрсетсе, «Рұқсат ету» түймесін басыңыз немесе пернетақта баптауларынан қолмен қосыңыз."
        case .updateAvailable:
            return "Орнатылған нұсқа: \(installedVersion ?? "—"). Жаңа нұсқа: \(embeddedVersion ?? "—"). Баптауларыңыз сақталады, жүйеден шығудың қажеті жоқ."
        case .ready:
            return "Енді мәзір жолағынан QazaqType-ты таңдауға болады."
        case .failed:
            return "Төмендегі қатені тексеріп, түзеткеннен кейін қайталаңыз."
        }
    }

    func runPrimaryAction() {
        switch stage {
        case .welcome, .failed, .updateAvailable, .needsLoginRefresh:
            // A copy that macOS has not picked up is reinstalled from scratch:
            // that also clears quarantine flags and stale registrations.
            install()
        case .needsActivation:
            activate()
        case .ready:
            refreshState()
        case .installing:
            break
        }
    }

    func install() {
        isUpdating = stage == .updateAvailable
        stage = .installing
        detail = isUpdating ? "QazaqType жаңартылуда…" : "QazaqType дайындалуда…"

        // File work runs off the main thread so the window stays responsive.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let sourceURL = try self.embeddedInputMethodURL()
                self.setDetail("Ескі нұсқалар тоқтатылып, тазалануда…")
                self.stopRunningInputMethod()
                try self.removeOldCopies()
                self.setDetail("Жаңа нұсқа көшірілуде…")
                let destinationURL = try self.copyInputMethod(from: sourceURL)
                DispatchQueue.main.async {
                    self.register(destinationURL)
                }
            } catch {
                DispatchQueue.main.async {
                    self.fail(error.localizedDescription)
                }
            }
        }
    }

    private func register(_ destinationURL: URL) {
        LSRegisterURL(destinationURL as CFURL, true)
        let registerStatus = TISRegisterInputSource(destinationURL as CFURL)
        guard registerStatus == noErr else {
            fail("Енгізу әдісін тіркеу сәтсіз аяқталды. Қате коды: \(registerStatus)")
            return
        }
        disableLegacyInputSources()

        isInstalled = true
        detail = "QazaqType көшіріліп, тіркелді. macOS енгізу көздерін жаңартуда…"
        waitForRegistration(of: destinationURL, attempt: 0)
    }

    /// macOS publishes a new input source asynchronously, sometimes only
    /// after several seconds, so poll instead of checking once.
    private func waitForRegistration(of destinationURL: URL, attempt: Int) {
        if mainInputSource() != nil || inputMode() != nil {
            refreshState()
            activate()
            return
        }
        if attempt == 4 {
            // A fresh process has no cached input source list; registering
            // from the input method itself also nudges the system.
            runInputMethodCommand(destinationURL, "--register-input-source")
        }
        guard attempt < 24 else {
            refreshState()
            stage = .needsLoginRefresh
            detail =
                "Файл дұрыс орнатылды, бірақ ағымдағы сеанс жаңа енгізу режимін әлі жүктемеді."
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.waitForRegistration(of: destinationURL, attempt: attempt + 1)
        }
    }

    func activate() {
        refreshState()
        guard let source = mainInputSource() ?? inputMode() else {
            stage = .needsLoginRefresh
            detail = "Ағымдағы сеанс QazaqType енгізу режимін әлі таппады."
            return
        }

        stage = .installing
        detail = "macOS жүйесінен QazaqType-ты қосу сұралуда…"
        let enableStatus = TISEnableInputSource(source)
        guard enableStatus == noErr else {
            fail("Енгізу әдісін қосу сәтсіз аяқталды. Қате коды: \(enableStatus)")
            return
        }
        waitForActivation(attempt: 0)
    }

    private func waitForActivation(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let mode = self.inputMode() {
                _ = TISEnableInputSource(mode)
            }
            self.refreshState()
            guard self.isEnabled, let refreshedSource = self.inputMode()
            else {
                if attempt < 8 {
                    self.stage = .installing
                    self.waitForActivation(attempt: attempt + 1)
                    return
                }
                self.stage = .needsActivation
                self.detail =
                    "macOS әлі растаған жоқ. Жүйелік сұрауда «Рұқсат ету» пәрменін таңдап, қайта көріңіз."
                return
            }

            let selectStatus = TISSelectInputSource(refreshedSource)
            self.refreshState()
            self.stage = .ready
            if self.isUpdating {
                self.isUpdating = false
                self.detail = "QazaqType \(self.installedVersion ?? "") нұсқасына жаңартылды."
            } else if selectStatus == noErr {
                self.detail = "Орнату, қосу және ауыстыру сәтті аяқталды."
            } else {
                self.detail =
                    "QazaqType қосылды. Оны мәзір жолағындағы енгізу әдістерінен таңдаңыз."
            }
        }
    }

    private func setDetail(_ value: String) {
        DispatchQueue.main.async {
            self.detail = value
        }
    }

    func refreshState() {
        hasLegacySystemInstallation =
            isKnownInputMethodBundle(at: systemInputMethodURL)
        let hasUserInstallation =
            isKnownInputMethodBundle(at: userInputMethodURL)
        isInstalled = hasLegacySystemInstallation || hasUserInstallation
        installedVersion = hasUserInstallation
            ? shortVersion(at: userInputMethodURL)
            : nil
        embeddedVersion = (try? embeddedInputMethodURL()).flatMap(shortVersion(at:))
        let canRefreshStage = stage != .installing && stage != .failed

        if hasLegacySystemInstallation && !hasUserInstallation {
            isRegistered = false
            isEnabled = false
            isSelected = false
            if canRefreshStage {
                stage = .welcome
                detail =
                    "Ескі жүйелік нұсқа табылды. Жаңарту кезінде macOS әкімші рұқсатын сұрайды."
            }
            return
        }

        // An older copy is always replaced, whether or not macOS loaded it.
        let isOutdated: Bool = {
            guard hasUserInstallation, let embeddedVersion else {
                return false
            }
            guard let installedVersion else {
                return true
            }
            return isVersion(embeddedVersion, newerThan: installedVersion)
        }()

        let mode = inputMode()
        let mainSource = mainInputSource()
        guard mode != nil || mainSource != nil else {
            isRegistered = false
            isEnabled = false
            isSelected = false
            if canRefreshStage {
                if isOutdated {
                    stage = .updateAvailable
                    detail = "Жаңарту ескі нұсқаны толық алмастырады. Пернетақта таңдауыңыз бен басқа баптаулар өзгермейді."
                } else if hasUserInstallation && isQuarantined(userInputMethodURL) {
                    // Copied by an older installer with the download flag,
                    // which keeps macOS from loading the input method.
                    stage = .welcome
                    detail = "Орнатылған көшірмені macOS бұғаттап тұр. «Қайта орнату» түймесін басыңыз."
                } else {
                    stage = isInstalled ? .needsLoginRefresh : .welcome
                }
            }
            return
        }

        isRegistered = true
        let source = mode ?? mainSource!
        // TISEnableInputSource can report an enabled value from the process-local
        // TIS cache before macOS has persisted it for System Settings.  Only call
        // the installation complete after HIToolbox contains the input mode.
        isEnabled = boolProperty(
            source,
            key: kTISPropertyInputSourceIsEnabled
        ) && isPersistedInEnabledInputSources()
        isSelected = boolProperty(
            source,
            key: kTISPropertyInputSourceIsSelected
        )

        if canRefreshStage {
            if isOutdated {
                stage = .updateAvailable
                detail = "Жаңарту ескі нұсқаны толық алмастырады. Пернетақта таңдауыңыз бен басқа баптаулар өзгермейді."
            } else {
                stage = isEnabled ? .ready : .needsActivation
            }
        }
    }

    /// Reads the version from disk; `Bundle` caches Info.plist per path, so
    /// it would keep reporting the replaced version after an update.
    private func shortVersion(at url: URL) -> String? {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: plist)?["CFBundleShortVersionString"] as? String
    }

    private func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        func parts(_ value: String) -> [Int] {
            value.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let lhs = parts(candidate)
        let rhs = parts(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }

    /// Quits every running copy (input method, its settings helper, and the
    /// pre-1.0 bundle) so no old code stays loaded after the files change.
    private func stopRunningInputMethod() {
        let identifiers = [
            InstallerConstants.inputMethodBundleIdentifier,
            InstallerConstants.legacyInputMethodBundleIdentifier,
            InstallerConstants.settingsBundleIdentifier,
        ]
        let running = identifiers.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        }
        for application in running {
            application.terminate()
        }
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline && running.contains(where: { !$0.isTerminated }) {
            Thread.sleep(forTimeInterval: 0.1)
        }
        for application in running where !application.isTerminated {
            application.forceTerminate()
        }
        // Input methods started by the system are not always listed above.
        _ = runTool("/usr/bin/pkill", ["-9", "-f", "/Input Methods/QazaqType.app/Contents/"])
        Thread.sleep(forTimeInterval: 0.3)
    }

    func openKeyboardSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.keyboard",
        ]
        for value in urls {
            if let url = URL(string: value),
               NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private var userInputMethodURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Input Methods", isDirectory: true)
            .appendingPathComponent("QazaqType.app", isDirectory: true)
    }

    private var systemInputMethodURL: URL {
        URL(
            fileURLWithPath: "/Library/Input Methods/QazaqType.app",
            isDirectory: true
        )
    }

    private func embeddedInputMethodURL() throws -> URL {
        guard let resourcesURL = Bundle.main.resourceURL else {
            throw InstallerError.message("Орнатқыштың ресурстар қалтасы жоқ.")
        }
        let url = resourcesURL.appendingPathComponent(
            "QazaqType.app",
            isDirectory: true
        )
        guard bundleIdentifier(at: url)
            == InstallerConstants.inputMethodBundleIdentifier
        else {
            throw InstallerError.message(
                "Орнатқыштағы QazaqType.app толық емес немесе сәйкестендіргіші қате."
            )
        }
        return url
    }

    /// Removes every earlier QazaqType bundle: user and system copies (under
    /// any name), backups left by older installers, and their Launch
    /// Services records, which could otherwise start an old version.
    private func removeOldCopies() throws {
        let protected = Set(
            [(try? embeddedInputMethodURL())?.standardizedFileURL.path]
                .compactMap { $0 }
        )
        var removable: [URL] = []
        removable += knownBundles(in: userInputMethodURL.deletingLastPathComponent())
        removable += knownBundles(in: systemInputMethodURL.deletingLastPathComponent())
        removable += knownBundles(in: URL(fileURLWithPath: "/Users/Shared", isDirectory: true)) {
            $0.hasPrefix("QazaqType")
        }
        removable = removable.filter { !protected.contains($0.standardizedFileURL.path) }

        var needsAdministrator: [URL] = []
        for url in removable {
            unregisterFromLaunchServices(url)
            do {
                try fileManager.removeItem(at: url)
            } catch {
                if fileManager.fileExists(atPath: url.path) {
                    needsAdministrator.append(url)
                }
            }
        }

        if !needsAdministrator.isEmpty {
            setDetail("Ескі жүйелік нұсқаны жою үшін әкімші рұқсаты сұралуда…")
            let command = "/bin/rm -rf "
                + needsAdministrator.map { shellQuoted($0.path) }.joined(separator: " ")
            try runAsAdministrator(command)
            if needsAdministrator.contains(where: { fileManager.fileExists(atPath: $0.path) }) {
                throw InstallerError.message("Ескі нұсқаны жою мүмкін болмады. Қайталап көріңіз.")
            }
        }

        // Copies elsewhere (Trash, an old installer in Applications, a mounted
        // disk image) stay on disk but must not be launched by bundle ID.
        for identifier in [
            InstallerConstants.inputMethodBundleIdentifier,
            InstallerConstants.legacyInputMethodBundleIdentifier,
        ] {
            let urls = LSCopyApplicationURLsForBundleIdentifier(identifier as CFString, nil)?
                .takeRetainedValue() as? [URL] ?? []
            for url in urls where !protected.contains(url.standardizedFileURL.path) {
                unregisterFromLaunchServices(url)
            }
        }
        DispatchQueue.main.sync {
            self.hasLegacySystemInstallation = false
        }
    }

    private func knownBundles(
        in directory: URL,
        where nameMatches: (String) -> Bool = { _ in true }
    ) -> [URL] {
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { $0.hasSuffix(".app") && nameMatches($0) }
            .map { directory.appendingPathComponent($0, isDirectory: true) }
            .filter(isKnownInputMethodBundle(at:))
    }

    private func copyInputMethod(from sourceURL: URL) throws -> URL {
        let destinationURL = userInputMethodURL
        let parentURL = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parentURL,
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw InstallerError.message(
                "Орнату орнында аттас басқа қолданба бар. Оны қорғау үшін орнату тоқтатылды."
            )
        }

        // `--noqtn` drops the download quarantine flag: macOS does not load a
        // quarantined input method from ~/Library/Input Methods.
        let (copyStatus, copyOutput) = runTool(
            "/usr/bin/ditto",
            ["--noqtn", sourceURL.path, destinationURL.path]
        )
        guard copyStatus == 0 else {
            throw InstallerError.message("Енгізу әдісін көшіру мүмкін болмады: \(copyOutput)")
        }
        _ = runTool("/usr/bin/xattr", ["-dr", "com.apple.quarantine", destinationURL.path])

        let (verifyStatus, verifyOutput) = runTool(
            "/usr/bin/codesign",
            ["--verify", "--deep", "--strict", destinationURL.path]
        )
        guard verifyStatus == 0 else {
            throw InstallerError.message("Көшірілген енгізу әдісінің қолтаңбасы жарамсыз: \(verifyOutput)")
        }

        // The input source server watches the folder's modification date.
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: parentURL.path
        )
        return destinationURL
    }

    private func isQuarantined(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.quarantine", nil, 0, 0, 0) >= 0
    }

    private func unregisterFromLaunchServices(_ url: URL) {
        _ = runTool(InstallerConstants.lsregister, ["-u", url.path])
    }

    private func disableLegacyInputSources() {
        let filter = [
            kTISPropertyBundleID as String:
                InstallerConstants.legacyInputMethodBundleIdentifier
        ] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true) else {
            return
        }
        for source in list.takeRetainedValue() as! [TISInputSource] {
            _ = TISDisableInputSource(source)
        }
    }

    private func runInputMethodCommand(_ bundleURL: URL, _ argument: String) {
        let executable = bundleURL.appendingPathComponent("Contents/MacOS/QazaqType").path
        DispatchQueue.global(qos: .userInitiated).async {
            _ = self.runTool(executable, [argument])
        }
    }

    private func runAsAdministrator(_ command: String) throws {
        let script = "do shell script \"" + appleScriptQuoted(command)
            + "\" with administrator privileges"
        let (status, output) = runTool("/usr/bin/osascript", ["-e", script])
        guard status == 0 else {
            throw InstallerError.message(
                output.contains("-128") ? "Әкімші рұқсаты берілмеді." : output
            )
        }
    }

    @discardableResult
    private func runTool(_ path: String, _ arguments: [String]) -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (process.terminationStatus, output)
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptQuoted(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func inputSource(identifier: String) -> TISInputSource? {
        guard let result = TISCreateInputSourceList(nil, true) else {
            return nil
        }
        return (result.takeRetainedValue() as! [TISInputSource]).first {
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

    private func mainInputSource() -> TISInputSource? {
        inputSource(
            identifier: InstallerConstants.inputMethodBundleIdentifier
        )
    }

    private func inputMode() -> TISInputSource? {
        inputSource(identifier: InstallerConstants.inputModeIdentifier)
    }

    private func boolProperty(
        _ source: TISInputSource,
        key: CFString
    ) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return false
        }
        return Unmanaged<CFBoolean>
            .fromOpaque(pointer)
            .takeUnretainedValue() == kCFBooleanTrue
    }

    private func isPersistedInEnabledInputSources() -> Bool {
        CFPreferencesAppSynchronize("com.apple.HIToolbox" as CFString)
        guard let value = CFPreferencesCopyAppValue(
            "AppleEnabledInputSources" as CFString,
            "com.apple.HIToolbox" as CFString
        ), let sources = value as? [[String: Any]] else {
            return false
        }

        return sources.contains { source in
            let bundleID = source["Bundle ID"] as? String
            let modeID = source["Input Mode"] as? String
            return bundleID == InstallerConstants.inputMethodBundleIdentifier
                && modeID == InstallerConstants.inputModeIdentifier
        }
    }

    private func bundleIdentifier(at url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }

    private func isKnownInputMethodBundle(at url: URL) -> Bool {
        guard let identifier = bundleIdentifier(at: url) else {
            return false
        }
        return identifier == InstallerConstants.inputMethodBundleIdentifier
            || identifier
                == InstallerConstants.legacyInputMethodBundleIdentifier
    }

    private func fail(_ message: String) {
        stage = .failed
        detail = message
        refreshInstallationFlagsOnly()
    }

    private func refreshInstallationFlagsOnly() {
        hasLegacySystemInstallation =
            isKnownInputMethodBundle(at: systemInputMethodURL)
        isInstalled = hasLegacySystemInstallation
            || isKnownInputMethodBundle(at: userInputMethodURL)
    }
}

private enum InstallerError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(value):
            return value
        }
    }
}

private struct StatusItem: View {
    let title: String
    let complete: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(
                systemName: complete
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .foregroundColor(complete ? .green : .secondary)
            Text(title)
                .foregroundColor(complete ? .primary : .secondary)
            Spacer()
        }
    }
}

private struct GuideStep: View {
    let number: Int
    let title: String
    let subtitle: String
    let active: Bool
    let complete: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        complete
                            ? Color.green
                            : active
                                ? Color.accentColor
                                : Color.secondary.opacity(0.18)
                    )
                    .frame(width: 30, height: 30)
                if complete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundColor(active ? .white : .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(
                        active || complete ? .primary : .secondary
                    )
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct InstallerRootView: View {
    @ObservedObject var model: InstallerModel
    @State private var testText = ""
    @State private var layout = QazaqPreferences.load().layout

    private var currentStep: Int {
        if model.isEnabled {
            return 3
        }
        if model.isInstalled {
            return 2
        }
        return 1
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(width: 780, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("QazaqType")
                        .font(.title2.bold())
                    Text("macOS орнату шебері")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            GuideStep(
                number: 1,
                title: "Орнату",
                subtitle: "Енгізу әдісін көшіру және тіркеу",
                active: currentStep == 1,
                complete: model.isInstalled
            )
            GuideStep(
                number: 2,
                title: "Жүйелік растау",
                subtitle: "macOS жүйесінде QazaqType-ты қосу",
                active: currentStep == 2,
                complete: model.isEnabled
            )
            GuideStep(
                number: 3,
                title: "Пайдалануды бастау",
                subtitle: "Мәзір жолағынан енгізу әдісін ауыстыру",
                active: currentStep == 3,
                complete: model.isSelected
            )

            Spacer()
            VStack(alignment: .leading, spacing: 7) {
                Text("Әзірлеуші")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Text("Qadyrjan Paizollauly")
                    .font(.caption)
                Link(
                    "qadyrjan.com",
                    destination: URL(string: "https://qadyrjan.com")!
                )
                .font(.caption)
                Link(
                    "Instagram · @qadyrjan.paizollauly",
                    destination: URL(
                        string: "https://www.instagram.com/qadyrjan.paizollauly/"
                    )!
                )
                .font(.caption)
            }
        }
        .padding(28)
        .frame(width: 260)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text(model.stageTitle)
                    .font(.system(size: 30, weight: .bold))
                Text(model.stageDescription)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                StatusItem(title: "Енгізу әдісінің файлы орнатылды", complete: model.isInstalled)
                StatusItem(title: "Енгізу режимі тіркелді", complete: model.isRegistered)
                StatusItem(title: "QazaqType қосылды", complete: model.isEnabled)
                StatusItem(title: "QazaqType таңдалды", complete: model.isSelected)
            }
            .padding(18)
            .background(Color.secondary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text(model.detail)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if model.isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Жылдам тексеру")
                            .font(.headline)
                        Spacer()
                        Picker("Пернетақта", selection: $layout) {
                            Text("Латын").tag(QazaqPreferences.latinLayout)
                            Text("Орысша ЙЦУКЕН").tag(QazaqPreferences.cyrillicLayout)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 240)
                        .onChange(of: layout) { value in
                            QazaqPreferences.saveLayout(value)
                        }
                    }
                    Text(
                        layout == QazaqPreferences.cyrillicLayout
                            ? "Мәзір жолағынан QazaqType-ты таңдап, Казакстан деп теріңіз"
                            : "Мәзір жолағынан QazaqType-ты таңдап, qazaq деп теріңіз"
                    )
                    .foregroundColor(.secondary)
                    TextField("Осы жерде тексеріңіз", text: $testText)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Spacer()

            HStack {
                Button("Пернетақта баптауларын ашу") {
                    model.openKeyboardSettings()
                }
                Spacer()
                if model.stage == .installing {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(model.primaryButtonTitle) {
                    model.runPrimaryAction()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canRunPrimaryAction)
            }
        }
        .padding(32)
    }
}

@main
private struct QazaqTypeInstallerApp: App {
    @StateObject private var model = InstallerModel()

    var body: some Scene {
        WindowGroup {
            InstallerRootView(model: model)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
