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
}

private enum InstallerStage {
    case welcome
    case installing
    case needsLoginRefresh
    case needsActivation
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
    @Published private(set) var detail =
        "Орнату алдында жұмысыңызды сақтаңыз. Алғашқы орнатудан кейін macOS жүйеден шығып, қайта кіруді сұрауы мүмкін."

    private let fileManager = FileManager.default

    init() {
        refreshState()
    }

    var primaryButtonTitle: String {
        switch stage {
        case .welcome:
            return hasLegacySystemInstallation ? "Жаңарту" : "Орнату"
        case .installing:
            return "Орнатылуда…"
        case .needsLoginRefresh:
            return "Қайта тексеру"
        case .needsActivation:
            return "QazaqType-ты қосу"
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
            return "macOS QazaqType-ты енгізу әдістері тізіміне әлі қоспады. Жүйеден шығып, қайта кірген соң орнатқышты қайта ашыңыз."
        case .needsActivation:
            return "macOS растау сұрағын көрсетсе, «Рұқсат ету» түймесін басыңыз немесе пернетақта баптауларынан қолмен қосыңыз."
        case .ready:
            return "Енді мәзір жолағынан QazaqType-ты таңдауға болады."
        case .failed:
            return "Төмендегі қатені тексеріп, түзеткеннен кейін қайталаңыз."
        }
    }

    func runPrimaryAction() {
        switch stage {
        case .welcome, .failed:
            install()
        case .needsLoginRefresh:
            refreshState()
            if isRegistered {
                activate()
            }
        case .needsActivation:
            activate()
        case .ready:
            refreshState()
        case .installing:
            break
        }
    }

    func install() {
        stage = .installing
        detail = "QazaqType дайындалуда…"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            do {
                let sourceURL = try self.embeddedInputMethodURL()
                if self.hasLegacySystemInstallation {
                    self.detail =
                        "Ескі жүйелік нұсқа табылды. Оны көшіру үшін әкімші рұқсаты сұралуда…"
                    try self.migrateLegacySystemInstallation()
                }
                let destinationURL = try self.installDestination(
                    embeddedSource: sourceURL
                )

                let registerStatus = TISRegisterInputSource(
                    destinationURL as CFURL
                )
                guard registerStatus == noErr else {
                    throw InstallerError.message(
                        "Енгізу әдісін тіркеу сәтсіз аяқталды. Қате коды: \(registerStatus)"
                    )
                }

                self.isInstalled = true
                self.detail = "QazaqType көшіріліп, тіркелді. macOS енгізу көздерін жаңартуда…"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.refreshState()
                    if self.isRegistered {
                        self.activate()
                    } else {
                        self.stage = .needsLoginRefresh
                        self.detail =
                            "Файл дұрыс орнатылды, бірақ ағымдағы сеанс жаңа енгізу режимін әлі жүктемеді."
                    }
                }
            } catch {
                self.fail(error.localizedDescription)
            }
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let mode = self.inputMode() {
                _ = TISEnableInputSource(mode)
            }
            self.refreshState()
            guard self.isEnabled, let refreshedSource = self.inputMode()
            else {
                self.stage = .needsActivation
                self.detail =
                    "macOS әлі растаған жоқ. Жүйелік сұрауда «Рұқсат ету» пәрменін таңдап, қайта көріңіз."
                return
            }

            let selectStatus = TISSelectInputSource(refreshedSource)
            self.refreshState()
            self.stage = .ready
            if selectStatus == noErr {
                self.detail = "Орнату, қосу және ауыстыру сәтті аяқталды."
            } else {
                self.detail =
                    "QazaqType қосылды. Оны мәзір жолағындағы енгізу әдістерінен таңдаңыз."
            }
        }
    }

    func refreshState() {
        hasLegacySystemInstallation =
            isKnownInputMethodBundle(at: systemInputMethodURL)
        let hasUserInstallation =
            isKnownInputMethodBundle(at: userInputMethodURL)
        isInstalled = hasLegacySystemInstallation || hasUserInstallation

        if hasLegacySystemInstallation && !hasUserInstallation {
            isRegistered = false
            isEnabled = false
            isSelected = false
            if stage != .installing && stage != .failed {
                stage = .welcome
                detail =
                    "Ескі жүйелік нұсқа табылды. Жаңарту кезінде macOS әкімші рұқсатын сұрайды."
            }
            return
        }

        let mode = inputMode()
        let mainSource = mainInputSource()
        guard mode != nil || mainSource != nil else {
            isRegistered = false
            isEnabled = false
            isSelected = false
            if stage != .installing && stage != .failed {
                stage = isInstalled ? .needsLoginRefresh : .welcome
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

        if stage != .installing && stage != .failed {
            stage = isEnabled ? .ready : .needsActivation
        }
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

    private func installDestination(embeddedSource: URL) throws -> URL {
        let parentURL = userInputMethodURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parentURL,
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: userInputMethodURL.path) {
            guard isKnownInputMethodBundle(at: userInputMethodURL)
            else {
                throw InstallerError.message(
                    "Орнату орнында аттас басқа қолданба бар. Оны қорғау үшін орнату тоқтатылды."
                )
            }
            try fileManager.removeItem(at: userInputMethodURL)
        }

        try fileManager.copyItem(
            at: embeddedSource,
            to: userInputMethodURL
        )
        return userInputMethodURL
    }

    private func migrateLegacySystemInstallation() throws {
        guard isKnownInputMethodBundle(at: systemInputMethodURL)
        else {
            return
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        let backupURL = URL(
            fileURLWithPath:
                "/Users/Shared/QazaqType-system-backup-"
                + formatter.string(from: Date())
                + ".app",
            isDirectory: true
        )
        let command =
            "/bin/mv "
            + shellQuoted(systemInputMethodURL.path)
            + " "
            + shellQuoted(backupURL.path)
        let source =
            "do shell script \""
            + appleScriptQuoted(command)
            + "\" with administrator privileges"
        guard let script = NSAppleScript(source: source) else {
            throw InstallerError.message("Жүйелік рұқсат сұрауын дайындау мүмкін болмады.")
        }

        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        if let error {
            let message =
                error[NSAppleScript.errorMessage] as? String
                ?? "Әкімші рұқсаты берілмеді."
            throw InstallerError.message(message)
        }

        guard !fileManager.fileExists(atPath: systemInputMethodURL.path) else {
            throw InstallerError.message("Ескі жүйелік нұсқаны көшіру мүмкін болмады. Қайталап көріңіз.")
        }
        detail = "Ескі нұсқа \(backupURL.path) мекенжайына сақталды. Жаңа нұсқа орнатылуда…"
        hasLegacySystemInstallation = false
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
