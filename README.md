# Timelock

A macOS app that combines **Toggl-style time tracking** with **Freedom-style blocking**. You pick an activity (e.g. "Working"), start its stopwatch, and while it runs, the websites and apps assigned to that activity are blocked. Stop the timer and the blocks lift.

---

## Core Idea

> Starting an activity = starting a timer **and** activating a blocking profile.

| Concept | Meaning |
|---|---|
| **Activity** | A named thing you do (Working, Studying, Writing). Has a color, a running total, and an attached block list. |
| **Block rule** | A website domain or an app that is blocked while a given activity is running. |
| **Session** | One continuous run of an activity: start time, end time, duration. Sessions are the time-tracking records. |

**Example:** "Working" blocks `youtube.com` and the Discord app. Start "Working" → the stopwatch starts counting up, YouTube stops loading, and Discord is closed if opened. Stop it → everything is unblocked.

---

## User Experience

### Menu bar app (primary surface)
The app lives in the menu bar, like Toggl Track's mini timer.

- Menu bar shows the running activity and elapsed time: `● Working  01:23:45`
- Clicking opens a popover:
  - List of activities, each with a play button
  - Currently running activity at the top with a large stopwatch and a Stop button
  - Today's total time
- Only **one activity runs at a time**. Starting another stops the current one (and swaps the block list).

### Main window
- **Activities**: create/edit/delete, choose color, manage block list.
- **Timeline / History**: list of sessions by day; edit start/end, delete, or add a manual entry.
- **Reports**: time per activity by day / week / month (bar chart + totals).
- **Settings**: launch at login, strictness mode, global always-blocked list, notifications.

### Stopwatch behavior
- Counts up from 0 when an activity starts; shown as `HH:MM:SS`.
- Elapsed time is computed from the stored `startedAt` timestamp (`now - startedAt`), never by incrementing a counter. This keeps it accurate across sleep, app restarts, and crashes.
- Start / Stop only. There is no pause.

---

## Blocking

### Websites
**Decision: keep it simple.** Block websites by editing the hosts file (`/etc/hosts`), mapping blocked domains to `0.0.0.0` / `::`. No paid Apple Developer account, no Network Extension, no daemon.

- Works in every browser. Doesn't catch subdomains unless listed (each rule expands to `domain` and `www.domain`), and browsers using DNS-over-HTTPS can bypass it. Accepted trade-offs.
- Root access comes from a single small script, `timelock-hosts` (`block <domains…>` / `unblock`), installed once at `/usr/local/bin/`, owned by root and not writable by the user.
- A one-time `sudoers` rule lets the app run only that script without a password:

  ```
  youruser ALL=(root) NOPASSWD: /usr/local/bin/timelock-hosts
  ```

- The app calls `sudo /usr/local/bin/timelock-hosts block youtube.com …` on start and `… unblock` on stop, then flushes the DNS cache.
- Website blocking sits behind a small `WebsiteBlocker` interface, so a Network Extension (or privileged helper) can replace it later if the app is ever distributed to others.

Blocked entries are wrapped in marker comments so they can be removed cleanly:

```
# >>> Timelock BEGIN
0.0.0.0 youtube.com
0.0.0.0 www.youtube.com
# <<< Timelock END
```

Each rule expands to common variants (`domain`, `www.domain`) automatically.

### Apps
- Subscribe to `NSWorkspace.didLaunchApplicationNotification`.
- When a blocked app (matched by **bundle identifier**, e.g. `com.hnc.Discord`) launches during a running activity, terminate it and show a notification: "Discord is blocked while *Working* is running."
- On activity start, also quit any already-running blocked apps (ask nicely with `terminate()`, then `forceTerminate()` after a short grace period).
- Adding apps: pick from `/Applications` via a file picker or a list of currently installed apps.

Stronger option later: Endpoint Security framework to deny the exec before it starts. Requires a special Apple entitlement, so not in the MVP.

### Browsers / limits
- Hosts-file blocking doesn't catch already-open connections; the app flushes the DNS cache (`dscacheutil -flushcache` + `killall -HUP mDNSResponder`) and can optionally prompt to reload the tab.
- Blocked pages just fail to load. A local "Blocked by Timelock" page is a possible nicety.

---

## Strictness Modes

Two modes, configurable per user:

1. **Gentle** (default): Stop button always works. Blocks lift instantly.
2. **Commitment**: When starting, you can set a minimum duration (e.g. 50 minutes). Stop is disabled until it elapses.

Ideas for bypass resistance (later): re-apply hosts entries if they're edited during a session, warning when a VPN/DoH profile is detected.

---

## Data Model

Stored locally with **SwiftData** (or SQLite via GRDB).

```
Activity
  id, name, color, createdAt, isArchived
  rules  -> [BlockRule]       // rules specific to this activity
  groups -> [BlockGroup]      // shared groups this activity uses

BlockGroup                    // reusable list, e.g. "Distractions"
  id, name, isGlobal          // isGlobal = applied whenever any activity runs
  rules -> [BlockRule]

BlockRule
  id, kind (website | app), value (domain or bundle id), displayName
  // belongs to either one Activity or one BlockGroup

Session
  id, activity -> Activity, startedAt, endedAt (nil while running), note
  minimumEndAt (nil = Gentle; set = Commitment, Stop disabled until then)
```

A currently running session is simply a `Session` with `endedAt == nil`. On launch, the app looks for one and resumes: stopwatch continues and blocks are re-applied.

---

## Architecture

```
┌─────────────────────────────┐
│  Timelock.app (SwiftUI)    │
│  - Menu bar popover / UI    │
│  - TimerService             │
│  - AppBlocker (NSWorkspace) │
│  - SwiftData store          │
└──────────────┬──────────────┘
               │ sudo (no password)
┌──────────────▼──────────────┐
│  timelock-hosts script      │
│  (run via sudo, no password)│
│  - Edits /etc/hosts         │
│  - Flushes DNS              │
└─────────────────────────────┘
```

- **Language / UI**: Swift + SwiftUI, `MenuBarExtra` for the menu bar item.
- **State**: a single `TimerService` owns the "current session" and publishes changes; starting/stopping it calls `BlockingCoordinator`, which fans out to the website blocker (`timelock-hosts` script) and app blocker.
- **Target**: macOS 14+.
- **Distribution**: personal use for now, run locally. Sharing it later would mean Developer ID signing + notarization and replacing the sudoers setup.

---

## Tech Stack

Native **Swift + SwiftUI**, using only Apple frameworks (no third-party dependencies). Target: macOS 14+.

| Need | Technology |
|---|---|
| Language and UI | Swift 5.9+, SwiftUI |
| Menu bar item and popover | `MenuBarExtra` |
| Stopwatch | `Timer` / `TimelineView`, computed as `now - startedAt` |
| Local storage | SwiftData |
| App blocking | `NSWorkspace` launch notifications + `NSRunningApplication.terminate()` |
| Website blocking | Shell script editing `/etc/hosts`, run via `Process` + `sudo` |
| Charts (Reports) | Swift Charts |
| Launch at login | `SMAppService.mainApp` |
| Notifications | `UserNotifications` |
| Tooling | Xcode, XCTest (timer and rule logic) |

---

## Key Flows

**Start activity**
1. User clicks ▶ on "Working".
2. Stop any running session (save `endedAt`).
3. Create a new `Session(startedAt: now)`.
4. Resolve rules: activity rules + global rules.
5. The script writes hosts entries and flushes DNS; app blocker quits running blocked apps and begins watching launches.
6. Menu bar starts showing the elapsed time.

**Stop activity**
1. Set `endedAt = now`.
2. The script removes the Timelock block from hosts, flushes DNS.
3. App blocker stops watching.

**Crash / reboot recovery**
- On launch, if a session has `endedAt == nil`, resume it and re-apply blocks.
- On launch, if no session is running, the app runs `unblock` to clear any stale hosts entries.

**Mac sleeps / lid closed**
- Session keeps running by timestamp. Optional setting: auto-stop after N minutes idle.

---

## Roadmap

**MVP (v0.1)**
- Menu bar app with activities and a start/stop stopwatch
- Session history persisted locally
- App blocking (NSWorkspace) + website blocking (hosts file via `timelock-hosts` script)
- Per-activity block lists

**v0.2**
- Reports (daily/weekly totals, charts)
- Manual entries and editing sessions
- Global always-blocked list, launch at login
- Commitment mode

**v0.3+**
- Network Extension for robust web blocking
- Scheduled activities (auto-start Working at 9:00 on weekdays)
- Idle detection, keyboard shortcut to toggle, iCloud sync, CSV export
- Toggl import/sync

---

## Decisions

- **Start / Stop only.** No pause or resume.
- **One running activity at a time.** No overlapping activities.
- **Gentle is the default** strictness mode.
- **Personal use only.** The app won't be shared, so the sudoers approach stays.
- **Commitment is per session.** The minimum duration is chosen each time an activity starts (optional; leaving it empty means Gentle).
- **Shared block lists.** Groups like "Distractions" can be reused by several activities (e.g. Working and Studying).

