# 🏀 Hoops Ticker

**Every men's college basketball score, scrolling along the edge of your Mac, like the crawl on a sports channel.**

Live scores, AP rankings, logos and TV channels for every Division I game, plus alerts for your team, box scores in one click, and a spoiler-free mode for games you're recording. It's free, open source, native Swift and signed and notarized by Apple, with no account and no tracking.

![Hoops Ticker showing a favorite team's next game and live scores](docs/ticker.png)

**[⬇ Download the latest version](../../releases/latest)** · macOS 12 or later · Apple Silicon and Intel

## Why you'll like it

- **No browser tab, no app to keep open.** Scores scroll by while you work, and you can see them at a glance.
- **It knows your team.** Follow your favorite and up to 5 more. Their games come first, they get alerts, and the ticker can even shrink down to just their game.
- **It knows what matters.** Upsets, close finishes and top-10 showdowns are badged and moved to the front, so you know what to switch on.
- **It stays out of the way.** Pause it with your pointer, fade it with an opacity slider, or let it hide itself until your team tips off.

## Features

### 📺 Every game, at a glance

- **All 365 Division I teams.** Live scores with the clock and period, today's finals, and tonight's tip times.
- **AP rankings, records and logos** next to every team: `#3 DUKE 71 – #12 UNC 68 · 14:22 2ND`.
- **TV channel on upcoming games**, like `7:00 PM · ESPN`.
- **Never empty on an off night.** Top 25 teams without a game today show their next game, up to 6 days out.
- **March ready.** NCAA Tournament games show seeds and the round, like `(1) ARIZONA · SWEET 16`, instead of AP ranks.

### ★ Built around your team

- **Follow your favorite team, plus up to 5 more.** Their games always lead the ticker with a ★, whether live, today's final, or a game days away.
- **Show only my team's game.** The ticker holds that one game still in the center of the bar, in your team's colors, and refreshes the score every 10 seconds while it's live. Turn it on from the menu bar with one click.

  ![Only my team's game, in Kentucky colors](docs/only-my-team.png)

- **Team alerts.** Mac notifications at tip-off, halftime, a close finish and the final score.
- **Pre-game reminders.** A heads-up 15 minutes, 30 minutes or 1 hour before tip-off.
- **AP poll alerts.** When the new poll drops, a notification tells you how your teams moved: up, down, into the poll or out of it.
- **Score in the menu bar.** Put your team's live score right next to the clock.
- **Auto-hide.** Let the ticker bar disappear unless your team is playing. You can still show or hide it by hand any time.

### 🔥 Knows what matters

- **🔴 UPSET ALERT** when an unranked team is beating a ranked one.
- **CLOSE** when a game is within 5 points late.
- **🟡 MARQUEE** when two top-10 teams meet.
- Badged live games jump to the front of the ticker.
- **Score flash.** A soft glow when a score changes. Choose your team's scores, the big moments (lead changes, ties and one-possession games in the last 4 minutes), every game, or off.

### 📊 Click for more

- **Box scores.** Click any game for a popup with team stats, top scorers and the last play, plus a button to open it on ESPN.
- Prefer ESPN? Set clicks to open the game page instead.

### 🙈 Spoiler-free mode

Recording the game? Spoiler-free mode hides scores for your teams' games or for every game, and your alerts say "Score hidden" instead of giving away the result. Turn it on or off from the menu bar.

### 🎛 Make it yours

- **Filter by conference.** Just the SEC, the Big Ten, or any other conference. Your followed teams still come through.
- **Filter by channel.** Only show games on the channels you can actually watch. Your followed teams still come through.
- **Pick what shows:** Top 25 games only, final scores, upcoming games, logos, records, badges.
- **Pick how it looks:** top or bottom of the screen, any monitor, four text sizes, an opacity slider and three scroll speeds.
- **Pause on hover** so you can read a score.
- **Open at login** (macOS 13 or later).

### ⚡ Small, native and private

- Written in Swift with AppKit. No Electron, no web view, almost no CPU.
- Refreshes every 20 seconds while games are live and backs off to every 2 minutes when they aren't.
- No account, no ads, no analytics, no tracking. It only talks to ESPN's public scoreboard and this repository's release feed.
- **Updates itself.** One click installs a new version and relaunches. Updates are signed, and the app rejects any that don't match.

## Install

1. Download **Hoops-Ticker.dmg** from the [latest release](../../releases/latest). It's signed and notarized by Apple, so it opens without a security warning.
2. Open it and drag **Hoops Ticker** into **Applications**.
3. Launch it. The ticker appears along the bottom of your screen and 🏀 appears in the menu bar.
4. Open **Settings…** from the 🏀 menu and pick your team.

Requires macOS 12 or later. Runs on Apple Silicon and Intel Macs.

## Using it

Click 🏀 in the menu bar, or right-click the ticker, for:

- Today's count of live, upcoming and final games, and when it last updated
- The teams you follow, and **Show Only *your team***
- **Spoiler-Free Mode**
- **Hide / Show Ticker**
- **Refresh Now**
- **Settings…** (⌘,)
- **Check for Updates…**

The 🏀 icon also shows how many games are live right now.

### Settings at a glance

| Tab | What's there |
|---|---|
| **Teams** | Favorite team, up to 5 more teams, show only my team's game, team colors, team alerts, pre-game reminder, AP poll alerts, conference filter, channel filter |
| **Ticker** | Top or bottom, which monitor, scroll speed, text size, bar opacity, pause on hover, menu-bar score, auto-hide |
| **Games** | Top 25 only, finals, upcoming games, records, logos, upset and close tags, marquee tags, score flash, what clicking a game does, spoiler-free mode |
| **General** | Open at login, automatic update checks, and the full AP Top 25 with records |

## Updates

Hoops Ticker updates itself. It checks this repository's latest GitHub release shortly after it launches and once a day. When there's a newer version, it shows what's new, and one click downloads, installs and relaunches it. Updates are signed, and the app refuses any that don't match. It only reads the public release information and sends nothing about you. You can turn automatic checks off in Settings and use **Check for Updates…** whenever you like.

## Build from source

You need Xcode or the Swift toolchain (Swift 5.9 or later).

```bash
git clone https://github.com/GeekNerdCarp/ncaa-hoops-ticker.git
cd ncaa-hoops-ticker
./build.sh
open "dist/Hoops Ticker.app"
```

`build.sh` produces an ad-hoc signed universal app, which is enough to run it on your own Mac. To make a signed, notarized DMG for sharing, see `release.sh`.

## Where the data comes from

Scores, schedules, teams and rankings come from ESPN's public scoreboard API. That API isn't officially documented, so ESPN could change it at any time.

This project isn't affiliated with or endorsed by ESPN or the NCAA.

## Feedback

Found a bug or want a feature? [Open an issue](../../issues). Intel Macs and multi-monitor setups are especially helpful to hear about.

## License

[GPL-3.0](LICENSE). You're free to use, modify and share this code, and any version you distribute must stay open source under the same license.

© 2026 GeekNerdCarp
