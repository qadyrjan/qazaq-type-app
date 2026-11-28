import Foundation

/// Interface languages of the settings window, update alert and input menu.
/// Kazakh is the default until the user picks another language.
enum QazaqLanguage: String, CaseIterable, Identifiable {
    case kazakh = "kk"
    case english = "en"
    case chinese = "zh"
    case russian = "ru"
    case system

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
    // Installer
    case iWindowTitle
    case iMenuQuit, iMenuEdit, iMenuUndo, iMenuCut, iMenuCopy, iMenuPaste, iMenuSelectAll
    case iWelcomeDetail
    case iBtnReinstall
    case iBtnInstall
    case iBtnInstalling
    case iBtnEnable
    case iBtnRecheck
    case iBtnRetry
    case iTitleWelcome
    case iTitleInstalling
    case iTitleNeedsLogin
    case iTitleNeedsActivation
    case iTitleUpdate
    case iTitleReady
    case iTitleFailed
    case iDescWelcome
    case iDescInstalling
    case iDescNeedsLogin
    case iDescNeedsActivation
    case iDescUpdate
    case iDescReady
    case iDescFailed
    case iUpdating
    case iPreparing
    case iCleaning
    case iCopying
    case iErrRegister
    case iRegistered
    case iNotLoaded
    case iNotFound
    case iEnabling
    case iErrEnable
    case iNotConfirmed
    case iUpdated
    case iAllDone
    case iEnabledChoose
    case iLegacyFound
    case iReplaces
    case iQuarantined
    case iErrNoResources
    case iErrBadEmbedded
    case iAdmin
    case iErrRemove
    case iErrNameTaken
    case iErrCopy
    case iErrSignature
    case iErrAdminDenied
    case iSubtitle
    case iStep1
    case iStep1Sub
    case iStep2
    case iStep2Sub
    case iStep3
    case iStep3Sub
    case iDeveloper
    case iStatusInstalled
    case iStatusRegistered
    case iStatusEnabled
    case iStatusSelected
    case iQuickTest
    case iLayoutLatin
    case iLayoutCyrillic
    case iTryCyrillic
    case iTryLatin
    case iTestPlaceholder
    case iOpenKeyboard
}

/// Returns `key` in the current interface language. `%@` placeholders are
/// filled from `arguments` in order.
func L(_ key: QazaqText, _ arguments: String...) -> String {
    L(key, arguments: arguments)
}

func L(_ key: QazaqText, arguments: [String]) -> String {
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
    .iWelcomeDetail: [
        .kazakh: "Орнату алдында жұмысыңызды сақтаңыз. Алғашқы орнатудан кейін macOS жүйеден шығып, қайта кіруді сұрауы мүмкін.",
        .english: "Save your work before installing. After the first installation, macOS may ask you to log out and back in.",
        .chinese: "安装前请保存您的工作。首次安装后，macOS 可能会要求您注销并重新登录。",
        .russian: "Перед установкой сохраните работу. После первой установки macOS может попросить выйти из системы и войти снова.",
    ],
    .iBtnReinstall: [
        .kazakh: "Қайта орнату",
        .english: "Reinstall",
        .chinese: "重新安装",
        .russian: "Переустановить",
    ],
    .iBtnInstall: [
        .kazakh: "Орнату",
        .english: "Install",
        .chinese: "安装",
        .russian: "Установить",
    ],
    .iBtnInstalling: [
        .kazakh: "Орнатылуда…",
        .english: "Installing…",
        .chinese: "正在安装…",
        .russian: "Установка…",
    ],
    .iBtnEnable: [
        .kazakh: "QazaqType-ты қосу",
        .english: "Enable QazaqType",
        .chinese: "启用 QazaqType",
        .russian: "Включить QazaqType",
    ],
    .iBtnRecheck: [
        .kazakh: "Қайта тексеру",
        .english: "Check Again",
        .chinese: "重新检查",
        .russian: "Проверить снова",
    ],
    .iBtnRetry: [
        .kazakh: "Қайталау",
        .english: "Try Again",
        .chinese: "重试",
        .russian: "Повторить",
    ],
    .iTitleWelcome: [
        .kazakh: "QazaqType-қа қош келдіңіз",
        .english: "Welcome to QazaqType",
        .chinese: "欢迎使用 QazaqType",
        .russian: "Добро пожаловать в QazaqType",
    ],
    .iTitleInstalling: [
        .kazakh: "Енгізу әдісі орнатылуда",
        .english: "Installing the input method",
        .chinese: "正在安装输入法",
        .russian: "Установка метода ввода",
    ],
    .iTitleNeedsLogin: [
        .kazakh: "Жүйеге қайта кіру қажет",
        .english: "Log out and back in",
        .chinese: "需要重新登录",
        .russian: "Нужно войти в систему заново",
    ],
    .iTitleNeedsActivation: [
        .kazakh: "Енгізу әдісін қосу",
        .english: "Enable the input method",
        .chinese: "启用输入法",
        .russian: "Включите метод ввода",
    ],
    .iTitleUpdate: [
        .kazakh: "Жаңа нұсқа қолжетімді",
        .english: "A new version is available",
        .chinese: "有新版本可用",
        .russian: "Доступна новая версия",
    ],
    .iTitleReady: [
        .kazakh: "QazaqType пайдалануға дайын",
        .english: "QazaqType is ready",
        .chinese: "QazaqType 已可使用",
        .russian: "QazaqType готов к работе",
    ],
    .iTitleFailed: [
        .kazakh: "Орнату аяқталмады",
        .english: "Installation didn't finish",
        .chinese: "安装未完成",
        .russian: "Установка не завершена",
    ],
    .iDescWelcome: [
        .kazakh: "Intel және Apple чипті Mac компьютерлеріне арналған дербес қазақша енгізу әдісі.",
        .english: "A standalone Kazakh input method for Macs with Intel or Apple silicon.",
        .chinese: "适用于 Intel 和 Apple 芯片 Mac 的独立哈萨克语输入法。",
        .russian: "Самостоятельный казахский метод ввода для Mac с процессорами Intel и Apple.",
    ],
    .iDescInstalling: [
        .kazakh: "QazaqType көшіріліп, тіркеліп және macOS жүйесінде қосылуда.",
        .english: "QazaqType is being copied, registered and enabled in macOS.",
        .chinese: "正在复制、注册 QazaqType，并在 macOS 中启用。",
        .russian: "QazaqType копируется, регистрируется и включается в macOS.",
    ],
    .iDescNeedsLogin: [
        .kazakh: "macOS QazaqType-ты енгізу әдістері тізіміне әлі қоспады. Алдымен «Қайта орнату» түймесін басыңыз. Көмектеспесе, жүйеден шығып, қайта кіріңіз де, орнатқышты қайта ашыңыз.",
        .english: "macOS hasn't added QazaqType to the input sources yet. First click “Reinstall”. If that doesn't help, log out, log back in and open the installer again.",
        .chinese: "macOS 尚未将 QazaqType 添加到输入法列表。请先点击“重新安装”。如果仍然无效，请注销并重新登录，然后再次打开安装程序。",
        .russian: "macOS ещё не добавила QazaqType в список источников ввода. Сначала нажмите «Переустановить». Если не поможет, выйдите из системы, войдите снова и откройте установщик ещё раз.",
    ],
    .iDescNeedsActivation: [
        .kazakh: "macOS растау сұрағын көрсетсе, «Рұқсат ету» түймесін басыңыз немесе пернетақта баптауларынан қолмен қосыңыз.",
        .english: "If macOS asks for confirmation, click “Allow”, or turn it on yourself in Keyboard settings.",
        .chinese: "如果 macOS 弹出确认提示，请点击“允许”，或在键盘设置中手动启用。",
        .russian: "Если macOS попросит подтверждение, нажмите «Разрешить» или включите его вручную в настройках клавиатуры.",
    ],
    .iDescUpdate: [
        .kazakh: "Орнатылған нұсқа: %@. Жаңа нұсқа: %@. Баптауларыңыз сақталады, жүйеден шығудың қажеті жоқ.",
        .english: "Installed version: %@. New version: %@. Your settings are kept and you don't need to log out.",
        .chinese: "已安装版本：%@。新版本：%@。您的设置会保留，无需注销。",
        .russian: "Установленная версия: %@. Новая версия: %@. Настройки сохранятся, выходить из системы не нужно.",
    ],
    .iDescReady: [
        .kazakh: "Енді мәзір жолағынан QazaqType-ты таңдауға болады.",
        .english: "You can now choose QazaqType from the input menu in the menu bar.",
        .chinese: "现在可以从菜单栏的输入法菜单中选择 QazaqType。",
        .russian: "Теперь QazaqType можно выбрать в меню ввода в строке меню.",
    ],
    .iDescFailed: [
        .kazakh: "Төмендегі қатені тексеріп, түзеткеннен кейін қайталаңыз.",
        .english: "Check the error below, fix it and try again.",
        .chinese: "请查看下方的错误，解决后重试。",
        .russian: "Проверьте ошибку ниже, устраните её и повторите попытку.",
    ],
    .iUpdating: [
        .kazakh: "QazaqType жаңартылуда…",
        .english: "Updating QazaqType…",
        .chinese: "正在更新 QazaqType…",
        .russian: "Обновление QazaqType…",
    ],
    .iPreparing: [
        .kazakh: "QazaqType дайындалуда…",
        .english: "Preparing QazaqType…",
        .chinese: "正在准备 QazaqType…",
        .russian: "Подготовка QazaqType…",
    ],
    .iCleaning: [
        .kazakh: "Ескі нұсқалар тоқтатылып, тазалануда…",
        .english: "Stopping and removing old versions…",
        .chinese: "正在停止并清理旧版本…",
        .russian: "Останавливаем и удаляем старые версии…",
    ],
    .iCopying: [
        .kazakh: "Жаңа нұсқа көшірілуде…",
        .english: "Copying the new version…",
        .chinese: "正在复制新版本…",
        .russian: "Копируем новую версию…",
    ],
    .iErrRegister: [
        .kazakh: "Енгізу әдісін тіркеу сәтсіз аяқталды. Қате коды: %@",
        .english: "Couldn't register the input method. Error code: %@",
        .chinese: "无法注册输入法。错误代码：%@",
        .russian: "Не удалось зарегистрировать метод ввода. Код ошибки: %@",
    ],
    .iRegistered: [
        .kazakh: "QazaqType көшіріліп, тіркелді. macOS енгізу көздерін жаңартуда…",
        .english: "QazaqType is copied and registered. macOS is updating its input sources…",
        .chinese: "QazaqType 已复制并注册。macOS 正在更新输入法列表…",
        .russian: "QazaqType скопирован и зарегистрирован. macOS обновляет источники ввода…",
    ],
    .iNotLoaded: [
        .kazakh: "Файл дұрыс орнатылды, бірақ ағымдағы сеанс жаңа енгізу режимін әлі жүктемеді.",
        .english: "The file is installed correctly, but this login session hasn't loaded the new input source yet.",
        .chinese: "文件已正确安装，但当前登录会话尚未加载新的输入法。",
        .russian: "Файл установлен правильно, но текущий сеанс ещё не загрузил новый источник ввода.",
    ],
    .iNotFound: [
        .kazakh: "Ағымдағы сеанс QazaqType енгізу режимін әлі таппады.",
        .english: "This session hasn't found the QazaqType input source yet.",
        .chinese: "当前会话尚未找到 QazaqType 输入法。",
        .russian: "Текущий сеанс ещё не нашёл источник ввода QazaqType.",
    ],
    .iEnabling: [
        .kazakh: "macOS жүйесінен QazaqType-ты қосу сұралуда…",
        .english: "Asking macOS to enable QazaqType…",
        .chinese: "正在请求 macOS 启用 QazaqType…",
        .russian: "Запрашиваем у macOS включение QazaqType…",
    ],
    .iErrEnable: [
        .kazakh: "Енгізу әдісін қосу сәтсіз аяқталды. Қате коды: %@",
        .english: "Couldn't enable the input method. Error code: %@",
        .chinese: "无法启用输入法。错误代码：%@",
        .russian: "Не удалось включить метод ввода. Код ошибки: %@",
    ],
    .iNotConfirmed: [
        .kazakh: "macOS әлі растаған жоқ. Жүйелік сұрауда «Рұқсат ету» пәрменін таңдап, қайта көріңіз.",
        .english: "macOS hasn't confirmed yet. Choose “Allow” in the system prompt and try again.",
        .chinese: "macOS 尚未确认。请在系统提示中选择“允许”，然后重试。",
        .russian: "macOS ещё не подтвердила. Выберите «Разрешить» в системном запросе и повторите.",
    ],
    .iUpdated: [
        .kazakh: "QazaqType %@ нұсқасына жаңартылды.",
        .english: "QazaqType was updated to version %@.",
        .chinese: "QazaqType 已更新到 %@ 版本。",
        .russian: "QazaqType обновлён до версии %@.",
    ],
    .iAllDone: [
        .kazakh: "Орнату, қосу және ауыстыру сәтті аяқталды.",
        .english: "Installed, enabled and selected successfully.",
        .chinese: "安装、启用和切换均已成功完成。",
        .russian: "Установка, включение и выбор успешно завершены.",
    ],
    .iEnabledChoose: [
        .kazakh: "QazaqType қосылды. Оны мәзір жолағындағы енгізу әдістерінен таңдаңыз.",
        .english: "QazaqType is enabled. Choose it from the input menu in the menu bar.",
        .chinese: "QazaqType 已启用。请从菜单栏的输入法菜单中选择它。",
        .russian: "QazaqType включён. Выберите его в меню ввода в строке меню.",
    ],
    .iLegacyFound: [
        .kazakh: "Ескі жүйелік нұсқа табылды. Жаңарту кезінде macOS әкімші рұқсатын сұрайды.",
        .english: "An old system-wide version was found. macOS will ask for administrator permission during the update.",
        .chinese: "发现旧的系统级版本。更新时 macOS 会请求管理员权限。",
        .russian: "Найдена старая системная версия. При обновлении macOS запросит права администратора.",
    ],
    .iReplaces: [
        .kazakh: "Жаңарту ескі нұсқаны толық алмастырады. Пернетақта таңдауыңыз бен басқа баптаулар өзгермейді.",
        .english: "The update fully replaces the old version. Your keyboard choice and other settings stay the same.",
        .chinese: "更新会完全替换旧版本。您的键盘选择和其他设置不会改变。",
        .russian: "Обновление полностью заменит старую версию. Выбранная клавиатура и другие настройки не изменятся.",
    ],
    .iQuarantined: [
        .kazakh: "Орнатылған көшірмені macOS бұғаттап тұр. «Қайта орнату» түймесін басыңыз.",
        .english: "macOS is blocking the installed copy. Click “Reinstall”.",
        .chinese: "macOS 正在阻止已安装的副本。请点击“重新安装”。",
        .russian: "macOS блокирует установленную копию. Нажмите «Переустановить».",
    ],
    .iErrNoResources: [
        .kazakh: "Орнатқыштың ресурстар қалтасы жоқ.",
        .english: "The installer's resources folder is missing.",
        .chinese: "安装程序缺少资源文件夹。",
        .russian: "В установщике нет папки ресурсов.",
    ],
    .iErrBadEmbedded: [
        .kazakh: "Орнатқыштағы QazaqType.app толық емес немесе сәйкестендіргіші қате.",
        .english: "The QazaqType.app inside the installer is incomplete or has the wrong identifier.",
        .chinese: "安装程序中的 QazaqType.app 不完整或标识符错误。",
        .russian: "QazaqType.app в установщике повреждён или имеет неверный идентификатор.",
    ],
    .iAdmin: [
        .kazakh: "Ескі жүйелік нұсқаны жою үшін әкімші рұқсаты сұралуда…",
        .english: "Asking for administrator permission to remove the old system-wide version…",
        .chinese: "正在请求管理员权限以删除旧的系统级版本…",
        .russian: "Запрашиваем права администратора для удаления старой системной версии…",
    ],
    .iErrRemove: [
        .kazakh: "Ескі нұсқаны жою мүмкін болмады. Қайталап көріңіз.",
        .english: "Couldn't remove the old version. Please try again.",
        .chinese: "无法删除旧版本，请重试。",
        .russian: "Не удалось удалить старую версию. Попробуйте ещё раз.",
    ],
    .iErrNameTaken: [
        .kazakh: "Орнату орнында аттас басқа қолданба бар. Оны қорғау үшін орнату тоқтатылды.",
        .english: "Another app with the same name is in the install location. Installation stopped to protect it.",
        .chinese: "安装位置已有同名的其他应用。为保护该应用，安装已停止。",
        .russian: "В месте установки есть другое приложение с таким же именем. Установка остановлена, чтобы его не повредить.",
    ],
    .iErrCopy: [
        .kazakh: "Енгізу әдісін көшіру мүмкін болмады: %@",
        .english: "Couldn't copy the input method: %@",
        .chinese: "无法复制输入法：%@",
        .russian: "Не удалось скопировать метод ввода: %@",
    ],
    .iErrSignature: [
        .kazakh: "Көшірілген енгізу әдісінің қолтаңбасы жарамсыз: %@",
        .english: "The copied input method has an invalid signature: %@",
        .chinese: "复制的输入法签名无效：%@",
        .russian: "У скопированного метода ввода недействительная подпись: %@",
    ],
    .iErrAdminDenied: [
        .kazakh: "Әкімші рұқсаты берілмеді.",
        .english: "Administrator permission wasn't granted.",
        .chinese: "未获得管理员权限。",
        .russian: "Права администратора не предоставлены.",
    ],
    .iSubtitle: [
        .kazakh: "macOS орнату шебері",
        .english: "macOS setup assistant",
        .chinese: "macOS 安装助手",
        .russian: "Мастер установки для macOS",
    ],
    .iStep1: [
        .kazakh: "Орнату",
        .english: "Install",
        .chinese: "安装",
        .russian: "Установка",
    ],
    .iStep1Sub: [
        .kazakh: "Енгізу әдісін көшіру және тіркеу",
        .english: "Copy and register the input method",
        .chinese: "复制并注册输入法",
        .russian: "Копирование и регистрация метода ввода",
    ],
    .iStep2: [
        .kazakh: "Жүйелік растау",
        .english: "System approval",
        .chinese: "系统确认",
        .russian: "Подтверждение в системе",
    ],
    .iStep2Sub: [
        .kazakh: "macOS жүйесінде QazaqType-ты қосу",
        .english: "Turn on QazaqType in macOS",
        .chinese: "在 macOS 中启用 QazaqType",
        .russian: "Включение QazaqType в macOS",
    ],
    .iStep3: [
        .kazakh: "Пайдалануды бастау",
        .english: "Start typing",
        .chinese: "开始使用",
        .russian: "Начало работы",
    ],
    .iStep3Sub: [
        .kazakh: "Мәзір жолағынан енгізу әдісін ауыстыру",
        .english: "Switch input source from the menu bar",
        .chinese: "从菜单栏切换输入法",
        .russian: "Переключение метода ввода в строке меню",
    ],
    .iDeveloper: [
        .kazakh: "Әзірлеуші",
        .english: "Developer",
        .chinese: "开发者",
        .russian: "Разработчик",
    ],
    .iStatusInstalled: [
        .kazakh: "Енгізу әдісінің файлы орнатылды",
        .english: "Input method file installed",
        .chinese: "输入法文件已安装",
        .russian: "Файл метода ввода установлен",
    ],
    .iStatusRegistered: [
        .kazakh: "Енгізу режимі тіркелді",
        .english: "Input source registered",
        .chinese: "输入法已注册",
        .russian: "Источник ввода зарегистрирован",
    ],
    .iStatusEnabled: [
        .kazakh: "QazaqType қосылды",
        .english: "QazaqType enabled",
        .chinese: "QazaqType 已启用",
        .russian: "QazaqType включён",
    ],
    .iStatusSelected: [
        .kazakh: "QazaqType таңдалды",
        .english: "QazaqType selected",
        .chinese: "已选择 QazaqType",
        .russian: "QazaqType выбран",
    ],
    .iQuickTest: [
        .kazakh: "Жылдам тексеру",
        .english: "Quick test",
        .chinese: "快速测试",
        .russian: "Быстрая проверка",
    ],
    .iLayoutLatin: [
        .kazakh: "Латын",
        .english: "Latin",
        .chinese: "拉丁字母",
        .russian: "Латиница",
    ],
    .iLayoutCyrillic: [
        .kazakh: "Орысша ЙЦУКЕН",
        .english: "Russian ЙЦУКЕН",
        .chinese: "俄文 ЙЦУКЕН",
        .russian: "Русская ЙЦУКЕН",
    ],
    .iTryCyrillic: [
        .kazakh: "Мәзір жолағынан QazaqType-ты таңдап, Казакстан деп теріңіз",
        .english: "Choose QazaqType in the menu bar and type Казакстан",
        .chinese: "在菜单栏选择 QazaqType，然后输入 Казакстан",
        .russian: "Выберите QazaqType в строке меню и наберите Казакстан",
    ],
    .iTryLatin: [
        .kazakh: "Мәзір жолағынан QazaqType-ты таңдап, qazaq деп теріңіз",
        .english: "Choose QazaqType in the menu bar and type qazaq",
        .chinese: "在菜单栏选择 QazaqType，然后输入 qazaq",
        .russian: "Выберите QazaqType в строке меню и наберите qazaq",
    ],
    .iTestPlaceholder: [
        .kazakh: "Осы жерде тексеріңіз",
        .english: "Try it here",
        .chinese: "在此测试",
        .russian: "Проверьте здесь",
    ],
    .iOpenKeyboard: [
        .kazakh: "Пернетақта баптауларын ашу",
        .english: "Open Keyboard Settings",
        .chinese: "打开键盘设置",
        .russian: "Открыть настройки клавиатуры",
    ],
    .iWindowTitle: [
        .kazakh: "QazaqType орнатқышы",
        .english: "QazaqType Installer",
        .chinese: "QazaqType 安装程序",
        .russian: "Установщик QazaqType",
    ],
    .iMenuQuit: [
        .kazakh: "QazaqType орнатқышынан шығу",
        .english: "Quit QazaqType Installer",
        .chinese: "退出 QazaqType 安装程序",
        .russian: "Завершить установщик QazaqType",
    ],
    .iMenuEdit: [
        .kazakh: "Өңдеу",
        .english: "Edit",
        .chinese: "编辑",
        .russian: "Правка",
    ],
    .iMenuUndo: [
        .kazakh: "Болдырмау",
        .english: "Undo",
        .chinese: "撤销",
        .russian: "Отменить",
    ],
    .iMenuCut: [
        .kazakh: "Қиып алу",
        .english: "Cut",
        .chinese: "剪切",
        .russian: "Вырезать",
    ],
    .iMenuCopy: [
        .kazakh: "Көшіру",
        .english: "Copy",
        .chinese: "拷贝",
        .russian: "Скопировать",
    ],
    .iMenuPaste: [
        .kazakh: "Қою",
        .english: "Paste",
        .chinese: "粘贴",
        .russian: "Вставить",
    ],
    .iMenuSelectAll: [
        .kazakh: "Барлығын таңдау",
        .english: "Select All",
        .chinese: "全选",
        .russian: "Выбрать все",
    ],
]
