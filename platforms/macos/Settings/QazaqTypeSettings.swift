import SwiftUI

@main
enum QazaqTypeSettingsMain {
    static func main() {
        if CommandLine.arguments.contains(BackgroundUpdateCheck.argument) {
            BackgroundUpdateCheck.run()
        } else {
            QazaqTypeSettingsApp.main()
        }
    }
}

struct QazaqTypeSettingsApp: App {
    @StateObject private var model = SettingsModel()

    var body: some Scene {
        WindowGroup {
            SettingsRootView(model: model)
                .frame(minWidth: 560, minHeight: 470)
        }
        .windowStyle(.titleBar)
    }
}

private final class SettingsModel: ObservableObject {
    @Published var enabled: Bool
    @Published var defaultMode: UInt32
    @Published var thresholdMilliseconds: UInt64
    @Published var showModeNotification: Bool
    @Published var layout: UInt32
    @Published var checkForUpdates: Bool
    @Published var language: QazaqLanguage {
        didSet { QazaqPreferences.saveLanguage(language) }
    }

    init() {
        let config = QazaqPreferences.load()
        enabled = config.enabled
        defaultMode = config.defaultMode
        thresholdMilliseconds = config.thresholdMilliseconds
        showModeNotification = config.showModeNotification
        layout = config.layout
        checkForUpdates = config.checkForUpdates
        language = QazaqPreferences.loadLanguage()
    }

    func save() {
        QazaqPreferences.save(
            QazaqRuntimeConfig(
                enabled: enabled,
                defaultMode: defaultMode,
                thresholdMilliseconds: thresholdMilliseconds,
                showModeNotification: showModeNotification,
                layout: layout,
                checkForUpdates: checkForUpdates
            )
        )
    }

    func restoreDefaults() {
        enabled = true
        defaultMode = 0
        thresholdMilliseconds = 400
        showModeNotification = true
        layout = QazaqPreferences.latinLayout
        checkForUpdates = true
        save()
    }
}

private struct SettingsRootView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label(L(.tabGeneral), systemImage: "gearshape") }
            InputRulesView(layout: model.layout)
                .tabItem { Label(L(.tabRules), systemImage: "character.book.closed") }
            PrivacyView()
                .tabItem { Label(L(.tabPrivacy), systemImage: "hand.raised") }
            AboutView()
                .tabItem { Label("QazaqType", systemImage: "info.circle") }
        }
        .padding(20)
        // Rebuild every view when the language changes so all text updates.
        .id(model.language)
        .navigationTitle(L(.windowTitle))
        .onAppear {
            NSApp.windows.first?.title = L(.windowTitle)
        }
        .onChange(of: model.language) { _ in
            NSApp.windows.first?.title = L(.windowTitle)
        }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Picker(L(.language), selection: $model.language) {
                ForEach(QazaqLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .frame(maxWidth: 320)

            Divider()

            Toggle(L(.enableConversion), isOn: $model.enabled)
                .onChange(of: model.enabled) { _ in model.save() }

            Picker(L(.keyboard), selection: $model.layout) {
                Text(L(.keyboardLatin)).tag(QazaqPreferences.latinLayout)
                Text(L(.keyboardCyrillic)).tag(QazaqPreferences.cyrillicLayout)
            }
            .pickerStyle(.segmented)
            .onChange(of: model.layout) { _ in model.save() }

            Picker(L(.defaultMode), selection: $model.defaultMode) {
                Text(L(.modeKazakh)).tag(UInt32(0))
                Text(L(.modeEnglish)).tag(UInt32(1))
            }
            .pickerStyle(.segmented)
            .onChange(of: model.defaultMode) { _ in model.save() }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L(.doublePressTime))
                    Spacer()
                    Text("\(model.thresholdMilliseconds) ms")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.thresholdMilliseconds) },
                        set: {
                            model.thresholdMilliseconds = UInt64($0.rounded())
                            model.save()
                        }
                    ),
                    in: 200...800,
                    step: 10
                )
                HStack {
                    Text("200 ms")
                    Spacer()
                    Text("800 ms")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Toggle(
                L(.showModeNotification),
                isOn: $model.showModeNotification
            )
            .onChange(of: model.showModeNotification) { _ in model.save() }

            Toggle(
                L(.checkUpdatesDaily),
                isOn: $model.checkForUpdates
            )
            .onChange(of: model.checkForUpdates) { _ in model.save() }

            HStack {
                Spacer()
                Button(L(.restoreDefaults)) {
                    model.restoreDefaults()
                }
            }
        }
        .padding()
    }
}

private struct InputRulesView: View {
    let layout: UInt32

    private let latinPairs = [
        ("aa", "ә"), ("ss", "ш"), ("cc", "ч"), ("zz", "ж"),
        ("nn", "ң"), ("oo", "ө"), ("uu", "ү"), ("yy", "і"),
        ("gg", "ғ"), ("ee", "э"), (",,", "я"), ("..", "ю"),
        ("//", "ь"),
    ]

    private let cyrillicPairs = [
        ("аа", "ә"), ("ии", "і"), ("оо", "ө"), ("нн", "ң"),
        ("хх", "һ"), ("уу", "ұ / ү"), ("к", "қ / к"), ("г", "ғ / г"),
        ("кк", "к"), ("гг", "г"), ("ккк", "ққ"), ("ннн", "нн"),
        ("иии", "иі"), ("ууу", "ұ ⇄ ү"),
    ]

    private var isCyrillic: Bool {
        layout == QazaqPreferences.cyrillicLayout
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L(.rulesTitle))
                .font(.title2.bold())
            Text(
                isCyrillic
                    ? L(.rulesCyrillic)
                    : L(.rulesLatin)
            )
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 120), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(isCyrillic ? cyrillicPairs : latinPairs, id: \.0) { pair in
                        HStack {
                            Text(pair.0).font(.system(.body, design: .monospaced))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                            Text(pair.1).font(.title3)
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            Text(
                isCyrillic
                    ? L(.rulesToggleCyrillic)
                    : L(.rulesToggleLatin)
            )
            .font(.headline)
        }
        .padding()
    }
}

private struct PrivacyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L(.privacyTitle), systemImage: "checkmark.shield")
                .font(.title2.bold())
            Text(L(.privacyOffline))
            Text(L(.privacyUpdates))
            Text(L(.privacyNothingStored))
            Text(L(.privacySecureInput))
            Spacer()
        }
        .padding()
    }
}

private struct AboutView: View {
    private var appIcon: NSImage {
        guard
            let url = Bundle.main.url(
                forResource: "QazaqType",
                withExtension: "tiff"
            ),
            let icon = NSImage(contentsOf: url)
        else {
            return NSImage()
        }
        return icon
    }

    @State private var isChecking = false
    @State private var status: String?

    private func checkNow() {
        isChecking = true
        status = nil
        let installed = QazaqUpdater.installedVersion
        QazaqUpdater.fetchLatest { result in
            switch result {
            case let .success(release)
                where QazaqUpdater.isVersion(release.version, newerThan: installed):
                QazaqUpdater.offer(release, installed: installed) {
                    isChecking = false
                }
            case .success, .failure(QazaqUpdater.Failure.noRelease):
                isChecking = false
                status = L(.aboutUpToDate)
            case .failure:
                isChecking = false
                status = L(.aboutFailed)
            }
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        return L(.aboutVersion, short)
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 72, height: 72)
            Text("QazaqType").font(.largeTitle.bold())
            Text(version)
            Text(L(.aboutTagline))
                .foregroundColor(.secondary)
            Button(isChecking ? L(.aboutChecking) : L(.aboutCheck)) {
                checkNow()
            }
            .disabled(isChecking)
            if let status {
                Text(status)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}
