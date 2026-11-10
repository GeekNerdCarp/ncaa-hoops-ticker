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
    static let final = NSColor(calibratedWhite: 1, alpha: 0.62)   // see-through, so it suits team-colored bars too
    static let dim = NSColor(calibratedWhite: 1, alpha: 0.45)
    static let network = NSColor(calibratedWhite: 0.72, alpha: 1)
    static let alert = NSColor(calibratedRed: 1.0, green: 0.22, blue: 0.2, alpha: 1)
}

extension NSColor {
    convenience init?(hex: String?) {
        guard let hex, hex.count == 6, let v = UInt32(hex, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                  blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
    /// WCAG relative luminance, 0 (black) to 1 (white).
    var luminance: CGFloat {
        guard let c = usingColorSpace(.sRGB) else { return 0 }
        func lin(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
    }
}

/// A team's bar colors: the primary color, darkened if needed so white and gold text stay
/// readable, and an accent stripe from the second color (or the primary when that's too dark).
func teamBarColors(primary: String?, alternate: String?) -> (background: NSColor, accent: NSColor)? {
    guard let base = NSColor(hex: primary) else { return nil }
    var bg = base
    var step: CGFloat = 0
    while bg.luminance > 0.12 && step < 0.9 {
        step += 0.05
        bg = base.blended(withFraction: step, of: .black) ?? base
    }
    var accent = NSColor(hex: alternate) ?? .white
    if accent.luminance < 0.1 || abs(accent.luminance - bg.luminance) < 0.05 { accent = base.luminance > 0.1 ? base : .white }
    return (bg, accent)
}

/// Whether a live game's change between two refreshes deserves a glow.
/// mode: 0 off, 1 the favorite team scored, 2 big moments, 3 any score change.
func shouldFlash(prev: Game, now: Game, mode: Int, followed: Set<String>) -> Bool {
    func pts(_ s: Side) -> Int? { Int(s.score ?? "") }
    guard let pa = pts(prev.away), let ph = pts(prev.home), let na = pts(now.away), let nh = pts(now.home),
          (pa, ph) != (na, nh) else { return false }
    switch mode {
    case 1:
        return (followed.contains(now.away.teamID) && na > pa) || (followed.contains(now.home.teamID) && nh > ph)
    case 2:
        let before = pa - ph, after = na - nh
        let leadChange = before != 0 && after != 0 && (before > 0) != (after > 0)
        let tie = after == 0 && before != 0
        func late(_ g: Game) -> Bool { g.period >= 2 && g.clock <= 240 && !g.isHalftime }
        let onePossession = late(now) && abs(after) <= 3 && (abs(before) > 3 || !late(prev))
        return leadChange || tie || onePossession
    case 3:
        return true
    default:
        return false
    }
}

/// One attributed string per game (separator included), so the ticker only draws what's on screen.
@MainActor
func buildTickerSegments(_ games: [Game], followed: Set<String>, font: NSFont, separator: Bool = true) -> [NSAttributedString] {
    var out = NSMutableAttributedString()
    var parts: [NSAttributedString] = []
    func add(_ s: String, _ c: NSColor) {
        out.append(NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: c]))
    }
    func team(_ s: Side, showScore: Bool, live: Bool) {
        if Prefs.showLogos, let logo = LogoStore.shared.attachment(for: s.teamID, font: font) {
            out.append(NSAttributedString(attachment: logo))
            add(" ", Palette.dim)
        }
        if let r = s.rank { add("#\(r) ", Palette.rank) }
        else if let seed = s.seed { add("(\(seed)) ", Palette.rank) }
        add(s.name.uppercased(), followed.contains(s.teamID) ? Palette.favorite : Palette.name)
        if Prefs.showRecords, let rec = s.record, !rec.isEmpty { add(" (\(rec))", Palette.dim) }
        if showScore, let sc = s.score { add(" \(sc)", live ? Palette.liveScore : Palette.score) }
    }

    if games.isEmpty {
        add("NO GAMES TO SHOW RIGHT NOW", Palette.dim)
        add("          ", Palette.dim)
        return [out]
    }
    for g in games {
        let mine = followed.contains(g.away.teamID) || followed.contains(g.home.teamID)
        if mine { add("★ ", Palette.favorite) }
        if Prefs.showAlertTags, let tag = g.isUpsetBrewing ? "UPSET ALERT" : (g.isCloseLate ? "CLOSE" : nil) {
            // White on red, so it reads as a badge rather than more ticker text.
            out.append(NSAttributedString(string: " \(tag) ", attributes: [.font: font, .foregroundColor: NSColor.white,
                                                                          .backgroundColor: Palette.alert]))
            add("  ", Palette.dim)
        }
        switch g.state {
        case .live:
            team(g.away, showScore: true, live: true)
            add("  –  ", Palette.dim)
            team(g.home, showScore: true, live: true)
            add("   \(g.detail.uppercased())", Palette.live)
            if let r = g.round { add(" · \(r)", Palette.rank) }
            // Where to watch your own team's game while it's on.
            if mine, let n = g.network { add(" · \(n.uppercased())", Palette.network) }
        case .final:
            team(g.away, showScore: true, live: false)
            add("  –  ", Palette.dim)
            team(g.home, showScore: true, live: false)
            add("   \(g.detail.uppercased())", Palette.final)
            if let r = g.round { add(" · \(r)", Palette.rank) }
        case .upcoming:
            team(g.away, showScore: false, live: false)
            add("  @  ", Palette.dim)
            team(g.home, showScore: false, live: false)
            add("   \(g.detail.uppercased())", Palette.upcoming)
            if let r = g.round { add(" · \(r)", Palette.rank) }
            if let n = g.network { add(" · \(n.uppercased())", Palette.network) }
        }
        if separator { add("      ◆      ", Palette.dim) }
        parts.append(out)
        out = NSMutableAttributedString()
    }
    return parts
}

/// Scrolls the games with Core Animation: each game is drawn once into a small image,
/// and the GPU slides a strip of those images. Only games within about a screen's width
/// of the visible area exist as layers at any moment, so CPU and memory stay flat.
final class TickerView: NSView {
    private struct Segment { let text: NSAttributedString; let x: CGFloat; let width: CGFloat }

    private var lastParts: [NSAttributedString] = []
    private var segments: [Segment] = []
    private var total: CGFloat = 0
    private let strip = CALayer()
    private let accent = CALayer()
    private var liveLayers: [String: CALayer] = [:]   // "segment:copy" -> layer
    private var images: [Int: CGImage] = [:]          // segment -> rendered image
    private var tick: Timer?
    private var centered = false   // one still segment in the middle instead of scrolling
    private var background = NSColor.black
    private var accentHeight: CGFloat = 1
    private var downAt: NSPoint?
    private var keys: [String] = []               // game id for each segment ("" for messages)
    private var pendingFlash = Set<String>()      // games whose score changed, waiting to be on screen
    private var hand = false
    private var paused = false

    /// Called with the index of the segment that was clicked.
    var onClick: ((Int) -> Void)?

    /// Points per frame at 60 fps (kept from the original timer-based ticker).
    var speed: CGFloat = 2.0 {
        didSet { if speed != oldValue { restart(at: currentOffset()) } }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer!.backgroundColor = NSColor.black.cgColor
        layer!.masksToBounds = true
        strip.anchorPoint = .zero
        strip.actions = ["position": NSNull(), "sublayers": NSNull(), "bounds": NSNull()]
        layer!.addSublayer(strip)
        accent.backgroundColor = NSColor(calibratedWhite: 0.25, alpha: 1).cgColor
        accent.actions = ["position": NSNull(), "bounds": NSNull()]
        layer!.addSublayer(accent)
        // Light bookkeeping a few times a second: add layers coming into view, drop ones that left.
        tick = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.updateVisible() }
        RunLoop.main.add(tick!, forMode: .common)
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(_ parts: [NSAttributedString], keys: [String] = []) {
        self.keys = keys
        // Refreshes usually change nothing; skip the rebuild so scrolling isn't disturbed.
        guard parts != lastParts || centered else { return }
        let wasCentered = centered
        centered = false
        lastParts = parts
        let keep = currentOffset()
        var x: CGFloat = 0
        segments = parts.map { s in
            let w = ceil(s.size().width)
            defer { x += w }
            return Segment(text: s, x: x, width: w)
        }
        total = x
        clearLayers()
        restart(at: total > 0 && !wasCentered ? keep.truncatingRemainder(dividingBy: total) : 0)
    }

    /// Shows one segment, still and centered. Unchanged text costs nothing.
    func setCentered(_ text: NSAttributedString, key: String = "") {
        keys = [key]
        guard !centered || segments.first?.text != text else { return }
        centered = true
        lastParts = []
        let w = ceil(text.size().width)
        segments = [Segment(text: text, x: 0, width: w)]
        total = w
        clearLayers()
        restart(at: 0)
    }

    /// Bar colors: black with a thin grey line normally, or a team's colors.
    func setColors(background bg: NSColor, accent: NSColor, accentHeight h: CGFloat) {
        guard bg != background || accent.cgColor != self.accent.backgroundColor || h != accentHeight else { return }
        background = bg
        accentHeight = h
        layer!.backgroundColor = bg.cgColor
        self.accent.backgroundColor = accent.cgColor
        needsLayout = true
        clearLayers()   // segment images have the old background baked in
        updateVisible()
    }

    /// Glow these games once each, as soon as they're on screen (now, if they already are).
    func flash(_ ids: Set<String>) {
        pendingFlash.formUnion(ids.subtracting([""]))
        updateVisible()
    }

    /// Jump back so the first game is at the left edge.
    func resetToStart() { restart(at: 0) }

    override func layout() {
        super.layout()
        accent.frame = CGRect(x: 0, y: Prefs.atTop ? 0 : bounds.height - accentHeight, width: bounds.width, height: accentHeight)
        if centered { restart(at: 0) }
    }

    override func setFrameSize(_ newSize: NSSize) {
        let heightChanged = newSize.height != frame.height
        super.setFrameSize(newSize)
        if heightChanged { clearLayers() }
        needsLayout = true
        updateVisible()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        clearLayers()
        updateVisible()
    }

    // MARK: Clicks

    // The panel never becomes active, so take the very first click.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { downAt = convert(event.locationInWindow, from: nil) }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        defer { downAt = nil }
        guard let d = downAt, hypot(p.x - d.x, p.y - d.y) < 6, let i = segmentIndex(at: p.x) else { return }
        onClick?(i)
    }

    /// Which segment is under this x position right now (the strip may be mid-scroll).
    private func segmentIndex(at x: CGFloat) -> Int? {
        guard total > 0 else { return nil }
        let sx = x - (strip.presentation() ?? strip).position.x
        if centered { return sx >= 0 && sx < total ? 0 : nil }
        var o = sx.truncatingRemainder(dividingBy: total)
        if o < 0 { o += total }
        return segments.firstIndex { o >= $0.x && o < $0.x + $0.width }
    }

    // Pointing-hand cursor over the ticker, even though the app is never frontmost.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) {
        if !hand { NSCursor.pointingHand.push(); hand = true }
        if Prefs.pauseOnHover { setPaused(true) }
    }
    override func mouseExited(with event: NSEvent) {
        if hand { NSCursor.pop(); hand = false }
        setPaused(false)
    }

    /// Hold the strip where it is (so a score can be read), or carry on from there.
    private func setPaused(_ p: Bool) {
        guard p != paused else { return }
        let here = currentOffset()
        paused = p
        restart(at: here)
    }

    // MARK: Scrolling

    private func currentOffset() -> CGFloat {
        guard total > 0, !centered else { return 0 }
        let x = (strip.presentation() ?? strip).position.x
        let o = (-x).truncatingRemainder(dividingBy: total)
        return o < 0 ? o + total : o
    }

    private func restart(at offset: CGFloat) {
        strip.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        strip.position = CGPoint(x: centered ? ((bounds.width - total) / 2).rounded() : -offset, y: 0)
        CATransaction.commit()
        if centered || paused { updateVisible(offset: offset); return }
        let pointsPerSecond = speed * 60
        if total > 0, pointsPerSecond > 0 {
            let anim = CABasicAnimation(keyPath: "position.x")
            anim.fromValue = 0
            anim.toValue = -total
            anim.duration = Double(total / pointsPerSecond)
            anim.repeatCount = .infinity
            anim.timeOffset = Double(offset / pointsPerSecond)
            anim.isRemovedOnCompletion = false
            strip.add(anim, forKey: "scroll")
        }
        updateVisible(offset: offset)
    }

    // MARK: Layers

    private func clearLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        liveLayers.values.forEach { $0.removeFromSuperlayer() }
        CATransaction.commit()
        liveLayers.removeAll()
        images.removeAll()
    }

    private func updateVisible(offset: CGFloat? = nil) {
        guard total > 0, bounds.width > 0, bounds.height > 0 else { return }
        let off = offset ?? currentOffset()
        let margin = bounds.width
        // Cover the visible window plus a margin, and the same window one loop earlier,
        // so the layers are already there when the animation wraps back to the start.
        let ranges = centered ? [(CGFloat(0), total / 2)]
            : [(off - margin, off + bounds.width + margin),
               (off - total - margin, off - total + bounds.width + margin)]
        let scale = window?.backingScaleFactor ?? 2
        let h = bounds.height

        var wanted = Set<String>()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (start, end) in ranges {
            for j in Int((start / total).rounded(.down))...Int((end / total).rounded(.down)) {
                for (i, s) in segments.enumerated() {
                    let x = CGFloat(j) * total + s.x
                    guard x + s.width > start, x < end else { continue }
                    let key = "\(i):\(j)"
                    guard wanted.insert(key).inserted, liveLayers[key] == nil else { continue }
                    let l = CALayer()
                    l.isOpaque = true
                    l.contentsScale = scale
                    l.contents = image(for: i, scale: scale, height: h)
                    l.frame = CGRect(x: x, y: 0, width: s.width, height: h)
                    strip.addSublayer(l)
                    liveLayers[key] = l
                }
            }
        }
        for (key, l) in liveLayers where !wanted.contains(key) {
            l.removeFromSuperlayer()
            liveLayers[key] = nil
        }
        if !pendingFlash.isEmpty { flashVisible(offset: off) }
        CATransaction.commit()
        let inUse = Set(liveLayers.keys.compactMap { Int($0.split(separator: ":")[0]) })
        images = images.filter { inUse.contains($0.key) }
    }

    /// Pulse a highlight over any pending game that has scrolled well into view.
    private func flashVisible(offset off: CGFloat) {
        let viewLeft = centered ? -CGFloat.infinity : off
        let viewRight = centered ? CGFloat.infinity : off + bounds.width
        var done = Set<String>()
        for (key, l) in liveLayers {
            guard let i = Int(key.split(separator: ":")[0]), keys.indices.contains(i),
                  pendingFlash.contains(keys[i]) else { continue }
            // The layer's x is in strip coordinates, the same space as the offset.
            // Wait until most of the game is on screen, so the glow is seen.
            let x = l.frame.minX, need = min(l.frame.width, bounds.width) * 0.75
            guard x + l.frame.width >= viewLeft + need, x <= viewRight - need else { continue }
            let glow = CALayer()
            glow.frame = l.bounds.insetBy(dx: 2, dy: 4)
            glow.cornerRadius = 6
            glow.backgroundColor = Palette.liveScore.withAlphaComponent(0.22).cgColor
            glow.borderColor = Palette.liveScore.withAlphaComponent(0.55).cgColor
            glow.borderWidth = 1.5
            glow.opacity = 0
            l.addSublayer(glow)
            // One soft fade in and out.
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.3, 0.5, 1]
            fade.duration = 2.2
            fade.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .linear),
                                    CAMediaTimingFunction(name: .easeInEaseOut)]
            glow.add(fade, forKey: "flash")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { glow.removeFromSuperlayer() }
            done.insert(keys[i])
        }
        pendingFlash.subtract(done)
    }

    private func image(for i: Int, scale: CGFloat, height: CGFloat) -> CGImage? {
        if let cached = images[i] { return cached }
        let s = segments[i]
        let w = Int((s.width * scale).rounded(.up)), h = Int((height * scale).rounded(.up))
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.setFillColor(background.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: s.width, height: height))
        // AppKit string drawing honors the NSColor attributes (Core Text's CTLineDraw ignores them).
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        s.text.draw(at: NSPoint(x: 0, y: ((height - s.text.size().height) / 2).rounded()))
        NSGraphicsContext.restoreGraphicsState()
        let img = ctx.makeImage()
        images[i] = img
        return img
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
    private let updater = Updater()
    private let alerts = TeamAlerts()

    private var games: [Game] = []          // today
    private var lookahead: [[Game]] = []    // tomorrow onward, one array per day
    private var scheduleNext: [String: Game] = [:]   // each followed team's next game, from its season schedule
    private var lastUpdate: Date?
    private var lastError: String?
    private var refreshTask: Task<Void, Never>?
    private var shownGames: [Game] = []     // what each ticker segment is, for clicks
    private var teamColors: [String: (String?, String?)] = [:]   // team id -> (primary, alternate) hex
    private var lastLive: [String: Game] = [:]   // previous snapshot of each live game, to spot baskets
    private var lastFullRefresh = Date.distantPast

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
        ticker.onClick = { [weak self] i in self?.openGame(at: i) }
        LogoStore.shared.onLoad = { [weak self] in self?.render() }

        settings.onChange = { [weak self] change in self?.settingChanged(change) }

        NotificationCenter.default.addObserver(self, selector: #selector(layoutPanel),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        layoutPanel()
        if !Prefs.hidden { panel.orderFrontRegardless() }
        render()

        refreshTask = Task { await refreshLoop() }
        Task { await lookaheadLoop() }
        Task { await top25Loop() }
        Task { await loadTeams() }
        Task { await loadConferences() }
        updater.startAutomaticChecks()
        alerts.start()
        if ProcessInfo.processInfo.environment["HOOPS_DEBUG"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.settings.show() }
        }
        if ProcessInfo.processInfo.environment["HOOPS_CHECK_NOW"] != nil {   // test the manual check path
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.checkForUpdates() }
        }
    }

    // MARK: Layout

    @objc private func layoutPanel() {
        guard let screen = Displays.target else { return }
        settings.syncDisplays()   // monitors may have just been plugged in or removed
        let vf = screen.visibleFrame
        let y = Prefs.atTop ? vf.maxY - barHeight : vf.minY
        panel.setFrame(NSRect(x: screen.frame.minX, y: y, width: screen.frame.width, height: barHeight), display: true)
        ticker.frame = NSRect(x: 0, y: 0, width: screen.frame.width, height: barHeight)
    }

    // MARK: Data

    private func refreshLoop() async {
        var first = true
        while !Task.isCancelled {
            let quick = quickRefreshGame()
            if let g = quick, Date().timeIntervalSince(lastFullRefresh) < 120 {
                // Only-my-team mode during a game: fetch just that game's day, every 10 seconds.
                if let day = try? await ESPN.fetchBoard(on: g.start),
                   let fresh = day.first(where: { $0.id == g.id }),
                   let i = games.firstIndex(where: { $0.id == g.id }) {
                    games[i] = fresh
                    lastUpdate = Date()
                    lastError = nil
                }
            } else {
                do {
                    games = try await ESPN.fetchToday(group: Prefs.conferenceID ?? 50, alsoTeams: Set(Prefs.followedIDs))
                    lastUpdate = Date()
                    lastFullRefresh = Date()
                    lastError = nil
                } catch {
                    lastError = error.localizedDescription
                }
            }
            guard !Task.isCancelled else { return }
            for fav in Prefs.followedIDs {
                for g in games where g.involves(fav) { alerts.observe(g, favoriteID: fav) }
            }
            render()
            ticker.flash(scoreChanges())
            if first, !games.isEmpty { ticker.resetToStart(); first = false }
            let anyLive = games.contains { $0.state == .live }
            let wait = quickRefreshGame() != nil ? 10 : (anyLive ? 20 : 120)
            try? await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000_000)
        }
    }

    /// Live games that should glow this refresh, per the "Flash score changes" setting.
    private func scoreChanges() -> Set<String> {
        var out = Set<String>()
        for g in games where g.state == .live {
            if let prev = lastLive[g.id],
               shouldFlash(prev: prev, now: g, mode: Prefs.flashMode, followed: Set(Prefs.followedIDs)) {
                out.insert(g.id)
            }
            lastLive[g.id] = g
        }
        return out
    }

    /// In only-my-team mode, the favorite's game today if it's live or about to tip off.
    private func quickRefreshGame() -> Game? {
        guard Prefs.favoriteOnly, let g = favoriteGame(), games.contains(where: { $0.id == g.id }) else { return nil }
        if g.state == .live { return g }
        let untilTip = g.start.timeIntervalSinceNow
        return g.state == .upcoming && untilTip < 5 * 60 && untilTip > -3 * 3600 ? g : nil
    }

    /// The conference changed: fetch today and the days ahead again and start from the left.
    private func reloadEverything() {
        restartRefreshLoop()
        Task {
            lookahead = await ESPN.fetchLookahead(days: lookaheadDays, group: Prefs.conferenceID ?? 50)
            render()
            ticker.resetToStart()
        }
    }

    /// Restart the refresh loop so a new mode takes effect now rather than after its current sleep.
    private func restartRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { await refreshLoop() }
    }

    private func lookaheadLoop() async {
        var first = true
        while true {
            lookahead = await ESPN.fetchLookahead(days: lookaheadDays, group: Prefs.conferenceID ?? 50)
            await refreshScheduleNext()
            render()
            // On launch, a favorite that isn't playing today only appears once lookahead arrives.
            if first, Prefs.favoriteTeamID != nil { ticker.resetToStart() }
            first = false
            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
        }
    }

    private func refreshScheduleNext() async {
        var out: [String: Game] = [:]
        for id in Prefs.followedIDs { if let g = try? await ESPN.fetchNextGame(teamID: id) { out[id] = g } }
        scheduleNext = out
    }

    private func top25Loop() async {
        while true {
            if let t = try? await ESPN.fetchTop25(), !t.isEmpty { settings.setTop25(t) }
            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
        }
    }

    private func loadConferences() async {
        for attempt in 0..<5 {
            if let c = try? await ESPN.fetchConferences(), !c.isEmpty { settings.setConferences(c); return }
            try? await Task.sleep(nanoseconds: UInt64(10 + attempt * 20) * 1_000_000_000)
        }
    }

    private func loadTeams() async {
        for attempt in 0..<5 {
            if let t = try? await ESPN.fetchTeams(), !t.isEmpty {
                settings.setTeams(t)
                for team in t { teamColors[team.id] = (team.color, team.altColor) }
                render()
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

        // Upsets brewing, then close finishes, then other live games, upcoming, finals.
        func order(_ g: Game) -> Int {
            switch g.state {
            case .live:
                guard Prefs.showAlertTags else { return 2 }
                return g.isUpsetBrewing ? 0 : (g.isCloseLate ? 1 : 2)
            case .upcoming: return 3
            case .final: return 4
            }
        }
        list.sort {
            if order($0) != order($1) { return order($0) < order($1) }
            if $0.state == .upcoming, $0.start != $1.start { return $0.start < $1.start }
            if $0.bestRank != $1.bestRank { return $0.bestRank < $1.bestRank }
            return $0.start < $1.start
        }

        // Followed teams lead, in the order you picked them: favorite first, then the others.
        var lead: [Game] = []
        for id in Prefs.followedIDs {
            if let g = followedGame(id), !lead.contains(where: { $0.id == g.id }) { lead.append(g) }
        }
        list.removeAll { g in lead.contains { $0.id == g.id } }
        return lead + list
    }

    /// Favorite's game: today's (live > upcoming > final), else its soonest upcoming game
    /// from either the next few days' scoreboards or its season schedule.
    private func favoriteGame() -> Game? {
        guard let fav = Prefs.favoriteTeamID else { return nil }
        return followedGame(fav)
    }

    private func followedGame(_ fav: String) -> Game? {
        let today = games.filter { $0.involves(fav) }
        if let g = today.first(where: { $0.state == .live }) ?? today.first(where: { $0.state == .upcoming }) {
            return g
        }
        if let f = today.first(where: { $0.state == .final }) { return f }
        let candidates = lookahead.joined().filter { $0.involves(fav) } + [scheduleNext[fav]].compactMap { $0 }
        return candidates.filter { $0.state == .upcoming }.min { $0.start < $1.start }
    }

    private func render() {
        ticker.speed = CGFloat(Prefs.speed)
        let list = visibleGames()
        shownGames = list
        let defaultAccent = NSColor(calibratedWhite: 0.25, alpha: 1)
        if Prefs.favoriteOnly, Prefs.useTeamColors, let fav = Prefs.favoriteTeamID,
           let c = teamColors[fav], let bar = teamBarColors(primary: c.0, alternate: c.1) {
            ticker.setColors(background: bar.background, accent: bar.accent, accentHeight: 3)
        } else {
            ticker.setColors(background: .black, accent: defaultAccent, accentHeight: 1)
        }
        if Prefs.favoriteOnly, Prefs.favoriteTeamID != nil {
            shownGames = []
            if let g = favoriteGame() {
                shownGames = [g]
                ticker.setCentered(buildTickerSegments([g], followed: Set(Prefs.followedIDs), font: font, separator: false)[0], key: g.id)
            } else {
                let name = (Prefs.favoriteTeamName ?? "your team").uppercased()
                let msg = lookahead.isEmpty ? "LOADING \(name)…" : "NO UPCOMING GAME FOR \(name)"
                ticker.setCentered(NSAttributedString(string: msg, attributes: [.font: font, .foregroundColor: Palette.dim]))
            }
        } else {
            ticker.set(buildTickerSegments(list, followed: Set(Prefs.followedIDs), font: font), keys: list.map { $0.id })
        }
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

    /// Open ESPN's page for the clicked game: live gamecast, box score, or preview.
    private func openGame(at i: Int) {
        guard shownGames.indices.contains(i),
              let url = URL(string: "https://www.espn.com/mens-college-basketball/game/_/gameId/\(shownGames[i].id)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func settingChanged(_ change: SettingChange) {
        switch change {
        case .position:
            layoutPanel()
            ticker.needsLayout = true
        case .display:
            render()
        case .favoriteOnly:
            render()
            restartRefreshLoop()
        case .favorite, .followed:
            scheduleNext = scheduleNext.filter { Prefs.followedIDs.contains($0.key) }
            render()
            ticker.resetToStart()
            Task {
                await refreshScheduleNext()
                render()
                ticker.resetToStart()
            }
            restartRefreshLoop()   // the "also show followed teams' games" fetch depends on who's followed
        case .conference:
            reloadEverything()
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if let a = updater.available {
            let it = item("Update Available: Version \(a.version)…", #selector(showUpdate))
            it.attributedTitle = NSAttributedString(string: it.title,
                                                    attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)])
            menu.addItem(it)
            menu.addItem(.separator())
        }

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
            let more = Prefs.extraTeamIDs.filter { $0 != Prefs.favoriteTeamID }.count
            menu.addItem(withTitle: "★ Following \(name)" + (more > 0 ? " + \(more) more" : ""), action: nil, keyEquivalent: "").isEnabled = false
            menu.addItem(item("Show Only \(name)", #selector(toggleFavoriteOnly), checked: Prefs.favoriteOnly))
        }
        menu.addItem(.separator())

        menu.addItem(item(panel.isVisible ? "Hide Ticker" : "Show Ticker", #selector(toggleTicker)))
        menu.addItem(item("Refresh Now", #selector(refreshNow)))
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
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
            if let g = try? await ESPN.fetchToday(group: Prefs.conferenceID ?? 50, alsoTeams: Set(Prefs.followedIDs)) {
                games = g; lastUpdate = Date(); lastError = nil
            }
            lookahead = await ESPN.fetchLookahead(days: lookaheadDays, group: Prefs.conferenceID ?? 50)
            await refreshScheduleNext()
            render()
        }
    }
    @objc private func openSettings() { settings.show() }
    @objc private func checkForUpdates() { Task { await updater.check(userInitiated: true) } }
    @objc private func showUpdate() { updater.promptToDownload() }
    @objc private func toggleFavoriteOnly() {
        Prefs.favoriteOnly.toggle()
        settingChanged(.favoriteOnly)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
