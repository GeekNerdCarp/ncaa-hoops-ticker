import AppKit

// MARK: - Stored preferences

enum Prefs {
    private static let d = UserDefaults.standard
    static var speed: Double {
        get { d.object(forKey: "speed") as? Double ?? 2.0 }
        set { d.set(newValue, forKey: "speed") }
    }
    static var rankedOnly: Bool {
        get { d.bool(forKey: "rankedOnly") }
        set { d.set(newValue, forKey: "rankedOnly") }
    }
    static var showFinals: Bool {
        get { d.object(forKey: "showFinals") as? Bool ?? true }
        set { d.set(newValue, forKey: "showFinals") }
    }
    static var showUpcoming: Bool {
        get { d.object(forKey: "showUpcoming") as? Bool ?? true }
        set { d.set(newValue, forKey: "showUpcoming") }
    }
    static var atTop: Bool {
        get { d.bool(forKey: "atTop") }
        set { d.set(newValue, forKey: "atTop") }
    }
    static var hidden: Bool {
        get { d.bool(forKey: "hidden") }
        set { d.set(newValue, forKey: "hidden") }
    }
    static var favoriteTeamID: String? {
        get { d.string(forKey: "favoriteTeamID") }
        set { d.set(newValue, forKey: "favoriteTeamID") }
    }
    static var favoriteTeamName: String? {
        get { d.string(forKey: "favoriteTeamName") }
        set { d.set(newValue, forKey: "favoriteTeamName") }
    }

    static let speeds: [(String, Double)] = [("Slow", 1.0), ("Medium", 2.0), ("Fast", 3.5)]
}

// MARK: - Settings window

enum SettingChange { case favorite, position, display }

@MainActor
final class SettingsController: NSObject {
    var onChange: ((SettingChange) -> Void)?

    private let window: NSWindow
    private let teamPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let positionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let speedPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let rankedBox = NSButton(checkboxWithTitle: "Top 25 games only", target: nil, action: nil)
    private let finalsBox = NSButton(checkboxWithTitle: "Final scores", target: nil, action: nil)
    private let upcomingBox = NSButton(checkboxWithTitle: "Upcoming games", target: nil, action: nil)
    private var centered = false

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Hoops Ticker Settings"
        window.isReleasedWhenClosed = false

        positionPopup.addItems(withTitles: ["Bottom of screen", "Top of screen"])
        speedPopup.addItems(withTitles: Prefs.speeds.map { $0.0 })
        teamPopup.addItem(withTitle: "Loading teams…")
        teamPopup.isEnabled = false
        for c: NSControl in [teamPopup, positionPopup, speedPopup, rankedBox, finalsBox, upcomingBox] {
            c.target = self
            c.action = #selector(changed(_:))
        }

        let hint = NSTextField(wrappingLabelWithString:
            "Your team's game shows first in the ticker: live, today's final, or its next scheduled game, even if that's days away.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let showStack = NSStackView(views: [rankedBox, finalsBox, upcomingBox])
        showStack.orientation = .vertical
        showStack.alignment = .leading
        showStack.spacing = 6

        func label(_ s: String) -> NSTextField { NSTextField(labelWithString: s) }
        let grid = NSGridView(views: [
            [label("Follow your favorite team:"), teamPopup],
            [NSGridCell.emptyContentView, hint],
            [label("Position:"), positionPopup],
            [label("Scroll speed:"), speedPopup],
            [label("Show:"), showStack],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.row(at: 4).rowAlignment = .none
        grid.row(at: 4).yPlacement = .top
        grid.rowSpacing = 12
        grid.columnSpacing = 10
        grid.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            teamPopup.widthAnchor.constraint(equalToConstant: 280),
            hint.widthAnchor.constraint(equalToConstant: 280),
        ])
        window.contentView = content
        window.setContentSize(content.fittingSize)
        sync()
    }

    func setTeams(_ teams: [TeamInfo]) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "None", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        for t in teams {
            let it = NSMenuItem(title: t.name, action: nil, keyEquivalent: "")
            it.representedObject = t.id
            menu.addItem(it)
        }
        teamPopup.menu = menu
        teamPopup.isEnabled = true
        sync()
    }

    /// Pull current values from Prefs into the controls.
    func sync() {
        if teamPopup.isEnabled {
            let fav = Prefs.favoriteTeamID
            let idx = teamPopup.itemArray.firstIndex { ($0.representedObject as? String) == fav && fav != nil } ?? 0
            teamPopup.selectItem(at: idx)
        }
        positionPopup.selectItem(at: Prefs.atTop ? 1 : 0)
        speedPopup.selectItem(at: Prefs.speeds.firstIndex { $0.1 == Prefs.speed } ?? 1)
        rankedBox.state = Prefs.rankedOnly ? .on : .off
        finalsBox.state = Prefs.showFinals ? .on : .off
        upcomingBox.state = Prefs.showUpcoming ? .on : .off
    }

    func show() {
        sync()
        if !centered { window.center(); centered = true }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func changed(_ sender: NSControl) {
        switch sender {
        case teamPopup:
            let item = teamPopup.selectedItem
            let id = item?.representedObject as? String
            Prefs.favoriteTeamID = id
            Prefs.favoriteTeamName = id == nil ? nil : item?.title
            onChange?(.favorite)
        case positionPopup:
            Prefs.atTop = positionPopup.indexOfSelectedItem == 1
            onChange?(.position)
        case speedPopup:
            Prefs.speed = Prefs.speeds[max(0, speedPopup.indexOfSelectedItem)].1
            onChange?(.display)
        case rankedBox:
            Prefs.rankedOnly = rankedBox.state == .on
            onChange?(.display)
        case finalsBox:
            Prefs.showFinals = finalsBox.state == .on
            onChange?(.display)
        case upcomingBox:
            Prefs.showUpcoming = upcomingBox.state == .on
            onChange?(.display)
        default:
            break
        }
    }
}
