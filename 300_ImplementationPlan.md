# 300 – Implementation Plan: Timelock

Step-by-step build plan. Each task is small enough to finish and verify on its own. It follows the milestones in [200_DesignPlan.md](200_DesignPlan.md) §10 and the requirements in [100_Requirements.md](100_Requirements.md).

**Rules of thumb**
- Finish and verify a task before starting the next.
- Write the test first for pure logic (timer, rules, domains, hosts editing).
- Commit at the end of each task (this folder isn't a git repo yet; see task 0.2).
- "Verify" lines say how to confirm the task is done.

---

## Phase 0 – Setup

| # | Task | Verify |
|---|---|---|
| 0.1 | Confirm Xcode 15+ is installed (`xcodebuild -version`) and macOS is 14+. | Version printed |
| 0.2 | Run `git init` in the project folder; add a `.gitignore` for Xcode (`xcuserdata/`, `DerivedData/`, `.DS_Store`). | `git status` works |
| 0.3 | In Xcode: **New Project → macOS → App**, SwiftUI, name `Timelock`, storage **SwiftData**, include Tests. Save it inside this folder. | App runs and shows the default window |
| 0.4 | Set deployment target to **macOS 14.0**. Under Signing & Capabilities: turn **App Sandbox off**, keep Hardened Runtime on, sign with "Sign to Run Locally". | Builds and runs |
| 0.5 | Delete the default `WindowGroup` content and the sample `Item` model (leave a placeholder scene so the app compiles). Keep the Dock icon: `LSUIElement` is **not** set. | App builds and launches |
| 0.6 | Create the folder groups from the design plan (Models, Services, Views, Support). | Groups exist in Xcode |
| 0.7 | Create `Scripts/` at the repo root (outside the Xcode target). | Folder exists |

---

## Phase 1 – M1: Timer Core

Goal: a main window with a running stopwatch that survives restarts.

| # | Task | Verify |
|---|---|---|
| 1.1 | **Models.** Create `Activity`, `BlockGroup`, `BlockRule`, `Session` as SwiftData `@Model` classes per design plan §3 (rules and groups can be stubs for now, but include the relationships). Register them in the app's `ModelContainer`. | App launches; no schema errors |
| 1.2 | **Clock protocol.** `protocol Clock { var now: Date { get } }` with `SystemClock` and a test `FakeClock`. | Compiles |
| 1.3 | **TimerService (test first).** Write tests for: `start` creates a session with `endedAt == nil`; `elapsed` = `now - startedAt`; `stop` sets `endedAt`; starting a second activity stops the first; `stop` with Gentle always succeeds. Then implement `TimerService` (`@Observable`, main actor) with `start`, `stop`, `elapsed`, `canStop`, state `.idle / .running`. | `⌘U`: tests pass |
| 1.4 | **Recovery.** Test then implement `recoverOnLaunch()`: fetch the session with `endedAt == nil` and resume it. Call it at app start. | Test passes; manual: force-quit mid-session, relaunch, time continues |
| 1.5 | **Tick.** Add a 1 s `Timer` in `TimerService` that updates a published `elapsed` while running (display only). | Value changes each second |
| 1.6 | **DurationFormatter.** Add `DurationFormatter` in Support (with tests: 0s, 59s, 1h 1m 1s, over 24h). | Tests pass |
| 1.7 | **Main window.** In `TimelockApp`, a `Window` scene showing the running block at the top (name, large `HH:MM:SS`, Stop) and the activity list with a ▶ button. Closing the window must not quit the app. | Start/stop works end to end; stopwatch counts live |
| 1.8 | **Activity editor (minimal).** Sheet or window to add, rename, recolor and archive activities (FR-101, FR-102). Seed "Working" on first launch. | Can create an activity and run it |

**Checkpoint:** run the timer, quit the app, relaunch, and confirm the time is right. If the stopwatch doesn't update live, fix it now (design plan §11, first risk).

---

## Phase 2 – M2: App Blocking

| # | Task | Verify |
|---|---|---|
| 2.1 | **Rules for apps.** In the activity editor, add an "Apps" section: a button opens an `NSOpenPanel` filtered to `.app`, reads `Bundle(url:)?.bundleIdentifier` and the display name, and saves a `BlockRule(kind: .app)` (FR-302, FR-303). | Discord appears in the list with `com.hnc.Discord` |
| 2.2 | **Effective rules (test first).** A pure function `effectiveRules(for: Activity, globalGroups:) -> [BlockRule]` that merges own, group and global rules and removes duplicates by `(kind, value)`. Table tests. | Tests pass |
| 2.3 | **AppBlocker.** Implement `start(bundleIDs:)` and `stop()`: terminate running matches (`terminate()`, then `forceTerminate()` after 3 s if still running) and observe `didLaunchApplicationNotification`. Guard against terminating Timelock itself. | Manual: open Discord during a session, it closes |
| 2.4 | **NotificationService.** Request permission on first use; post "Discord is blocked while Working is running" (FR-503). | Notification appears |
| 2.5 | **BlockingCoordinator (part 1).** Wire `TimerService.start/stop` and recovery to call `apply` and `clear`; for now it drives only `AppBlocker`. Test the coordinator with a fake blocker. | Blocks re-apply after a relaunch mid-session |

---

## Phase 3 – M3: Website Blocking

### 3A – The root script

| # | Task | Verify |
|---|---|---|
| 3.1 | **Domain normalization (test first).** `DomainNormalizer.normalize(_:) -> String?` in Swift: accepts `https://www.YouTube.com/watch?v=1`, `youtube.com`, `sub.example.co.uk`; returns lowercase host without scheme, path, port; returns `nil` for garbage. Rule expansion adds `www.` when missing (FR-304). | Table tests pass |
| 3.2 | **`Scripts/timelock-hosts`.** Implement `block`, `unblock`, `status` per design plan §5: strict domain regex, temp file plus atomic replace, marker block only, DNS flush, `HOSTS_FILE` env override. | See 3.3 |
| 3.3 | **Script tests.** A shell test that copies a sample hosts file to a temp path and checks: `block` adds the block; running `block` twice leaves one block; `unblock` restores the original bytes exactly; an invalid domain (`"a b"`, `"x;rm"`, `""`) exits non-zero and leaves the file untouched. | All checks pass against the temp file |
| 3.4 | **`Scripts/install.sh`.** Copy to `/usr/local/bin/timelock-hosts` (`root:wheel`, `755`); write `/etc/sudoers.d/timelock` (`0440`) for the invoking user (use `$SUDO_USER`); validate with `visudo -cf` **before** moving it into place. | `sudo -n /usr/local/bin/timelock-hosts status` works without a password |
| 3.5 | **First real run (careful).** Back up `/etc/hosts` first (`cp /etc/hosts ~/hosts.backup`). Run `sudo -n timelock-hosts block youtube.com www.youtube.com`, check the browser fails to load YouTube, then `unblock`. | YouTube blocked then restored; `diff` against backup is empty |

### 3B – App integration

| # | Task | Verify |
|---|---|---|
| 3.6 | **`WebsiteBlocker` protocol + `FakeWebsiteBlocker`** (records calls, can throw). | Compiles |
| 3.7 | **`HostsFileBlocker`.** Run `/usr/bin/sudo -n /usr/local/bin/timelock-hosts …` with `Process`; capture the exit code and stderr; throw a typed error on failure. Pass domains as separate arguments, never through a shell string. | Manual block/unblock from the app |
| 3.8 | **Website rules UI.** "Websites" section in the activity editor: text field that runs `DomainNormalizer` and shows inline errors (FR-301, FR-303). | Adding `https://www.youtube.com/x` stores `youtube.com` |
| 3.9 | **BlockingCoordinator (part 2).** Add website blocking; on failure, keep the session running and surface a warning in the main window (design plan §4.2). Coordinator tests with `FakeWebsiteBlocker`, including the failure path. | Tests pass |
| 3.10 | **Stale cleanup.** On launch, if no session is running, call `unblock` (FR-406). | Manually add a fake block, relaunch: removed |
| 3.11 | **Setup check.** At launch, run `sudo -n timelock-hosts status`; if it fails, show a "Website blocking isn't set up, run install.sh" banner in the main window and Settings. | Banner appears when the sudoers file is removed |

**Checkpoint:** run the real scenario: "Working" with `youtube.com` and Discord. YouTube fails, Discord closes, stop restores both.

---

## Phase 4 – M4: History (completes the MVP)

| # | Task | Verify |
|---|---|---|
| 4.1 | **Sidebar.** Wrap the existing main window in a `NavigationSplitView` sidebar: Timer (current home view), Activities, History (others added later). Reopen the window from the Dock icon after closing it. | Sidebar switches sections; Dock click reopens the window |
| 4.2 | **History view.** Query sessions sorted by start descending; group by calendar day with a day total; each row shows activity color, name, start–end, duration. Running session shows "running". | Sessions listed correctly |
| 4.3 | **Acceptance walkthrough.** Run all 7 steps in 100_Requirements.md §5, including force-quit and reboot recovery, and compare `/etc/hosts` with the backup afterwards. | All 7 pass |

**MVP complete.** Commit and tag `v0.1`.

---

## Phase 5 – M5: Groups and Reports (v0.2)

| # | Task | Verify |
|---|---|---|
| 5.1 | **Groups UI.** Groups section in the sidebar: create a group, add website and app rules, toggle "Global" (FR-305, FR-306). | Group is created |
| 5.2 | **Attach groups to activities.** Multi-select in the activity editor. Editing a group changes every activity using it. Verify the effective rules test covers this. | Two activities share one group |
| 5.3 | **Edit and delete sessions.** Edit start/end (validate `end > start`, no overlap with the running session), delete with confirmation (FR-702). | Edits persist |
| 5.4 | **Manual entries.** "Add entry" sheet for a past period (FR-703). | Entry appears in History |
| 5.5 | **Today's total** in the main window (FR-207); includes the running session. | Number matches History |
| 5.6 | **Reports.** Swift Charts bar chart: time per activity, day/week/month picker (FR-704). Aggregation is a pure function with tests (sessions crossing midnight, running session, empty range). | Chart matches History totals |

---

## Phase 6 – M6: Commitment and Settings (v0.2)

| # | Task | Verify |
|---|---|---|
| 6.1 | **Commitment logic (test first).** `start(activity, minimumDuration:)` sets `minimumEndAt`; `canStop` false before it and true after; `stop` throws `commitmentActive(remaining)`; starting another activity during Commitment is refused; recovery restores `minimumEndAt` (FR-602, FR-604). | Tests pass |
| 6.2 | **Start sheet.** Presets `None · 25 · 50 · 90 · Custom`, default None (Gentle) (FR-601). | Sheet appears on ▶ |
| 6.3 | **Timer view behavior.** Stop disabled during Commitment; show the remaining time, updating each second (FR-603). | Countdown visible; Stop enabled at 0 |
| 6.4 | **Settings.** Launch at login (`SMAppService.mainApp.register()/unregister()`), default mode, notifications toggle, and hosts-script setup status (FR-801 to FR-803). | Toggles persist |
| 6.5 | **Final pass.** VoiceOver labels, keyboard navigation, light and dark mode (NFR-12); re-run the acceptance walkthrough, plus a Commitment scenario. | Checklist passes |

**v0.2 complete.** Commit and tag `v0.2`.

---

## Testing Checklist (run before each tag)

- [ ] `⌘U` passes (timer, rules, domains, formatter, coordinator, aggregation)
- [ ] Shell tests for `timelock-hosts` pass
- [ ] Force-quit mid-session then relaunch: time and blocks correct
- [ ] Reboot mid-session: same
- [ ] After a normal stop, `diff /etc/hosts ~/hosts.backup` is empty
- [ ] Mac sleeps mid-session: elapsed time is correct on wake
- [ ] With the sudoers rule removed: app warns and doesn't hang
- [ ] Blocked app relaunching repeatedly doesn't spam notifications

---

## Order of Work at a Glance

```
Phase 0  Setup
Phase 1  Timer core         ← usable stopwatch
Phase 2  App blocking       ← Discord blocked
Phase 3  Website blocking   ← YouTube blocked
Phase 4  History            ← MVP (v0.1)
Phase 5  Groups + Reports   ┐
Phase 6  Commitment+Settings┘ v0.2
```

## Watch Out For

- **Don't test the script against the real `/etc/hosts` until 3.3 passes.** Use `HOSTS_FILE` on a temp copy first, and keep the backup from 3.5.
- **Keep a root shell open** the first time you run `install.sh`, in case the `sudoers` file has a problem.
- **Never build shell commands as strings.** Always pass arguments as an array to `Process`.
- **Sign locally, don't sandbox.** Turning the sandbox back on breaks both `sudo` and quitting other apps.
