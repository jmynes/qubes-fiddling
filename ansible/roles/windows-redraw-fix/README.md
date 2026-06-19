# windows-redraw-fix

Clears the desktop redraw artifacts (stranded window edges, drag/marquee trails,
leftover fragments) that a **Windows 10 HVM shows at >2 vCPUs** in Qubes OS.

## Why this exists

At 4+ vCPUs the Win10 desktop leaves stale pixels behind; at 2 vCPUs it's clean,
and Win7 is unaffected. Root-caused (June 2026) by building an **instrumented
Qubes stubdom qemu** that forced a full re-read of guest VRAM every 200 ms — the
fragments persisted, proving the stale pixels live in **guest VRAM**. So it is
**not** a qemu / Xen / stubdom / dirty-tracking bug (all ruled out); it's the
Windows side: DWM + the Microsoft Basic Display Adapter race under SMP and never
repaint the vacated regions. Win7 escapes it because it can run without DWM
compositing. No hypervisor patch can fix it — the fix has to be guest-side.

## What it installs

`redraw-hook.exe` (compiled in-guest from `files/redraw-hook.cs` with the inbox
.NET Framework `csc`), run by a logon scheduled task **QubesRedrawFix**. It:

- hooks window **close / minimize / move-resize-end** (`SetWinEventHook`) and
  forces one `RedrawWindow` per event — clears window & Start-menu fragments;
- throttled catch-all on `LOCATIONCHANGE` (~5 Hz) for programmatic window moves;
- a **desktop-scoped** low-level mouse hook: a left-drag that *starts on the
  desktop* (cursor's root window is `Progman`/`WorkerW`) fires a single repaint
  **on mouse-up** — clears marquee-select / icon-drag trails. It hit-tests on
  button-down and **never arms for app windows**, so in-app
  dragging/scrolling/pane-resizing is untouched (an earlier *un*scoped version
  fired on every drag and tanked app performance — see history below).
  Repainting *during* the desktop drag was tried (A/B-tested) but its `RDW_ERASE`
  wiped the live marquee rectangle each frame, delaying it ~1s before it became
  visible; clear-on-release won.

The deploy script also switches dragging to **outline mode**
(`DragFullWindows=0`) so live window drags don't smear, and applies a **custom
visual-effects** profile: window/menu/taskbar **animations and fades off** (under
SMP they smear and make the Start menu feel sluggish) while **keeping** the
translucent selection rectangle, icon-label shadows, and Aero Peek. This needs
an Explorer restart, so the deploy briefly bounces Explorer.

Idle cost is ~0 — it fires **only on discrete window-level events**, never during
in-app dragging/scrolling/pane-resizing, so it doesn't touch app performance.
`RedrawWindow` uses `RDW_UPDATENOW` so the repaint is synchronous — that flag is
load-bearing; orphaned fragments have no active painter, so a merely queued
invalidation never clears them.

## History / notes

- An earlier global (unscoped) low-level mouse hook fired on *every* drag,
  including in-app dragging/scrolling/pane-resizing — forcing 25 Hz full-screen
  repaints that badly degraded performance and made app panes jump. Replaced by
  the desktop-scoped version above, which hit-tests the drag origin and only
  arms on `Progman`/`WorkerW`.
- If in-app pane dragging still feels off, the next suspect is the
  `DragFullWindows=0` (outline drag) step in the deploy script — toggle it back.

## Usage

```yaml
- hosts: localhost            # runs on mgmtvm; talks to the qube over qrexec
  connection: local
  roles:
    - role: windows-redraw-fix
      vars:
        redraw_target_qube: romhacking-hma-mcp
```

The target qube must be **running** with QWT/qrexec up. Re-running is idempotent
(recompiles the exe, recreates the task).

### Manual / standalone deploy

```bash
ansible/roles/windows-redraw-fix/files/deploy-redraw-fix.sh <qube>
```

## Tuning

- **Flush rate during desktop drags** — the `SetTimer(..., 40, ...)` interval
  (ms) in `files/redraw-hook.cs`. Higher = lighter, slightly less smooth.
- **Live window contents while dragging** — remove the `DragFullWindows=0` step
  in `files/deploy-redraw-fix.sh` (then window drags smear until release).

## Remove

```
schtasks /Delete /TN QubesRedrawFix /F     # in the guest
# then kill redraw-hook.exe; optionally restore DragFullWindows=1
```
