import AppKit

/// Checks this project's GitHub releases for a newer version.
@MainActor
final class Updater {
    static let repo = "GeekNerdCarp/ncaa-hoops-ticker"

    struct Available {
        let version: String
        let downloadURL: URL
        let notes: String
    }

    /// Set when a newer release was found; the menu shows an "Update to …" item.
    private(set) var available: Available?
    var onChange: (() -> Void)?
    private var timer: Timer?
    private var checking = false

    var currentVersion: String {
        // HOOPS_FAKE_VERSION lets you test the update prompt with an older version number.
        if let fake = ProcessInfo.processInfo.environment["HOOPS_FAKE_VERSION"] { return fake }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Checks shortly after launch, then once a day, while automatic checks are on.
    func startAutomaticChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.automaticCheck() }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.automaticCheck()
        }
    }

    private func automaticCheck() {
        guard Prefs.autoCheckUpdates else { return }
        Task { await check(userInitiated: false) }
    }

    /// userInitiated: always report the result. Automatic: speak up only once per new version.
    func check(userInitiated: Bool) async {
        guard !checking else { return }
        checking = true
        defer { checking = false }

        do {
            let release = try await fetchLatest()
            let latest = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
            guard Self.isNewer(latest, than: currentVersion) else {
                available = nil
                onChange?()
                if userInitiated {
                    alert("You're up to date", "Hoops Ticker \(currentVersion) is the newest version.")
                }
                return
            }
            let dmg = release.assets.first { $0.name.hasSuffix(".dmg") }?.browser_download_url
            let url = URL(string: dmg ?? release.html_url) ?? URL(string: release.html_url)!
            available = Available(version: latest, downloadURL: url, notes: Self.plainNotes(release.body ?? ""))
            onChange?()
            if userInitiated || Prefs.lastPromptedVersion != latest {
                Prefs.lastPromptedVersion = latest
                promptToDownload()
            }
        } catch {
            if userInitiated {
                alert("Couldn't check for updates",
                      "Hoops Ticker couldn't reach GitHub. Check your internet connection and try again.\n\n(\(error.localizedDescription))")
            }
        }
    }

    /// Shows the "new version" alert for an update that was already found.
    func promptToDownload() {
        guard let a = available else { return }
        let alert = NSAlert()
        alert.messageText = "Hoops Ticker \(a.version) is available"
        var info = "You have version \(currentVersion)."
        if !a.notes.isEmpty { info += "\n\n" + a.notes }
        info += "\n\nAfter it downloads, open the DMG and drag Hoops Ticker into Applications, replacing this copy. Quit this one first from the 🏀 menu."
        alert.informativeText = info
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(a.downloadURL)
        }
    }

    // MARK: - GitHub

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
        let body: String?
        let assets: [Asset]
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
    }

    private func fetchLatest() async throws -> Release {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("HoopsTicker/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    // MARK: - Helpers

    /// Compares dotted version numbers: 1.0.10 is newer than 1.0.9.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// The release notes' "What's new" bullets as plain text, for the alert.
    static func plainNotes(_ markdown: String) -> String {
        var lines: [String] = []
        for raw in markdown.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("### ") && !lines.isEmpty { break }   // stop at the next section (Install, …)
            guard line.hasPrefix("- ") else { continue }
            let clean = line.dropFirst(2).replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
            lines.append("• " + clean)
        }
        let text = lines.joined(separator: "\n")
        return text.count > 600 ? String(text.prefix(600)) + "…" : text
    }

    private func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}
