# Deferred Bugs

Bugs found *on the way* to a task — parked here so the task stays on the happy path.
This file is the single home for "noticed but not now." It is a triage queue, not a fix log.

## Protocol (agents follow this — no exceptions)

1. **Find a bug mid-task → append ONE line to the log below** (date, one-sentence symptom + `file:line`). That's it. Do **not** fix it, investigate it, or replan the task around it.
2. **Stay on the happy path.** Finish and report the task you were actually given.
3. **At the end of the task, list the deferred bugs you logged** (in your final report). Also surface one *earlier* if it becomes directly relevant to the current task — a one-line "note: this touches deferred bug X" is enough.
4. **Never fix a deferred bug unless explicitly asked.** The human triages this list during review — right after the task's data/deliverable lands. Fixing out of order is how a task gets lost.

A bug on the way is a **note**, not a detour. One line here beats a five-file tangent every time.

## Log

| id | date | status | bug |
|----|------|--------|-----|
| B1 | 2026-09-23 | fixed | KDE Store / `.plasmoid` install is silently broken — the bundle carries no native plugin, so `import org.termibar 1.0` (package/contents/ui/TerminalSession.qml:5) fails and the widget loads blank; README does not warn that `install.sh` is mandatory — the popup now detects the missing module (`Utils.hasTerminalPlugin`) and explains it instead of coming up blank; still needs install.sh to actually work |
| B2 | 2026-11-04 | fixed | Use-after-free crashes plasmashell when a session's process exits: `~Part` deletes the widget (and its `QWidgetWindow`) before `destroyed()` fires, so the raw `m_embeddedWindow` dangles in `detachWidget()` (plugin/konsoleitem.cpp:135) — SIGSEGV confirmed via gdb backtrace |
| B3 | 2026-11-04 | fixed | `install.sh` never restarts plasmashell: under `set -e`, `pkill -KILL -P "$PSPID"` exits 1 when no children match (the normal case after `kquitapp6`), aborting before `systemctl --user start` (install.sh:30-31) |
| B4 | 2026-11-04 | fixed | Deleting a terminal in config throws `ReferenceError: sessionsRepeater` — the id lives in the `fullRepresentation` component scope, invisible to root functions — aborting `reconcileSessions()` before `sessionsModel.remove()` (package/contents/ui/main.qml:103) |
| B5 | 2026-11-04 | fixed | "Add Terminal" stores the i18n placeholder as the real command, so the new tab runs `$SHELL -lc "e.g. /bin/bash, htop, spotify_player"` (package/contents/ui/ConfigTerminals.qml:157) |
| B6 | 2026-11-04 | fixed | Session identity is the terminal's name: renaming in config kills the running process, and command edits never reach the model (package/contents/ui/main.qml:97,130-132) |
| B7 | 2026-11-04 | fixed | "Add Terminal" names collide after a deletion (`"Terminal " + (list.length + 1)`), producing duplicate names that confuse name-keyed reconcile (package/contents/ui/ConfigTerminals.qml:156) |
| B8 | 2026-11-04 | fixed | `embedWidget()` shows the part widget regardless of the QML item's visibility, so a non-active tab's subsurface overlaps the active terminal when 2+ sessions autostart (plugin/konsoleitem.cpp:165) |
| B9 | 2026-11-04 | fixed | `exited(0)` is hardcoded, so exitCode is always 0 and the "exited with code %1" / "terminated" branches are unreachable (plugin/konsoleitem.cpp:113, package/contents/ui/TerminalSession.qml:124-129) |
| B10 | 2026-11-04 | fixed | Font family/size and Rows/Columns settings never reach the terminal — `KonsoleItem` has no font API and `TerminalInterface` only exposes `setCurrentProfile()`; rows/cols merely scale the popup (package/contents/ui/ConfigGeneral.qml:59-82, main.qml:252-253) — font settings removed, rows/cols relabelled as popup size |
| B11 | 2026-11-04 | fixed | `~KonsoleItem` does not disconnect the `destroyed` lambda the way `shutdown()` does, so `exited()` can fire during item teardown (plugin/konsoleitem.cpp:45-49) |
| B12 | 2026-11-04 | fixed | Autostart checkbox's `onCheckedChanged` fires while the delegate is built, writing config on config-page open (package/contents/ui/ConfigTerminals.qml:118) |
| B13 | 2026-11-04 | fixed | `workingDirectory` is read by `buildConfigs()` but has no config UI, so it is always empty (package/contents/ui/main.qml:55) — field added, and `start()` now cds into it for custom commands too |
| B14 | 2026-11-04 | documented | Autostart forces `expanded = true`, popping the panel popup open at login — unavoidable today since the KPart cannot embed without a popup window (package/contents/ui/main.qml:165-166) |
| B15 | 2026-11-04 | fixed | Clearing a terminal's command field silently deletes that terminal on reload — `parseTerminalList` drops entries whose command is empty (package/contents/ui/utils.js:9); found while fixing B5 — empty now means "just a shell" |
| B16 | 2026-11-04 | fixed | Any command outside the system PATH dies instantly with "command not found": `start()` ran `$SHELL -lc`, which never reads the interactive rc (`.zshrc`/`.bashrc`) where user PATH additions like `~/.local/bin` live (plugin/konsoleitem.cpp:111) — reported as "yt-music instantly crashes on autostart", fixed by `-lic` |
| B17 | 2026-11-04 | fixed | Autostarted sessions launched a bare shell instead of their command: the delegate arrives with `sessionState` already Running, so the initial binding evaluation fired `onCurrentStateChanged` mid-creation and called `start()` before `KonsoleItem.command` was bound — empty command took the `showShellInDir` branch, and idempotent `start()` made the later correct call a no-op (package/contents/ui/TerminalSession.qml:31) |
| B18 | 2026-11-04 | fixed | `killall plasmashell` / SIGTERM / logout was ignored while a session ran: Plasma only hides the popup window, so the part widget stayed a visible top-level QWidget with a reparented QWindow, and QApplication refuses to quit in that state. Typing `exit` ended the session and released it. Fixed by hiding the part widget on popup hide (plugin/konsoleitem.cpp:262). Residual: still refused if the popup is open at quit time |
| B19 | 2026-11-05 | fixed | Columns/Rows settings had no effect on the popup (and so none on the terminal): `AppletPopup::hideEvent()` saves popupWidth/popupHeight on every hide and `updateSize()` then returns early forever, so `Layout.preferredWidth/Height` only ever applied to the first open of a fresh widget. Fixed by pushing the configured size onto the popup window on every show (package/contents/ui/main.qml:306). Consequence: a dragged popup size is no longer remembered |
| B20 | 2026-11-05 | open | Every `PlasmaComponents.TabButton` instance logs `TypeError: Cannot read property 'visualFocus' of null` + `Unable to assign [undefined] to QQuickItem*` (TabButton.qml:67,79) — our custom `contentItem: RowLayout` displaces the one TabButton's internals expect. Fires per tab delegate even when the header is hidden; tabs still work (package/contents/ui/main.qml:361) |
