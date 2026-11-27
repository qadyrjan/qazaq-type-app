import SwiftUI

@main
struct QazaqTypeSettingsApp: App {
    @StateObject private var model = SettingsModel()

    var body: some Scene {
        WindowGroup {
            SettingsRootView(model: model)
                .frame(minWidth: 560, minHeight: 430)
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

    init() {
        let config = QazaqPreferences.load()
        enabled = config.enabled
        defaultMode = config.defaultMode
        thresholdMilliseconds = config.thresholdMilliseconds
        showModeNotification = config.showModeNotification
        layout = config.layout
    }

    func save() {
        QazaqPreferences.save(
            QazaqRuntimeConfig(
                enabled: enabled,
                defaultMode: defaultMode,
                thresholdMilliseconds: thresholdMilliseconds,
                showModeNotification: showModeNotification,
                layout: layout
            )
        )
    }

    func restoreDefaults() {
        enabled = true
        defaultMode = 0
        thresholdMilliseconds = 400
        showModeNotification = true
        layout = QazaqPreferences.latinLayout
        save()
    }
}

private struct SettingsRootView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("Жалпы", systemImage: "gearshape") }
            InputRulesView(layout: model.layout)
                .tabItem { Label("Ережелер", systemImage: "character.book.closed") }
            PrivacyView()
                .tabItem { Label("Құпиялық", systemImage: "hand.raised") }
            AboutView()
                .tabItem { Label("QazaqType", systemImage: "info.circle") }
        }
        .padding(20)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Toggle("Қазақша түрлендіруді қосу", isOn: $model.enabled)
                .onChange(of: model.enabled) { _ in model.save() }

            Picker("Пернетақта", selection: $model.layout) {
                Text("Латын (q → қ)").tag(QazaqPreferences.latinLayout)
                Text("Орысша ЙЦУКЕН (аа → ә)").tag(QazaqPreferences.cyrillicLayout)
            }
            .pickerStyle(.segmented)
            .onChange(of: model.layout) { _ in model.save() }

            Picker("Бастапқы режим", selection: $model.defaultMode) {
                Text("KZ — Қазақша").tag(UInt32(0))
                Text("EN — English").tag(UInt32(1))
            }
            .pickerStyle(.segmented)
            .onChange(of: model.defaultMode) { _ in model.save() }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Қос басу уақыты")
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
                "Режим ауысқанда хабарлама көрсету",
                isOn: $model.showModeNotification
            )
            .onChange(of: model.showModeNotification) { _ in model.save() }

            HStack {
                Spacer()
                Button("Әдепкі баптауларды қалпына келтіру") {
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
            Text("Қос басу ережелері")
                .font(.title2.bold())
            Text(
                isCyrillic
                    ? "Орыс әріптері өз орнында. Қазақ әрпі үшін орнына жазып жүрген әріпті екі рет басыңыз. Сөз бос орын басқанда бекітіледі, ал қ, ғ, ұ, ү сөздің дауыстыларына қарап өзі таңдалады."
                    : "Екі бірдей пернені белгіленген уақыт ішінде басыңыз."
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
                    ? "йй (латынша qq) — KZ және EN режимдерін ауыстырады"
                    : "qq — сөз басында KZ және EN режимдерін ауыстырады"
            )
            .font(.headline)
        }
        .padding()
    }
}

private struct PrivacyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Барлық түрлендіру осы Mac ішінде орындалады", systemImage: "checkmark.shield")
                .font(.title2.bold())
            Text("QazaqType интернет байланысын қажет етпейді.")
            Text("Енгізілген мәтін, пернелер және жазу тарихы сақталмайды немесе серверге жіберілмейді.")
            Text("Құпиясөз өрістері мен қауіпсіз енгізу аймақтарында macOS шектеулері толық сақталады.")
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

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 72, height: 72)
            Text("QazaqType").font(.largeTitle.bold())
            Text("0.1.3 development")
            Text("Қазақ тіліне арналған офлайн жүйелік енгізу әдісі")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}
