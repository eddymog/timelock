# 200 – Design Plan: Timelock

How Timelock will be built. It turns the requirements in [100_Requirements.md](100_Requirements.md) (IDs like FR-401) into concrete components, data, flows and build order. For the product overview see [README.md](README.md).

---

## 1. Design Principles

1. **Timestamps, not counters.** The stopwatch is always `now - startedAt`. Nothing depends on the app staying alive.
2. **Persist first, act second.** A session is saved before blocks are applied, so a crash can always be recovered.
3. **One source of truth.** A single `TimerService` owns "what is running". Everything else reacts to it.
4. **Blocking is pluggable.** Website blocking hides behind a protocol so it can be swapped or faked in tests.
5. **Fail loudly, not silently.** If blocking can't be applied, the user is told; the app never pretends to block.

---

## 2. Project Setup

| Item | Choice |
|---|---|
| Project | Xcode macOS App, SwiftUI lifecycle, product name `Timelock` |
| Deployment target | macOS 14.0 |
| App Sandbox | **Off.** Sandboxed apps can't run `sudo`, or quit other apps. Personal use only, so this is acceptable. |
| Hardened Runtime | On |
| Dock icon | Hidden (`LSUIElement = YES`), so it's a menu bar app; the main window opens from the menu |
| Dependencies | None |

### Folder structure

```
Timelock/
├── TimelockApp.swift            // @main, MenuBarExtra + main Window scenes
├── Models/                      // SwiftData: Activity, BlockGroup, BlockRule, Session
├── Services/
│   ├── TimerService.swift       // running-session state machine
│   ├── BlockingCoordinator.swift
│   ├── WebsiteBlocker.swift     // protocol
│   ├── HostsFileBlocker.swift   // runs timelock-hosts via sudo
│   ├── AppBlocker.swift         // NSWorkspace watcher
│   └── NotificationService.swift
├── Views/
│   ├── MenuBar/                 // popover, start sheet
│   ├── Activities/              // list, editor, rule editor, groups
│   ├── History/
│   ├── Reports/
│   └── Settings/
├── Support/                     // formatting, HostsFileEditor (pure), Clock protocol
└── TimelockTests/
Scripts/
├── timelock-hosts               // root-owned hosts editor
└── install.sh                   // one-time setup (script + sudoers)
```

---

## 3. Data Model (SwiftData)

```
Activity    id, name, colorHex, createdAt, isArchived
            rules  -> [BlockRule]    (cascade delete)
            groups -> [BlockGroup]   (many-to-many)
            sessions -> [Session]    (inverse)

BlockGroup  id, name, isGlobal
            rules -> [BlockRule]     (cascade delete)
            activities -> [Activity] (inverse)

BlockRule   id, kind (.website | .app), value, displayName
            activity: Activity?      // exactly one of activity / group is set
            group: BlockGroup?

Session     id, activity, startedAt, endedAt?, note, minimumEndAt?
```

- `value` is a normalized domain (`youtube.com`, lowercase, no scheme or path) for websites, or a bundle identifier (`com.hnc.Discord`) for apps.
- A running session is one with `endedAt == nil`. There is at most one.
- `minimumEndAt == nil` means Gentle; a value means Commitment (FR-601, FR-602, FR-604).
- **Effective rules** for an activity = its own rules + rules of its groups + rules of every `isGlobal` group, de-duplicated by `(kind, value)`.

---

## 4. Core Components

### 4.1 TimerService (`@Observable`, main actor)

Owns the current session and is the only thing that starts or stops one.

```
state: .idle | .running(Session)

start(activity, minimumDuration: TimeInterval?)
stop()  throws -> StopError.commitmentActive(remaining)
elapsed: TimeInterval           // now - startedAt
canStop: Bool                   // minimumEndAt == nil || now >= minimumEndAt
recoverOnLaunch()
```

**start:**
1. If a session is running, `stop()` it first. If its Commitment is still active, this throws and the switch is refused (FR-602).
2. Insert `Session(startedAt: now, minimumEndAt: now + duration?)` and save (NFR-06).
3. Call `BlockingCoordinator.apply(rules)`.

**stop:**
1. If `!canStop`, throw `commitmentActive`.
2. Set `endedAt = now`, save.
3. Call `BlockingCoordinator.clear()`.

A 1-second `Timer` on the main run loop refreshes `elapsed` for display only; the value is always recomputed from timestamps, so a missed tick costs nothing.

### 4.2 BlockingCoordinator

Resolves effective rules, splits them by kind, and drives both blockers.

```
apply(rules)  ->  websiteBlocker.block(domains)   // async, reports failure
              ->  appBlocker.start(bundleIDs)
clear()       ->  websiteBlocker.unblock()
              ->  appBlocker.stop()
```

If the website blocker fails, the session still runs (app blocking and timing continue) and the popover shows a warning: "Website blocking unavailable – run install.sh". It doesn't silently fail (principle 5).

### 4.3 WebsiteBlocker

```swift
protocol WebsiteBlocker {
    func block(_ domains: [String]) async throws
    func unblock() async throws
}
```

`HostsFileBlocker` implements it by running:

```
/usr/bin/sudo -n /usr/local/bin/timelock-hosts block youtube.com www.youtube.com ...
/usr/bin/sudo -n /usr/local/bin/timelock-hosts unblock
```

`-n` makes sudo fail immediately instead of prompting if the `sudoers` rule is missing, so the app can show the warning instead of hanging.

### 4.4 AppBlocker

- On `start(bundleIDs)`:
  1. Quit any running match: `NSRunningApplication.runningApplications(withBundleIdentifier:)` → `terminate()`; after about 3 seconds, `forceTerminate()` if still alive (FR-501).
  2. Observe `NSWorkspace.shared.notificationCenter` for `didLaunchApplicationNotification`. If the launched app's bundle ID is blocked, terminate it and post a notification (FR-502, FR-503).
- On `stop()`: remove the observer.

### 4.5 NotificationService

Wraps `UserNotifications`. Requests permission on first use; all calls are no-ops if denied.

---

## 5. The hosts script (`timelock-hosts`)

A small shell script, the only thing that runs as root.

| Command | Behavior |
|---|---|
| `block <domain>...` | Validate every domain; remove any existing Timelock block; append a new one; flush DNS |
| `unblock` | Remove the Timelock block; flush DNS |
| `status` | Print `active` or `inactive` (used for diagnostics and recovery) |

**Block format** (FR-401, FR-402):

```
# >>> Timelock BEGIN
0.0.0.0 youtube.com
:: youtube.com
0.0.0.0 www.youtube.com
:: www.youtube.com
# <<< Timelock END
```

**Safety rules** (NFR-07 to NFR-09):
- Domains must match `^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$`; anything else aborts with a non-zero exit and no change to the file.
- Work on a temp copy, then replace `/etc/hosts` atomically. Only lines between the markers are ever touched.
- Never `eval`, and quote all variables.
- Flush with `dscacheutil -flushcache` and `killall -HUP mDNSResponder`.
- `HOSTS_FILE` env var overrides the path for tests. `sudo` resets the environment by default, so this can't be used through the `sudoers` rule.

**Install** (`install.sh`, run once with `sudo`):
1. Copy the script to `/usr/local/bin/timelock-hosts`; `chown root:wheel`; `chmod 755`.
2. Write `/etc/sudoers.d/timelock` (mode 0440): `<user> ALL=(root) NOPASSWD: /usr/local/bin/timelock-hosts`.
3. Validate the file with `visudo -cf` before installing it, so a typo can't lock out `sudo`.

The app checks for the script at launch (`status` via `sudo -n`) and, if it fails, shows a setup banner.

---

## 6. UI Design

### 6.1 Menu bar and popover

Menu bar item: idle → clock icon; running → `● Working 01:23:45` (FR-206).

```
┌───────────────────────────────┐
│ ● Working          01:23:45   │   running block (only when active)
│   Commitment: 26:15 left      │   (only if minimumEndAt set)
│   [ Stop ]                    │   disabled while commitment active
├───────────────────────────────┤
│ Today: 4h 12m                 │
├───────────────────────────────┤
│ ▶ Working                     │   each activity: color dot, name, ▶
│ ▶ Studying                    │
│ ▶ Writing                     │
├───────────────────────────────┤
│ Open Timelock…    Settings…   │
└───────────────────────────────┘
```

**Start flow:** clicking ▶ opens a small sheet: *Commitment (optional)* with presets `None · 25 · 50 · 90 min · Custom`, default `None` (Gentle, FR-802), then **Start**.

### 6.2 Main window (sidebar navigation)

| Section | Contents |
|---|---|
| **Activities** | List with color and total time; editor shows name/color, its own rules, attached groups |
| **Groups** | Shared lists (Distractions, …) with a "Global" toggle (FR-305, FR-306) |
| **History** | Sessions by day; edit times, delete, add manual entry (FR-701 to FR-703) |
| **Reports** | Swift Charts bar chart per activity, day/week/month toggle (FR-704) |
| **Settings** | Launch at login, default mode, notifications, setup status of `timelock-hosts` |

**Rule editor:** website field (accepts a URL or a domain and normalizes it), and an app picker listing installed apps from `/Applications` and `~/Applications`, storing the bundle ID.

---

## 7. Key Flows

**Start, with crash safety**
```
User taps ▶ → (optional Commitment) → TimerService.start
  → save Session → BlockingCoordinator.apply
      ├─ hosts script: block + flush DNS
      └─ AppBlocker: quit running matches, watch launches
  → menu bar shows timer
```

**Launch recovery** (FR-205, FR-406)
```
App launches → fetch Session where endedAt == nil
  ├─ found  → resume state, re-apply blocks (commitment timer resumes from minimumEndAt)
  └─ none   → run `timelock-hosts unblock` to clear stale entries
```

**Stop**
```
User taps Stop → canStop? ── no → show "N min left" (button disabled)
                        └─ yes → save endedAt → clear blocks → menu bar idle
```

**Mac sleeps mid-session:** nothing to do. The timestamp math is unaffected, and blocks stay in place. If a Commitment period ended while asleep, `canStop` is true on wake.

---

## 8. Error Handling

| Situation | Behavior |
|---|---|
| `timelock-hosts` missing or `sudoers` rule absent | Session still starts; warning banner with setup instructions |
| Domain fails validation in the editor | Rejected at entry time, with an inline message |
| Blocked app refuses to quit | `forceTerminate()` after the grace period; if it still fails, log it and show a notification |
| App crashes or is force-quit | Recovery on next launch. Blocks stay in place until then, which is the safe direction |
| Hosts file edited externally during a session | Not handled in the MVP (FR-605 is a Could) |

---

## 9. Testing Strategy (NFR-11)

| Area | Approach |
|---|---|
| Timer logic | Inject a `Clock` protocol; test start/stop, elapsed, `canStop`, recovery, switching activities |
| Effective rules | Unit tests: own + group + global merge, de-duplication |
| Domain normalization | Table tests: URLs, uppercase, `www.`, paths, invalid input |
| Blocking coordination | `FakeWebsiteBlocker` records calls; assert `block`/`unblock` order and arguments |
| Hosts script | Shell tests against a temp file via `HOSTS_FILE`: idempotent block, unblock restores original bytes, invalid domain leaves the file untouched |
| App blocking | Manual: open the blocked app during a session (hard to unit test) |
| MVP acceptance | Manual walkthrough of the 7 steps in 100_Requirements.md §5 |

---

## 10. Build Plan

| Milestone | Deliverable | Requirements |
|---|---|---|
| **M1: Timer core** | Xcode project, SwiftData models, `TimerService`, menu bar item with running stopwatch, start/stop, recovery on launch | FR-101, FR-102, FR-201 to FR-206, NFR-04, NFR-06 |
| **M2: App blocking** | Rule editor for apps, `AppBlocker`, notification on block | FR-302, FR-303, FR-501 to FR-504 |
| **M3: Website blocking** | `timelock-hosts` + `install.sh`, `HostsFileBlocker`, domain normalization, stale-entry cleanup | FR-301, FR-304, FR-401 to FR-406, NFR-07 to NFR-10 |
| **M4: History** | Day-grouped sessions list | FR-701 |
| **MVP complete** | Run the acceptance walkthrough | §5 of 100_Requirements.md |
| **M5: Groups and reports** | Shared/global groups, editing sessions, manual entries, Reports charts, today's total | FR-207, FR-305, FR-306, FR-702 to FR-704 |
| **M6: Commitment and settings** | Start sheet with duration, disabled Stop, launch at login, default mode | FR-601 to FR-604, FR-801 to FR-803 |

Milestones M1 to M3 give a usable app; M4 completes the MVP; M5 and M6 make up v0.2.

---

## 11. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| A live-updating menu bar title in `MenuBarExtra` can be unreliable with `TimelineView` | Drive the label from `TimerService.elapsed`, updated by a 1 s `Timer`; verify in M1 before building more UI |
| A bad `sudoers` file can break `sudo` | `install.sh` validates with `visudo -cf` before installing; keep a root shell open while installing the first time |
| macOS or browsers cache DNS, so blocks seem to lag | Flush after every change; document that an open tab may need a reload |
| Browsers using DNS-over-HTTPS bypass the hosts file | Accepted for the MVP; mention in Settings; a Network Extension could replace `HostsFileBlocker` later |
| Some apps relaunch themselves after being terminated | `AppBlocker` terminates on every launch notification, so they die again; watch for loops and rate-limit notifications |
| macOS updates changing `/etc/hosts` handling | Low risk; the script only touches its marker block, and `status` makes problems visible |
