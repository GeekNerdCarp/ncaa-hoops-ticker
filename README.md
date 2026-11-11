# 🏀 Hoops Ticker

A scrolling, LED-style men's college basketball score ticker for your Mac.

![Hoops Ticker showing a favorite team's next game and live scores](docs/ticker.png)

## Features

- **Every Division I game.** Live scores, today's finals and upcoming tip times, with AP rankings, team records and logos.
- **Follow your favorite team, and more.** Pick any of the 365 D1 teams, plus up to 5 more. Their games scroll first, whether live, today's final, or a game a week away, and they get a ★.
- **Just your team, if you like.** **Show only my team's game** holds that one game still in the center in your team's colors, updating the score every 10 seconds while it's live.
- **Team alerts.** Mac notifications at tip-off, halftime, a close finish and the final.
- **Knows what matters.** Red **UPSET ALERT** and **CLOSE** badges and a gold **MARQUEE** badge for top-10 matchups move those games up, and a soft glow marks your team's scores or the big moments.
- **Click for a box score.** Click any game for team stats, top scorers and the last play, with a button to open it on ESPN. TV channels show on upcoming games.
- **Filter by conference or channel.** Show just the SEC, Big Ten, or any other conference, or only games on the channels you have. Your followed teams always come through.
- **Menu-bar score.** Put your team's live score right in the menu bar, and let the bar hide itself unless your team is playing.
- **Reminders and poll alerts.** A notification before tip-off, and when the weekly AP poll comes out telling you how your teams moved.
- **Spoiler-free mode.** Hide scores (and the alerts that would give them away) for games you're recording.
- **March ready.** NCAA Tournament games show seeds and the round instead of AP rankings.
- **Looks ahead.** Top 25 teams with no game today show their next game, up to 6 days out, so the ticker is never empty on an off night.
- **AP Top 25 in the menu bar.** The full poll with records, plus a live-game count on the 🏀 icon.
- **Your choice of display.** Top 25 only, finals and upcoming on or off, four text sizes, an opacity slider, three scroll speeds, pause on hover, top or bottom of the screen, any monitor, and an option to open at login.
- **Small and native.** Written in Swift with AppKit. No Electron, no account, no ads, no tracking.

## Install

1. Download **Hoops-Ticker.dmg** from the [latest release](../../releases/latest). It's signed and notarized by Apple, so it opens without a security warning.
2. Open it and drag **Hoops Ticker** into **Applications**.
3. Launch it. The ticker appears along the bottom of your screen and 🏀 appears in the menu bar.

Requires macOS 12 or later. Runs on Apple Silicon and Intel Macs.

## Using it

Click 🏀 in the menu bar for:

- **Settings…** to choose your teams, conference, display, position, scroll speed, alerts and which games to show, and to browse the AP Top 25
- **Hide / Show Ticker**
- **Refresh Now**
- **Check for Updates…**

You can also right-click the ticker to open the same menu.

## Updates

Hoops Ticker updates itself. It checks this repository's latest GitHub release shortly after it launches and once a day; when there's a newer version it shows what's new, and one click downloads, installs and relaunches it. Updates are signed, and the app refuses any that don't match. It only reads the public release information and sends nothing about you. You can turn automatic checks off in Settings and use **Check for Updates…** whenever you like.

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

Scores, schedules, teams and rankings come from ESPN's public scoreboard API. That API isn't officially documented, so ESPN could change it at any time. The ticker refreshes every 20 seconds while games are live and every 2 minutes otherwise.

This project isn't affiliated with or endorsed by ESPN or the NCAA.

## License

[GPL-3.0](LICENSE). You're free to use, modify and share this code, and any version you distribute must stay open source under the same license.

© 2026 GeekNerdCarp
