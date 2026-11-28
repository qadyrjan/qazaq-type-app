import Foundation

/// Interface languages of the settings window, update alert and input menu.
enum QazaqLanguage: String, CaseIterable, Identifiable {
    case system
    case kazakh = "kk"
    case english = "en"
    case chinese = "zh"
    case russian = "ru"

    var id: String { rawValue }

    /// Each language is named in itself so anyone can find their own.
    var nativeName: String {
        switch self {
        case .system: return L(.languageSystem)
        case .kazakh: return "Қазақша"
        case .english: return "English"
        case .chinese: return "中文"
        case .russian: return "Русский"
        }
    }

    /// The concrete language to display: the chosen one, or the first macOS
    /// preferred language QazaqType supports, or Kazakh.
    var resolved: QazaqLanguage {
        guard self == .system else { return self }
        for identifier in Locale.preferredLanguages {
            let code = identifier.lowercased()
            if code.hasPrefix("kk") { return .kazakh }
            if code.hasPrefix("zh") { return .chinese }
            if code.hasPrefix("ru") { return .russian }
            if code.hasPrefix("en") { return .english }
        }
        return .kazakh
    }

    static var current: QazaqLanguage {
        QazaqPreferences.loadLanguage().resolved
    }
}

enum QazaqText {
    case windowTitle
    case tabGeneral, tabRules, tabPrivacy
    case language, languageSystem
    case enableConversion
    case keyboard, keyboardLatin, keyboardCyrillic
    case defaultMode, modeKazakh, modeEnglish
    case doublePressTime
    case showModeNotification
    case checkUpdatesDaily
    case restoreDefaults
    case rulesTitle, rulesLatin, rulesCyrillic
    case rulesToggleLatin, rulesToggleCyrillic
    case privacyTitle, privacyOffline, privacyUpdates, privacyNothingStored, privacySecureInput
    case aboutVersion, aboutTagline, aboutCheck, aboutChecking, aboutUpToDate, aboutFailed
    case updateTitle, updateBody, updateNow, updateLater
    case menuLatin, menuCyrillic, menuSettings
}

/// Returns `key` in the current interface language. `%@` placeholders are
/// filled from `arguments` in order.
func L(_ key: QazaqText, _ arguments: String...) -> String {
    let language = QazaqLanguage.current
    let table = qazaqStrings[key] ?? [:]
    var text = table[language] ?? table[.kazakh] ?? ""
    for argument in arguments {
        guard let range = text.range(of: "%@") else { break }
        text.replaceSubrange(range, with: argument)
    }
    return text
}

private let qazaqStrings: [QazaqText: [QazaqLanguage: String]] = [
    .windowTitle: [
        .kazakh: "QazaqType баптаулары",
        .english: "QazaqType Settings",
        .chinese: "QazaqType 设置",
        .russian: "Настройки QazaqType",
    ],
    .tabGeneral: [
        .kazakh: "Жалпы", .english: "General", .chinese: "通用", .russian: "Общие",
    ],
    .tabRules: [
        .kazakh: "Ережелер", .english: "Rules", .chinese: "输入规则", .russian: "Правила",
    ],
    .tabPrivacy: [
        .kazakh: "Құпиялық", .english: "Privacy", .chinese: "隐私",
        .russian: "Конфиденциальность",
    ],
    .language: [
        .kazakh: "Интерфейс тілі", .english: "Language", .chinese: "界面语言",
        .russian: "Язык интерфейса",
    ],
    .languageSystem: [
        .kazakh: "Жүйе тілі", .english: "System", .chinese: "跟随系统",
        .russian: "Как в системе",
    ],
    .enableConversion: [
        .kazakh: "Қазақша түрлендіруді қосу",
        .english: "Enable Kazakh conversion",
        .chinese: "启用哈萨克语转换",
        .russian: "Включить казахское преобразование",
    ],
    .keyboard: [
        .kazakh: "Пернетақта", .english: "Keyboard", .chinese: "键盘",
        .russian: "Клавиатура",
    ],
    .keyboardLatin: [
        .kazakh: "Латын (q → қ)", .english: "Latin (q → қ)",
        .chinese: "拉丁字母 (q → қ)", .russian: "Латиница (q → қ)",
    ],
    .keyboardCyrillic: [
        .kazakh: "Орысша ЙЦУКЕН (аа → ә)", .english: "Russian ЙЦУКЕН (аа → ә)",
        .chinese: "俄文 ЙЦУКЕН (аа → ә)", .russian: "Русская ЙЦУКЕН (аа → ә)",
    ],
    .defaultMode: [
        .kazakh: "Бастапқы режим", .english: "Starting mode", .chinese: "默认模式",
        .russian: "Режим по умолчанию",
    ],
    .modeKazakh: [
        .kazakh: "KZ — Қазақша", .english: "KZ — Kazakh", .chinese: "KZ — 哈萨克语",
        .russian: "KZ — Казахский",
    ],
    .modeEnglish: [
        .kazakh: "EN — English", .english: "EN — English", .chinese: "EN — 英语",
        .russian: "EN — Английский",
    ],
    .doublePressTime: [
        .kazakh: "Қос басу уақыты", .english: "Double-press time",
        .chinese: "双击间隔", .russian: "Время двойного нажатия",
    ],
    .showModeNotification: [
        .kazakh: "Режим ауысқанда хабарлама көрсету",
        .english: "Show a notice when the mode changes",
        .chinese: "切换模式时显示提示",
        .russian: "Показывать уведомление при смене режима",
    ],
    .checkUpdatesDaily: [
        .kazakh: "Жаңартуларды күн сайын тексеру",
        .english: "Check for updates daily",
        .chinese: "每天检查更新",
        .russian: "Ежедневно проверять обновления",
    ],
    .restoreDefaults: [
        .kazakh: "Әдепкі баптауларды қалпына келтіру",
        .english: "Restore Defaults",
        .chinese: "恢复默认设置",
        .russian: "Восстановить настройки по умолчанию",
    ],
    .rulesTitle: [
        .kazakh: "Қос басу ережелері", .english: "Double-press rules",
        .chinese: "双击规则", .russian: "Правила двойного нажатия",
    ],
    .rulesLatin: [
        .kazakh: "Екі бірдей пернені белгіленген уақыт ішінде басыңыз.",
        .english: "Press the same key twice within the set time.",
        .chinese: "在设定的时间内连按同一个键两次。",
        .russian: "Нажмите одну и ту же клавишу дважды в пределах заданного времени.",
    ],
    .rulesCyrillic: [
        .kazakh: "Орыс әріптері өз орнында. Қазақ әрпі үшін орнына жазып жүрген әріпті екі рет басыңыз. Сөз бос орын басқанда бекітіледі, ал қ, ғ, ұ, ү сөздің дауыстыларына қарап өзі таңдалады.",
        .english: "Russian letters stay where they are. For a Kazakh letter, press the letter you would otherwise write in its place twice. The word is committed when you press Space, and қ, ғ, ұ, ү are chosen from the word's vowels.",
        .chinese: "俄文字母保持原位。输入哈萨克字母时，连按两次平时用来代替它的字母。按空格键时确认整个词，қ、ғ、ұ、ү 会根据词中的元音自动选择。",
        .russian: "Русские буквы остаются на своих местах. Чтобы ввести казахскую букву, дважды нажмите букву, которой её обычно заменяют. Слово подтверждается пробелом, а қ, ғ, ұ, ү выбираются по гласным слова.",
    ],
    .rulesToggleLatin: [
        .kazakh: "qq — сөз басында KZ және EN режимдерін ауыстырады",
        .english: "qq at the start of a word switches between KZ and EN",
        .chinese: "在词首输入 qq 可在 KZ 和 EN 之间切换",
        .russian: "qq в начале слова переключает режимы KZ и EN",
    ],
    .rulesToggleCyrillic: [
        .kazakh: "йй (латынша qq) — KZ және EN режимдерін ауыстырады",
        .english: "йй (qq on Latin keys) switches between KZ and EN",
        .chinese: "йй（即拉丁键位的 qq）在 KZ 和 EN 之间切换",
        .russian: "йй (qq в латинице) переключает режимы KZ и EN",
    ],
    .privacyTitle: [
        .kazakh: "Барлық түрлендіру осы Mac ішінде орындалады",
        .english: "All conversion happens on this Mac",
        .chinese: "所有转换都在这台 Mac 上完成",
        .russian: "Всё преобразование выполняется на этом Mac",
    ],
    .privacyOffline: [
        .kazakh: "Түрлендіру интернетсіз жұмыс істейді. Енгізу әдісінің өзі желіге ешқашан шықпайды.",
        .english: "Conversion works without the internet. The input method itself never connects to the network.",
        .chinese: "转换无需联网。输入法本身从不访问网络。",
        .russian: "Преобразование работает без интернета. Сам метод ввода никогда не обращается к сети.",
    ],
    .privacyUpdates: [
        .kazakh: "Жаңартуларды тексеру қосулы болса, осы баптаулар көмекшісі күніне бір рет GitHub-тан соңғы нұсқа нөмірін ғана сұрайды. Оны «Жалпы» бетінде өшіруге болады.",
        .english: "When update checks are on, this settings helper asks GitHub only for the latest version number, once a day. You can turn this off on the General tab.",
        .chinese: "开启检查更新后，此设置助手每天只向 GitHub 查询一次最新版本号。可在“通用”页面关闭。",
        .russian: "Если проверка обновлений включена, этот помощник настроек раз в день запрашивает у GitHub только номер последней версии. Её можно отключить на вкладке «Общие».",
    ],
    .privacyNothingStored: [
        .kazakh: "Енгізілген мәтін, пернелер және жазу тарихы сақталмайды немесе серверге жіберілмейді.",
        .english: "Typed text, keystrokes and typing history are never stored or sent to a server.",
        .chinese: "输入的文字、按键和输入历史不会被保存，也不会发送到服务器。",
        .russian: "Введённый текст, нажатия клавиш и история ввода не сохраняются и не отправляются на сервер.",
    ],
    .privacySecureInput: [
        .kazakh: "Құпиясөз өрістері мен қауіпсіз енгізу аймақтарында macOS шектеулері толық сақталады.",
        .english: "macOS restrictions in password fields and secure input areas stay fully in place.",
        .chinese: "在密码框和安全输入区域中，macOS 的限制完全保留。",
        .russian: "В полях паролей и областях защищённого ввода ограничения macOS полностью сохраняются.",
    ],
    .aboutVersion: [
        .kazakh: "Нұсқа %@", .english: "Version %@", .chinese: "版本 %@",
        .russian: "Версия %@",
    ],
    .aboutTagline: [
        .kazakh: "Қазақ тіліне арналған офлайн жүйелік енгізу әдісі",
        .english: "An offline system input method for Kazakh",
        .chinese: "离线运行的哈萨克语系统输入法",
        .russian: "Офлайн-метод ввода для казахского языка",
    ],
    .aboutCheck: [
        .kazakh: "Жаңартуларды тексеру", .english: "Check for Updates",
        .chinese: "检查更新", .russian: "Проверить обновления",
    ],
    .aboutChecking: [
        .kazakh: "Тексерілуде…", .english: "Checking…", .chinese: "正在检查…",
        .russian: "Проверка…",
    ],
    .aboutUpToDate: [
        .kazakh: "Сізде соңғы нұсқа орнатылған.",
        .english: "You have the latest version.",
        .chinese: "已是最新版本。",
        .russian: "У вас установлена последняя версия.",
    ],
    .aboutFailed: [
        .kazakh: "Тексеру мүмкін болмады. Интернет байланысын тексеріңіз.",
        .english: "Couldn't check for updates. Check your internet connection.",
        .chinese: "无法检查更新，请检查网络连接。",
        .russian: "Не удалось проверить обновления. Проверьте подключение к интернету.",
    ],
    .updateTitle: [
        .kazakh: "QazaqType %@ шықты",
        .english: "QazaqType %@ is available",
        .chinese: "QazaqType %@ 已发布",
        .russian: "Вышла QazaqType %@",
    ],
    .updateBody: [
        .kazakh: "Сізде %@ нұсқасы орнатылған. Жаңа нұсқа жүктеліп, орнатқыш ашылады — сонда «Жаңарту» батырмасын басыңыз. Баптауларыңыз сақталады.",
        .english: "You have version %@. The new version will be downloaded and the installer will open — click “Жаңарту” (Update) there. Your settings are kept.",
        .chinese: "当前安装的是 %@ 版本。新版本下载后会打开安装程序，请在其中点击“Жаңарту”（更新）。您的设置会保留。",
        .russian: "У вас установлена версия %@. Новая версия будет загружена и откроется установщик — нажмите в нём «Жаңарту» (Обновить). Настройки сохранятся.",
    ],
    .updateNow: [
        .kazakh: "Жаңарту", .english: "Update", .chinese: "更新", .russian: "Обновить",
    ],
    .updateLater: [
        .kazakh: "Кейін", .english: "Later", .chinese: "稍后", .russian: "Позже",
    ],
    .menuLatin: [
        .kazakh: "Латын пернетақтасы (q → қ, aa → ә)",
        .english: "Latin keyboard (q → қ, aa → ә)",
        .chinese: "拉丁字母键盘 (q → қ, aa → ә)",
        .russian: "Латинская клавиатура (q → қ, aa → ә)",
    ],
    .menuCyrillic: [
        .kazakh: "Орыс пернетақтасы — ЙЦУКЕН (аа → ә, ии → і)",
        .english: "Russian keyboard — ЙЦУКЕН (аа → ә, ии → і)",
        .chinese: "俄文键盘 — ЙЦУКЕН (аа → ә, ии → і)",
        .russian: "Русская клавиатура — ЙЦУКЕН (аа → ә, ии → і)",
    ],
    .menuSettings: [
        .kazakh: "QazaqType баптаулары…",
        .english: "QazaqType Settings…",
        .chinese: "QazaqType 设置…",
        .russian: "Настройки QazaqType…",
    ],
]
