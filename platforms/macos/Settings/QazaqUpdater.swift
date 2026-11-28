import AppKit
import Security

/// A published QazaqType release.
struct QazaqRelease {
    let version: String
    let pageURL: URL
    let downloadURL: URL?
}

/// Checks GitHub for a newer release and hands it to the bundled installer.
///
/// Only this settings helper touches the network; the input method never
/// does. The request carries no typed text and no user data.
enum QazaqUpdater {
    static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/qadyrjan/qazaq-type-app/releases/latest"
    )!
    /// Developer ID team that must sign a downloaded installer.
    static let teamIdentifier = "5YX83877Q3"
    static let installerBundleIdentifier = "kz.qazaqtype.installer"
    static let inputMethodBundleIdentifier = "kz.qazaqtype.inputmethod.QazaqType"

    enum Failure: Error {
        /// The repository has no published release yet.
        case noRelease
        case unavailable
    }

    /// Version of the installed input method that contains this helper.
    static var installedVersion: String {
        let inputMethod = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if let info = NSDictionary(
            contentsOf: inputMethod.appendingPathComponent("Contents/Info.plist")
        ),
            info["CFBundleIdentifier"] as? String == inputMethodBundleIdentifier,
            let version = info["CFBundleShortVersionString"] as? String
        {
            return version
        }
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func fetchLatest(completion: @escaping (Result<QazaqRelease, Error>) -> Void) {
        var request = URLRequest(
            url: latestReleaseURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("QazaqType-Updater", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: Result<QazaqRelease, Error>
            if let error {
                result = .failure(error)
            } else if (response as? HTTPURLResponse)?.statusCode == 404 {
                result = .failure(Failure.noRelease)
            } else if let data,
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let release = parse(data)
            {
                result = .success(release)
            } else {
                result = .failure(Failure.unavailable)
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    static func parse(_ data: Data) -> QazaqRelease? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tag = json["tag_name"] as? String,
            let page = (json["html_url"] as? String).flatMap(URL.init(string:))
        else {
            return nil
        }
        let assets = json["assets"] as? [[String: Any]] ?? []
        let dmg = assets.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
        return QazaqRelease(
            version: tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV")),
            pageURL: page,
            downloadURL: (dmg?["browser_download_url"] as? String).flatMap(URL.init(string:))
        )
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
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

    /// Asks the user to update. On agreement, downloads the release, checks
    /// its signature, opens the installer, and calls `completion` once the
    /// installer quits or anything fails.
    static func offer(
        _ release: QazaqRelease,
        installed: String,
        completion: @escaping () -> Void
    ) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = L(.updateTitle, release.version)
        alert.informativeText =
            L(.updateBody, installed)
        alert.addButton(withTitle: L(.updateNow))
        alert.addButton(withTitle: L(.updateLater))
        guard alert.runModal() == .alertFirstButtonReturn else {
            completion()
            return
        }
        guard let downloadURL = release.downloadURL else {
            NSWorkspace.shared.open(release.pageURL)
            completion()
            return
        }
        UpdateSession.start(downloadURL: downloadURL) { succeeded in
            if !succeeded {
                // Fall back to the release page so the user can still update.
                NSWorkspace.shared.open(release.pageURL)
            }
            completion()
        }
    }

    /// Accepts only an installer signed by QazaqType's Developer ID.
    static func isTrustedInstaller(at url: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code
        else {
            return false
        }
        let requirementText =
            "anchor apple generic and identifier \"\(installerBundleIdentifier)\""
            + " and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            requirementText as CFString,
            [],
            &requirement
        ) == errSecSuccess,
            let requirement
        else {
            return false
        }
        let flags = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures
                | kSecCSCheckNestedCode
                | kSecCSStrictValidate
        )
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }
}

/// Downloads and mounts a release disk image, then runs its installer.
private final class UpdateSession {
    private static var active: UpdateSession?

    private let completion: (Bool) -> Void
    private var mountPoint: URL?
    private var diskImage: URL?
    private var terminationObservation: NSKeyValueObservation?

    private init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    static func start(downloadURL: URL, completion: @escaping (Bool) -> Void) {
        let session = UpdateSession(completion: completion)
        active = session
        session.download(downloadURL)
    }

    private func download(_ url: URL) {
        URLSession.shared.downloadTask(with: url) { [self] location, response, _ in
            guard let location,
                  (response as? HTTPURLResponse)?.statusCode == 200
            else {
                return finish(succeeded: false)
            }
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("QazaqTypeUpdate", isDirectory: true)
            let image = folder.appendingPathComponent(UUID().uuidString + ".dmg")
            do {
                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true
                )
                try FileManager.default.moveItem(at: location, to: image)
            } catch {
                return finish(succeeded: false)
            }
            diskImage = image
            guard let mountPoint = attach(image) else {
                return finish(succeeded: false)
            }
            self.mountPoint = mountPoint
            let installer = mountPoint.appendingPathComponent("QazaqType Installer.app")
            guard QazaqUpdater.isTrustedInstaller(at: installer) else {
                return finish(succeeded: false)
            }
            DispatchQueue.main.async { self.launch(installer) }
        }.resume()
    }

    private func attach(_ image: URL) -> URL? {
        let output = run(
            "/usr/bin/hdiutil",
            ["attach", image.path, "-nobrowse", "-readonly", "-noautoopen", "-plist"]
        )
        guard let output,
              let plist = try? PropertyListSerialization.propertyList(
                  from: output,
                  format: nil
              ) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let path = entities.compactMap({ $0["mount-point"] as? String }).first
        else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func launch(_ installer: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: installer,
            configuration: configuration
        ) { [self] application, _ in
            guard let application else {
                return finish(succeeded: false)
            }
            terminationObservation = application.observe(
                \.isTerminated,
                options: [.initial, .new]
            ) { [self] application, _ in
                if application.isTerminated {
                    finish(succeeded: true)
                }
            }
        }
    }

    private func finish(succeeded: Bool) {
        terminationObservation = nil
        if let mountPoint {
            _ = run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-quiet", "-force"])
            self.mountPoint = nil
        }
        if let diskImage {
            try? FileManager.default.removeItem(at: diskImage)
            self.diskImage = nil
        }
        DispatchQueue.main.async { [self] in
            completion(succeeded)
            UpdateSession.active = nil
        }
    }

    private func run(_ executable: String, _ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}

/// Entry used when the input method starts the daily background check.
final class BackgroundUpdateCheck: NSObject, NSApplicationDelegate {
    static let argument = "--check-for-updates"

    static func run() {
        let application = NSApplication.shared
        let delegate = BackgroundUpdateCheck()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let installed = QazaqUpdater.installedVersion
        QazaqUpdater.fetchLatest { result in
            guard case let .success(release) = result,
                  QazaqUpdater.isVersion(release.version, newerThan: installed)
            else {
                NSApp.terminate(nil)
                return
            }
            QazaqUpdater.offer(release, installed: installed) {
                NSApp.terminate(nil)
            }
        }
    }
}
