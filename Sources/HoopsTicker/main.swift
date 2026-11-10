import AppKit

// MARK: - Ticker rendering

enum Palette {
    static let rank = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.2, alpha: 1)
    static let name = NSColor.white
    static let favorite = NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.35, alpha: 1)
    static let liveScore = NSColor(calibratedRed: 0.35, green: 1.0, blue: 0.45, alpha: 1)
    static let score = NSColor(calibratedWhite: 0.92, alpha: 1)
    static let live = NSColor(calibratedRed: 1.0, green: 0.38, blue: 0.3, alpha: 1)
    static let upcoming = NSColor(calibratedRed: 0.4, green: 0.85, blue: 1.0, alpha: 1)
    static let final = NSColor(calibratedWhite: 0.6, alpha: 1)
    static let dim = NSColor(calibratedWhite: 0.4, alpha: 1)
}

func buildTickerText(_ games: [Game], favoriteID: String?, font: NSFont) -> NSAttributedString {
    let out = NSMutableAttributedString()
    func add(_ s: String, _ c: NSColor) {
        out.append(NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: c]))
    }
    func team(_ s: Side, showScore: Bool, live: Bool) {
        if let r = s.rank { add("#\(r) ", Palette.rank) }
        add(s.name.uppercased(), s.teamID == favoriteID ? Palette.favorite : Palette.name)
        if showScore, let sc = s.score { add(" \(sc)", live ? Palette.liveScore : Palette.score) }
    }

    if games.isEmpty {
        add("NO GAMES TO SHOW RIGHT NOW", Palette.dim)
        add("          ", Palette.dim)
        return out
    }
    for g in games {
        if let fav = favoriteID, g.involves(fav) { add("★ ", Palette.favorite) }
        switch g.state {
        case .live:
            team(g.away, showScore: true, live: true)
            add("  –  ", Palette.dim)
            team(g.home, showScore: true, live: true)
            add("   \(g.detail.uppercased())", Palette.live)
        case .final:
            team(g.away, showScore: true, live: false)
            add("  –  ", Palette.dim)
            team(g.home, showScore: true, live: false)
            add("   \(g.detail.uppercased())", Palette.final)
        case .upcoming:
            team(g.away, showScore: false, live: false)
            add("  @  ", Palette.dim)
            team(g.home, showScore: false, live: false)
            add("   \(g.detail.uppercased())", Palette.upcoming)
        }
        add("      ◆      ", Palette.dim)
    }
    return out
}

final class TickerView: NSView {
    private var content = NSAttributedString()
    private var contentWidth: CGFloat = 0
    private var offset: CGFloat = 0
    var speed: CGFloat = 2.0
    private var timer: Timer?

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, self.contentWidth > 0, self.window?.isVisible == true else { return }
            self.offset += self.speed
            if self.offset >= self.contentWidth { self.offset -= self.contentWidth }
            self.needsDisplay = true
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(_ text: NSAttributedString) {
        content = text
        contentWidth = ceil(text.size().width)
        if offset >= contentWidth { offset = 0 }
        needsDisplay = true
    }

    /// Jump back so the first game is at the left edge.
    func resetToStart() {
        offset = 0
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
        guard contentWidth > 0 else { return }
        let h = content.size().height
        let y = (bounds.height - h) / 2
        var x = -offset
        while x < bounds.width {
            content.draw(at: NSPoint(x: x, y: y))
            x += contentWidth
        }
        NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
        NSRect(x: 0, y: Prefs.atTop ? bounds.height - 1 : 0, width: bounds.width, height: 1).fill()
    }
}

// MARK: - Menu bar icon

/// The app icon's basketball, drawn as a vector so it stays sharp at menu bar size.
func menuBarBall() -> NSImage {
    let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
        let ball = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
        NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.67, blue: 0.35, alpha: 1),
                            NSColor(calibratedRed: 0.94, green: 0.45, blue: 0.14, alpha: 1),
                            NSColor(calibratedRed: 0.75, green: 0.27, blue: 0.08, alpha: 1)],
                   atLocations: [0, 0.55, 1], colorSpace: .deviceRGB)!
            .draw(in: ball, relativeCenterPosition: NSPoint(x: -0.35, y: 0.4))

        NSGraphicsContext.saveGraphicsState()
        ball.addClip()
        NSColor(calibratedRed: 0.16, green: 0.07, blue: 0.04, alpha: 1).setStroke()
        let c = NSPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2 - 1
        let seams = NSBezierPath()
        seams.move(to: NSPoint(x: c.x, y: c.y - r)); seams.line(to: NSPoint(x: c.x, y: c.y + r))
        seams.move(to: NSPoint(x: c.x - r, y: c.y)); seams.line(to: NSPoint(x: c.x + r, y: c.y))
        for side: CGFloat in [-1, 1] {
            let rr = r * 0.95, cx = c.x + side * r * 1.2
            seams.appendOval(in: NSRect(x: cx - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr))
        }
        seams.lineWidth = 1.1
        seams.stroke()
        NSGraphicsContext.restoreGraphicsState()
        return true
    }
    img.accessibilityDescription = "Hoops Ticker"
    return img
}

// MARK: - App delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var panel: NSPanel!
    private var ticker: TickerView!
    private var statusItem: NSStatusItem!
    private let settings = SettingsController()

    private var games: [Game] = []          // today
    private var lookahead: [[Game]] = []    // tomorrow onward, one array per day
    private var favoriteNext: Game?         // favorite team's next game from its season schedule
    private var top25: [RankedTeam] = []
    private var lastUpdate: Date?
    private var lastError: String?

    private let lookaheadDays = 6
    private let barHeight: CGFloat = 44
    private lazy var font = NSFont.monospacedSystemFont(ofSize: 22, weight: .heavy)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ticker = TickerView(frame: .zero)
        ticker.speed = CGFloat(Prefs.speed)
        panel.contentView = ticker

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = menuBarBall()
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        ticker.menu = menu

        settings.onChange = { [weak self] change in self?.settingChanged(change) }

        NotificationCenter.default.addObserver(self, selector: #selector(layoutPanel),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        layoutPanel()
        if !Prefs.hidden { panel.orderFrontRegardless() }
        render()

        Task { await refreshLoop() }
        Task { await lookaheadLoop() }
        Task { await top25Loop() }
        Task { await loadTeams() }
        if ProcessInfo.processInfo.environment["HOOPS_DEBUG"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.settings.show() }
        }
    }

    // MARK: Layout

    @objc private func layoutPanel() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let y = Prefs.atTop ? vf.maxY - barHeight : vf.minY
        panel.setFrame(NSRect(x: screen.frame.minX, y: y, width: screen.frame.width, height: barHeight), display: true)
        ticker.frame = NSRect(x: 0, y: 0, width: screen.frame.width, height: barHeight)
    }

    // MARK: Data

    private func refreshLoop() async {
        var first = true
        while true {
            do {
                games = try await ESPN.fetchBoard(daysFromNow: 0)
                lastUpdate = Date()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
            render()
            if first, !games.isEmpty { ticker.resetToStart(); first = false }
            let anyLive = games.contains { $0.state == .live }
            try? await Task.sleep(nanoseconds: UInt64(anyLive ? 20 : 120) * 1_000_000_000)
        }
    }

    private func lookaheadLoop() async {
        var first = true
        while true {
            lookahead = await ESPN.fetchLookahead(days: lookaheadDays)
            await refreshFavoriteNext()
            render()
            // On launch, a favorite that isn't playing today only appears once lookahead arrives.
            if first, Prefs.favoriteTeamID != nil { ticker.resetToStart() }
            first = false
            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
        }
    }

    private func refreshFavoriteNext() async {
        guard let fav = Prefs.favoriteTeamID else { favoriteNext = nil; return }
        favoriteNext = try? await ESPN.fetchNextGame(teamID: fav)
    }

    private func top25Loop() async {
        while true {
            if let t = try? await ESPN.fetchTop25(), !t.isEmpty { top25 = t }
            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
        }
    }

    private func loadTeams() async {
        for attempt in 0..<5 {
            if let t = try? await ESPN.fetchTeams(), !t.isEmpty {
                settings.setTeams(t)
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(10 + attempt * 20) * 1_000_000_000)
        }
    }

    /// Builds the ticker's game list: favorite first, then live, upcoming, finals.
    private func visibleGames() -> [Game] {
        var list = games
        if Prefs.rankedOnly { list = list.filter { $0.isRanked } }
        if !Prefs.showFinals { list = list.filter { $0.state != .final } }
        if !Prefs.showUpcoming { list = list.filter { $0.state != .upcoming } }

        var ids = Set(list.map { $0.id })
        if Prefs.showUpcoming {
            // Nothing left to play today: show the next day that has games.
            if !games.contains(where: { $0.state != .final }),
               let day = lookahead.first(where: { !$0.isEmpty }) {
                for g in day where (!Prefs.rankedOnly || g.isRanked) && ids.insert(g.id).inserted {
                    list.append(g)
                }
            }
            // Every Top 25 team not playing today gets its next game, however many days out.
            var covered = Set(games.flatMap { [$0.away.teamID, $0.home.teamID] })
            let ahead = lookahead.joined().filter { $0.state == .upcoming && $0.isRanked }.sorted { $0.start < $1.start }
            for g in ahead {
                let rankedTeams = [g.away, g.home].filter { $0.rank != nil }.map { $0.teamID }
                guard rankedTeams.contains(where: { !covered.contains($0) }) else { continue }
                covered.formUnion(rankedTeams)
                if ids.insert(g.id).inserted { list.append(g) }
            }
        }

        func order(_ s: GameState) -> Int { s == .live ? 0 : (s == .upcoming ? 1 : 2) }
        list.sort {
            if order($0.state) != order($1.state) { return order($0.state) < order($1.state) }
            if $0.state == .upcoming, $0.start != $1.start { return $0.start < $1.start }
            if $0.bestRank != $1.bestRank { return $0.bestRank < $1.bestRank }
            return $0.start < $1.start
        }

        if let fav = favoriteGame() {
            list.removeAll { $0.id == fav.id }
            list.insert(fav, at: 0)
        }
        return list
    }

    /// Favorite's game: today's (live > upcoming > final), else the soonest upcoming one.
    private func favoriteGame() -> Game? {
        guard let fav = Prefs.favoriteTeamID else { return nil }
        let today = games.filter { $0.involves(fav) }
        if let g = today.first(where: { $0.state == .live }) ?? today.first(where: { $0.state == .upcoming }) {
            return g
        }
        let ahead = lookahead.joined().filter { $0.involves(fav) && $0.state == .upcoming }.min { $0.start < $1.start }
        if let f = today.first(where: { $0.state == .final }) { return f }
        return ahead ?? favoriteNext
    }

    private func render() {
        ticker.speed = CGFloat(Prefs.speed)
        let list = visibleGames()
        ticker.set(buildTickerText(list, favoriteID: Prefs.favoriteTeamID, font: font))
        if ProcessInfo.processInfo.environment["HOOPS_DEBUG"] != nil {
            print("--- render: \(list.count) games, lookahead days loaded: \(lookahead.filter { !$0.isEmpty }.count)")
            for g in list.prefix(200) {
                print(" ", g.state, g.away.rank.map { "#\($0)" } ?? "", g.away.name, "@", g.home.rank.map { "#\($0)" } ?? "", g.home.name, "|", g.detail)
            }
            fflush(stdout)
        }
        let live = games.filter { $0.state == .live }.count
        statusItem.button?.title = live > 0 ? " \(live)" : ""
        settings.sync()
    }

    private func settingChanged(_ change: SettingChange) {
        switch change {
        case .position:
            layoutPanel()
            ticker.needsDisplay = true
        case .display:
            render()
        case .favorite:
            favoriteNext = nil
            render()
            ticker.resetToStart()
            Task {
                await refreshFavoriteNext()
                render()
                ticker.resetToStart()
            }
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let live = games.filter { $0.state == .live }.count
        let up = games.filter { $0.state == .upcoming }.count
        let fin = games.filter { $0.state == .final }.count
        var status = "Today: \(live) live · \(up) upcoming · \(fin) final"
        if let e = lastError, lastUpdate == nil { status = "Can't reach ESPN (\(e))" }
        menu.addItem(withTitle: status, action: nil, keyEquivalent: "").isEnabled = false
        if let t = lastUpdate {
            let f = DateFormatter(); f.timeStyle = .medium
            menu.addItem(withTitle: "Updated \(f.string(from: t))", action: nil, keyEquivalent: "").isEnabled = false
        }
        if let name = Prefs.favoriteTeamName {
            menu.addItem(withTitle: "★ Following \(name)", action: nil, keyEquivalent: "").isEnabled = false
        }
        menu.addItem(.separator())

        menu.addItem(item(panel.isVisible ? "Hide Ticker" : "Show Ticker", #selector(toggleTicker)))
        menu.addItem(item("Refresh Now", #selector(refreshNow)))
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())

        menu.addItem(item("Top 25 Games Only", #selector(toggleRankedOnly), checked: Prefs.rankedOnly))
        menu.addItem(item("Show Final Scores", #selector(toggleFinals), checked: Prefs.showFinals))
        menu.addItem(item("Show Upcoming Games", #selector(toggleUpcoming), checked: Prefs.showUpcoming))
        menu.addItem(.separator())

        let speedMenu = NSMenu()
        for (title, v) in Prefs.speeds {
            let it = item(title, #selector(setSpeed(_:)), checked: Prefs.speed == v)
            it.representedObject = v
            speedMenu.addItem(it)
        }
        let speedItem = NSMenuItem(title: "Scroll Speed", action: nil, keyEquivalent: "")
        speedItem.submenu = speedMenu
        menu.addItem(speedItem)

        let posMenu = NSMenu()
        posMenu.addItem(item("Bottom of Screen", #selector(setBottom), checked: !Prefs.atTop))
        posMenu.addItem(item("Top of Screen", #selector(setTop), checked: Prefs.atTop))
        let posItem = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        posItem.submenu = posMenu
        menu.addItem(posItem)
        menu.addItem(.separator())

        let topMenu = NSMenu()
        if top25.isEmpty {
            topMenu.addItem(withTitle: "Loading…", action: nil, keyEquivalent: "").isEnabled = false
        } else {
            for t in top25 {
                let rec = t.record.isEmpty ? "" : "  (\(t.record))"
                topMenu.addItem(withTitle: String(format: "%2d  %@%@", t.rank, t.name, rec), action: nil, keyEquivalent: "").isEnabled = false
            }
        }
        let topItem = NSMenuItem(title: "AP Top 25", action: nil, keyEquivalent: "")
        topItem.submenu = topMenu
        menu.addItem(topItem)
        menu.addItem(.separator())
        menu.addItem(item("Quit Hoops Ticker", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, checked: Bool = false, key: String = "") -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        it.state = checked ? .on : .off
        return it
    }

    @objc private func toggleTicker() {
        if panel.isVisible { panel.orderOut(nil); Prefs.hidden = true }
        else { panel.orderFrontRegardless(); Prefs.hidden = false }
    }
    @objc private func refreshNow() {
        Task {
            if let g = try? await ESPN.fetchBoard(daysFromNow: 0) { games = g; lastUpdate = Date(); lastError = nil }
            lookahead = await ESPN.fetchLookahead(days: lookaheadDays)
            await refreshFavoriteNext()
            render()
        }
    }
    @objc private func openSettings() { settings.show() }
    @objc private func toggleRankedOnly() { Prefs.rankedOnly.toggle(); render() }
    @objc private func toggleFinals() { Prefs.showFinals.toggle(); render() }
    @objc private func toggleUpcoming() { Prefs.showUpcoming.toggle(); render() }
    @objc private func setSpeed(_ s: NSMenuItem) { Prefs.speed = s.representedObject as? Double ?? 2.0; render() }
    @objc private func setBottom() { Prefs.atTop = false; settingChanged(.position); settings.sync() }
    @objc private func setTop() { Prefs.atTop = true; settingChanged(.position); settings.sync() }
    @objc private func quit() { NSApp.terminate(nil) }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
