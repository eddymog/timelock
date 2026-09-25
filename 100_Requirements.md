# 100 – Requirements: Timelock

Requirements for Timelock, a macOS app that combines Toggl-style time tracking with Freedom-style website and app blocking. See [README.md](README.md) for the overview and design.

**Priority key:** **Must** = needed for the MVP · **Should** = v0.2 · **Could** = later

---

## 1. Scope

**In scope:** a personal-use, native macOS app that tracks time per activity and blocks websites and apps while an activity runs.

**Out of scope:** pause/resume, overlapping activities, Mac App Store distribution or sharing the app with others, multi-user or team features, cloud sync, iOS/Windows/Linux versions, blocking on other devices.

---

## 2. Functional Requirements

### 2.1 Activities

| ID | Requirement | Priority |
|---|---|---|
| FR-101 | The user can create an activity with a name and a color. | Must |
| FR-102 | The user can rename, recolor, and archive an activity. | Must |
| FR-103 | The user can delete an activity; its past sessions are kept as archived history or deleted after confirmation. | Should |
| FR-104 | Activity names must be unique (case-insensitive). | Should |

### 2.2 Timer / Stopwatch

| ID | Requirement | Priority |
|---|---|---|
| FR-201 | The user can start an activity, which creates a session and starts a stopwatch counting up from 00:00:00. | Must |
| FR-202 | The user can stop the running activity, which saves the session's end time. | Must |
| FR-203 | Only one activity can run at a time. Starting another stops the current one first. | Must |
| FR-204 | Elapsed time is computed from the stored start timestamp, so it stays correct across sleep, app restarts and crashes. | Must |
| FR-205 | On launch, if a session has no end time, the app resumes it and re-applies its blocks. | Must |
| FR-206 | The main window shows the running activity and its elapsed time (e.g. `Working 01:23:45`). | Must |
| FR-207 | Today's total tracked time is shown in the main window. | Should |
| FR-208 | Optional auto-stop after N minutes of idle time. | Could |

### 2.3 Block rules

| ID | Requirement | Priority |
|---|---|---|
| FR-301 | The user can add website rules (domain) to an activity, e.g. `youtube.com`. | Must |
| FR-302 | The user can add app rules to an activity by picking an installed app; the rule is stored by bundle identifier. | Must |
| FR-303 | The user can edit and remove rules. | Must |
| FR-304 | Each website rule expands to `domain` and `www.domain` automatically. | Must |
| FR-305 | The user can mark a group as global so it applies whenever any activity runs. | Should |
| FR-306 | The user can create shared block groups (e.g. "Distractions") and attach them to several activities. Editing a group updates every activity that uses it. | Should |

### 2.4 Website blocking

| ID | Requirement | Priority |
|---|---|---|
| FR-401 | When an activity starts, its website rules (plus global rules) are written to `/etc/hosts`, mapped to `0.0.0.0` and `::`. | Must |
| FR-402 | Entries are wrapped in marker comments (`# >>> Timelock BEGIN` / `# <<< Timelock END`), and only that block is ever modified. | Must |
| FR-403 | When the activity stops, the Timelock block is removed from `/etc/hosts`. | Must |
| FR-404 | The DNS cache is flushed after every change. | Must |
| FR-405 | Root access goes through a single root-owned script (`timelock-hosts`) allowed by a scoped `sudoers` rule; the app never handles a password. | Must |
| FR-406 | On launch, if no session is running, stale Timelock entries are removed. | Must |
| FR-407 | Website blocking sits behind a `WebsiteBlocker` interface so another implementation can replace it later. | Should |

### 2.5 App blocking

| ID | Requirement | Priority |
|---|---|---|
| FR-501 | When an activity starts, blocked apps that are already running are quit (graceful `terminate()`, then `forceTerminate()` after a short grace period). | Must |
| FR-502 | While an activity runs, any blocked app that launches is terminated immediately. | Must |
| FR-503 | A notification tells the user which app was blocked and by which activity. | Should |
| FR-504 | App blocking stops when the activity stops. | Must |

### 2.6 Strictness modes

| ID | Requirement | Priority |
|---|---|---|
| FR-601 | **Gentle** mode (default): the Stop button always works and blocks lift immediately. | Must |
| FR-602 | **Commitment** mode: chosen per session. When starting an activity, the user can optionally set a minimum duration; Stop is disabled until it has elapsed. | Should |
| FR-603 | The remaining commitment time is shown while the session runs. | Should |
| FR-604 | Commitment persists across app restarts (the minimum end time is stored with the session). | Should |
| FR-605 | Optional: re-apply hosts entries if they are edited during a session. | Could |

### 2.7 History and reports

| ID | Requirement | Priority |
|---|---|---|
| FR-701 | The user can view sessions grouped by day, with activity, start, end and duration. | Must |
| FR-702 | The user can edit a session's start and end times, or delete it. | Should |
| FR-703 | The user can add a manual entry for a past period. | Should |
| FR-704 | Reports show time per activity by day, week and month (chart plus totals). | Should |
| FR-705 | Export sessions to CSV. | Could |

### 2.8 Settings

| ID | Requirement | Priority |
|---|---|---|
| FR-801 | Launch at login toggle. | Should |
| FR-802 | Choose the default strictness mode (Gentle unless changed). | Should |
| FR-803 | Toggle notifications. | Should |

---

## 3. Non-Functional Requirements

| ID | Requirement | Category |
|---|---|---|
| NFR-01 | Runs on macOS 14 (Sonoma) or later, on Apple Silicon and Intel. | Compatibility |
| NFR-02 | Built with Swift and SwiftUI, using only Apple frameworks (no third-party dependencies). | Technology |
| NFR-03 | Starting or stopping an activity applies or removes all blocks within 2 seconds. | Performance |
| NFR-04 | The stopwatch display updates every second with negligible CPU use (under 1% idle). | Performance |
| NFR-05 | All data is stored locally on the Mac; nothing is sent over the network. | Privacy |
| NFR-06 | Data survives crashes and force-quits: a session is written when it starts, not only when it stops. | Reliability |
| NFR-07 | The app must never leave the hosts file corrupted or with stale blocks after a normal stop, crash or reboot. | Reliability |
| NFR-08 | Edits to `/etc/hosts` change only the Timelock marker block; existing content is preserved. | Safety |
| NFR-09 | The `timelock-hosts` script is owned by root, not writable by the user, and accepts only validated domain names (no shell injection). | Security |
| NFR-10 | The app never stores or asks for the admin password. | Security |
| NFR-11 | Core logic (timer, rule expansion, hosts-file editing) has unit tests. | Quality |
| NFR-12 | The main UI is usable with keyboard navigation and VoiceOver labels, and supports light and dark mode. | Accessibility |

---

## 4. Constraints and Assumptions

- Personal use on the developer's own Mac only; the app will not be shared. No paid Apple Developer account required.
- The user has admin rights and can install the `sudoers` rule once.
- Website blocking through the hosts file can be bypassed by DNS-over-HTTPS and does not cover unlisted subdomains. This is accepted for the MVP.
- Commitment mode is a soft lock. Anyone with admin rights can still edit `/etc/hosts` or quit the app manually.

---

## 5. Acceptance Criteria (MVP)

1. Create an activity "Working" with `youtube.com` and Discord as rules.
2. Press play: the stopwatch starts, `youtube.com` fails to load in the browser, and Discord quits if it was open.
3. Open Discord while "Working" runs: it closes again and a notification appears.
4. Press stop: YouTube loads again, Discord can be opened, and a session is saved to history.
5. Force-quit the app mid-session and relaunch: the stopwatch resumes with the correct elapsed time and blocks are active.
6. Reboot mid-session and relaunch: the same result as step 5.
7. After a normal stop, `/etc/hosts` contains no Timelock block, and its original content is unchanged.

---

## 6. Decisions

| Question | Decision |
|---|---|
| Pause and resume? | No. Start and stop only. |
| Overlapping activities? | No. One running activity at a time (FR-203). |
| Default strictness mode? | Gentle (FR-601, FR-802). |
| Will the app be shared? | No. Personal use, so the sudoers approach (FR-405, NFR-09) stays. |
| Shared block lists? | Yes (FR-305, FR-306). |
| Commitment per session or per activity? | Per session (FR-602). |
