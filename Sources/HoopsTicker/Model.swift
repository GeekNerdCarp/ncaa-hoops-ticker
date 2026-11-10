import Foundation

// MARK: - ESPN JSON (only the fields we use; everything else ignored)

struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

struct StatusJSON: Decodable {
    let type: Ty
    struct Ty: Decodable {
        let state: String          // "pre", "in", "post"
        let shortDetail: String?   // e.g. "13:02 - 1st", "Halftime", "Final"
    }
}

struct CompetitorJSON: Decodable {
    let homeAway: String
    let score: String?
    let team: Tm
    let curatedRank: Rk?
    struct Tm: Decodable {
        let id: String
        let displayName: String
        let shortDisplayName: String?
    }
    struct Rk: Decodable { let current: Int }

    enum CodingKeys: String, CodingKey { case homeAway, score, team, curatedRank }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        homeAway = try c.decode(String.self, forKey: .homeAway)
        team = try c.decode(Tm.self, forKey: .team)
        curatedRank = try? c.decode(Rk.self, forKey: .curatedRank)
        // Scoreboard sends score as "71"; team schedule sends {"displayValue":"71"}.
        if let s = try? c.decode(String.self, forKey: .score) {
            score = s
        } else if let o = try? c.decode([String: Lossy<String>].self, forKey: .score) {
            score = o["displayValue"]?.value
        } else {
            score = nil
        }
    }
}

struct Board: Decodable {
    let events: [Lossy<Ev>]
}

struct Ev: Decodable {
    let id: String
    let date: String
    let status: StatusJSON?          // scoreboard puts status here…
    let competitions: [Comp]
    struct Comp: Decodable {
        let status: StatusJSON?      // …team schedule puts it here
        let competitors: [CompetitorJSON]
    }
}

struct TeamsResponse: Decodable {
    let sports: [S]
    struct S: Decodable { let leagues: [L] }
    struct L: Decodable { let teams: [W] }
    struct W: Decodable { let team: T }
    struct T: Decodable { let id: String; let displayName: String }
}

struct RankingsResponse: Decodable {
    let rankings: [Poll]
    struct Poll: Decodable {
        let name: String
        let ranks: [Rank]
    }
    struct Rank: Decodable {
        let current: Int
        let recordSummary: String?
        let team: T
        struct T: Decodable {
            let location: String
            let nickname: String?
        }
    }
}

// MARK: - App model

enum GameState { case live, upcoming, final }

struct Side {
    let teamID: String
    let name: String
    let rank: Int?      // 1...25, nil if unranked
    let score: String?
}

struct Game {
    let id: String
    let state: GameState
    let away: Side
    let home: Side
    let detail: String
    let start: Date

    var bestRank: Int { min(away.rank ?? 99, home.rank ?? 99) }
    var isRanked: Bool { bestRank <= 25 }
    func involves(_ teamID: String) -> Bool { away.teamID == teamID || home.teamID == teamID }
}

struct RankedTeam {
    let rank: Int
    let name: String
    let record: String
}

struct TeamInfo {
    let id: String
    let name: String
}

// MARK: - Networking

enum ESPN {
    static let base = "https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball"

    private static let startParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        return f
    }()

    private static let timeOnly: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private static let dayAndTime: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE M/d h:mm a"; return f
    }()

    private static let dateParam: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/New_York")
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    private static func get<T: Decodable>(_ type: T.Type, _ url: String) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: URL(string: url)!)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// One day's scoreboard. -1 = yesterday, 0 = today, 1 = tomorrow, …
    /// Always asks for a specific date: ESPN's undated scoreboard keeps showing
    /// yesterday's games until well into the morning.
    static func fetchBoard(daysFromNow: Int) async throws -> [Game] {
        try await fetchBoard(on: Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!)
    }

    /// The scoreboard for the (Eastern time) date that contains `day`.
    static func fetchBoard(on day: Date) async throws -> [Game] {
        let url = "\(base)/scoreboard?groups=50&limit=400&dates=\(dateParam.string(from: day))"
        let board = try await get(Board.self, url)
        return board.events.compactMap { $0.value }.compactMap(makeGame)
    }

    /// What the ticker treats as "today": all of today's games, plus yesterday's games
    /// that are still going or haven't tipped off (late games run past midnight), plus,
    /// before noon, last night's final scores.
    static func fetchToday() async throws -> [Game] {
        async let todayBoard = fetchBoard(daysFromNow: 0)
        async let yesterdayBoard = try? fetchBoard(daysFromNow: -1)
        var games = try await todayBoard
        let morning = Calendar.current.component(.hour, from: Date()) < 12
        for g in await yesterdayBoard ?? [] where g.state != .final || morning {
            games.append(g)
        }
        var seen = Set<String>()
        return games.filter { seen.insert($0.id).inserted }
    }

    /// Days 1...n, fetched in parallel. Index 0 = tomorrow. A failed day comes back empty.
    static func fetchLookahead(days: Int) async -> [[Game]] {
        await withTaskGroup(of: (Int, [Game]).self) { group in
            for d in 1...days {
                group.addTask { (d, (try? await fetchBoard(daysFromNow: d)) ?? []) }
            }
            var out = Array(repeating: [Game](), count: days)
            for await (d, g) in group { out[d - 1] = g }
            return out
        }
    }

    /// A team's next game that hasn't started, from its full-season schedule.
    static func fetchNextGame(teamID: String) async throws -> Game? {
        let board = try await get(Board.self, "\(base)/teams/\(teamID)/schedule")
        let now = Date()
        return board.events.compactMap { $0.value }.compactMap(makeGame)
            .filter { $0.state == .upcoming && $0.start > now }
            .min { $0.start < $1.start }
    }

    static func fetchTeams() async throws -> [TeamInfo] {
        let r = try await get(TeamsResponse.self, "\(base)/teams?groups=50&limit=500")
        return (r.sports.first?.leagues.first?.teams ?? [])
            .map { TeamInfo(id: $0.team.id, name: $0.team.displayName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func fetchTop25() async throws -> [RankedTeam] {
        let r = try await get(RankingsResponse.self, "\(base)/rankings")
        guard let ap = r.rankings.first(where: { $0.name.contains("AP") }) ?? r.rankings.first else { return [] }
        return ap.ranks.map {
            RankedTeam(rank: $0.current, name: $0.team.location, record: $0.recordSummary ?? "")
        }
    }

    private static func makeGame(_ e: Ev) -> Game? {
        guard let comp = e.competitions.first,
              let status = e.status ?? comp.status,
              let away = comp.competitors.first(where: { $0.homeAway == "away" }),
              let home = comp.competitors.first(where: { $0.homeAway == "home" }) else { return nil }

        func side(_ c: CompetitorJSON) -> Side {
            let r = c.curatedRank?.current
            return Side(teamID: c.team.id,
                        name: c.team.shortDisplayName ?? c.team.displayName,
                        rank: (r != nil && r! <= 25) ? r : nil,
                        score: c.score)
        }
        let start = startParser.date(from: e.date) ?? Date()
        let state: GameState
        var detail = status.type.shortDetail ?? ""
        switch status.type.state {
        case "in":
            state = .live
        case "post":
            state = .final
            if detail.isEmpty { detail = "Final" }
        default:
            state = .upcoming
            detail = Calendar.current.isDateInToday(start)
                ? timeOnly.string(from: start)
                : dayAndTime.string(from: start)
        }
        return Game(id: e.id, state: state, away: side(away), home: side(home), detail: detail, start: start)
    }
}
