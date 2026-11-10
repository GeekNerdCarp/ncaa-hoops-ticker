import AppKit
@preconcurrency import UserNotifications

/// Watches the favorite team's game between refreshes and posts a Mac notification
/// when something happens: tip-off, halftime, a close finish, and the final.
/// Only changes it actually sees fire, so relaunching mid-game doesn't replay old news.
@MainActor
final class TeamAlerts: NSObject, UNUserNotificationCenterDelegate {
    enum Event: Equatable { case tipoff, halftime, closeGame, final }

    private var last: [String: Game] = [:]          // game id -> previous snapshot
    private var sent: [String: Set<String>] = [:]   // game id -> events already posted

    /// Compare this refresh with the previous one. Returns what's newsworthy (for testing).
    @discardableResult
    func observe(_ g: Game, favoriteID: String) -> [Event] {
        defer { last[g.id] = g }
        guard let prev = last[g.id] else { return [] }
        var events: [Event] = []
        if prev.state == .upcoming && g.state == .live { events.append(.tipoff) }
        if !prev.isHalftime && g.isHalftime { events.append(.halftime) }
        if g.isCloseLate { events.append(.closeGame) }
        if prev.state != .final && g.state == .final { events.append(.final) }

        var done = sent[g.id, default: []]
        events = events.filter { done.insert("\($0)").inserted }
        sent[g.id] = done
        if Prefs.notifyFavorite { events.forEach { post($0, g, favoriteID: favoriteID) } }
        return events
    }

    private func post(_ e: Event, _ g: Game, favoriteID: String) {
        let mine = g.away.teamID == favoriteID ? g.away : g.home
        let other = g.away.teamID == favoriteID ? g.home : g.away
        func label(_ s: Side) -> String {
            (s.rank.map { "#\($0) " } ?? s.seed.map { "(\($0)) " } ?? "") + s.name
        }
        func score(_ s: Side) -> String { "\(s.name) \(s.score ?? "0")" }
        let line = "\(score(g.away)), \(score(g.home))"
        let tv = g.network.map { " · \($0)" } ?? ""

        let title: String, body: String
        switch e {
        case .tipoff:
            title = "\(mine.name) tips off"
            body = "\(label(g.away)) @ \(label(g.home))\(tv)"
        case .halftime:
            title = "Halftime"
            body = line
        case .closeGame:
            title = "Close game: \(mine.name) vs \(other.name)"
            body = "\(line) · \(g.detail)\(tv)"
        case .final:
            let m = Int(mine.score ?? "") ?? 0, o = Int(other.score ?? "") ?? 0
            title = m > o ? "\(mine.name) wins!" : "\(mine.name) loses"
            body = "\(g.detail): \(line)"
        }
        let content = UNMutableNotificationContent()
        content.title = "🏀 " + title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "\(g.id)-\(e)", content: content, trigger: nil))
    }

    // MARK: Permission

    func start() { UNUserNotificationCenter.current().delegate = self }

    /// Ask macOS for permission. If it was turned off earlier, offer to open System Settings.
    static func requestPermission(completion: @escaping @MainActor (Bool) -> Void) {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            if await center.notificationSettings().authorizationStatus == .denied {
                let a = NSAlert()
                a.messageText = "Notifications are turned off for Hoops Ticker"
                a.informativeText = "To get alerts about your team's games, allow notifications for Hoops Ticker in System Settings › Notifications."
                a.addButton(withTitle: "Open System Settings")
                a.addButton(withTitle: "Cancel")
                NSApp.activate(ignoringOtherApps: true)
                if a.runModal() == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
                completion(false)
                return
            }
            let ok = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            completion(ok)
        }
    }

    /// Show banners even though the app counts as "active" while its menu is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
