# Airgapped Windows 10 qube via Ansible (mgmtvm)

`playbooks/windows10-airgapped.yml` produces a secure, network-less Windows 10
qube from **mgmtvm** using the Qubes Admin API + `qubes-ansible`, instead of
running `qvm-create-windows-qube` in dom0 (as `windows.sh` does). It is a
faithful port of that tool's flow:

| qvm-create-windows-qube (dom0)             | this playbook (mgmtvm)                                  |
| ------------------------------------------ | ------------------------------------------------------- |
| `install.sh` builds `windows-mgmt`         | role `windows-mgmt-setup` builds it via `qubesos.core.qube` |
| streams QWT ISO from dom0                   | downloads + signature-verifies the QWT rpm in mgmtvm, or reuses a pre-staged ISO |
| `create-media.sh` injects the answer file  | same, run over `qvm-run` in `windows-mgmt`              |
| 3–4 `qvm-start --cdrom VM:/path` boot passes | same, but `qvm-start --cdrom VM:loopN` (loop-device form; the path form is dom0-only) |
| temp dom0 `qubes.Filecopy` policy + `qvm-copy-to-vm` | post scripts streamed over `qubes.VMShell` (base64) — **no dom0 policy change** |
| airgap via `qvm-firewall` drop/accept dance | `netvm ""` from creation, never flipped (see "Why no firewall dance") |

## Roles

- **`windows-mgmt-setup`** — ensures the airgapped `windows-mgmt` resources
  qube, installs `genisoimage`/`datefudge` via its template, streams in the
  local `qvm-create-windows-qube` checkout + the Windows ISO + QWT, and bakes
  the unattended installation media (answer file injected as `Autounattend.xml`).
- **`windows-qube`** — creates the Windows HVM with hardened airgapped prefs,
  drives the unattended install boot passes, installs QWT, runs optional
  telemetry/optimize post scripts, marks the qube provisioned, and shuts it down.

## Prerequisites (one-time, in dom0 — mgmtvm cannot do these)

1. Install/refresh the Admin API policy so mgmtvm may create and manage qubes:
   ```
   sudo cp ~/qubes-fiddling/ansible/policies/30-ansible.policy /etc/qubes/policy.d/
   sudo cp ~/qubes-fiddling/ansible/policies/include/admin-local-rwx /etc/qubes/policy.d/include/
   sudo cp ~/qubes-fiddling/ansible/policies/include/admin-global-ro /etc/qubes/policy.d/include/
   ```
   (`ansible.sh` lines 11–13 do this but with broken paths — copy the three
   files individually as above. The new `windows-mgmt` qube is auto-tagged
   `created-by-mgmtvm` at creation, so it needs no manual `qvm-tags`.)
2. **Windows ISO** — by default the role **auto-downloads** the official
   **Win10 22H2 x64** ISO (`win_iso_download_method: mirror`) from a stable
   mirror and verifies it against the pinned `win_iso_sha256` (`a6f470ca…`, the
   same hash Mido's table uses), so integrity is guaranteed regardless of source.
   Alternatives: `win_iso_download_method: connector` pulls the *current* ISO
   straight from Microsoft's `software-download-connector` API (direct from MS,
   but its anti-bot ("Sentinel") rejects VPN/datacenter IPs — only residential
   IPs pass), or `manual` to stage your own at `win_iso_src` and pin its hash.
   `mido.sh` is intentionally not used (its Microsoft endpoints 404).

## Run

```
cd ~/qubes-fiddling/ansible
ansible-playbook -i inventory.ini playbooks/windows10-airgapped.yml
```

The Windows installation itself takes a long time (multiple unattended reboots,
possibly chkdsk). Timeouts are generous and tunable via `win_install_timeout_secs`.

## After the run — hardening (one-time, in dom0)

The role tags every qube it makes `airgapped-windows`. A netvm-less qube is
**not** a true airgap (shared Xen/dom0, XSAs, human clipboard/file error), so
install the deny policy that closes the remaining data paths for that tag:
```
sudo cp ~/qubes-fiddling/ansible/policies/40-windows-airgapped.policy /etc/qubes/policy.d/
```
This denies clipboard paste, file copy, and open-in-VM/URL in both directions
for the tag. App-menu sync has no Admin API equivalent; if you want the
Start-menu entries, run `qvm-appmenus --update --force <qube>` in dom0.

## Key knobs (override in the playbook `vars:`)

| var | default | meaning |
| --- | --- | --- |
| `win_qube_name` | `win10-airgapped` | the qube to produce |
| `win_qube_klass` | `StandaloneVM` | or `TemplateVM` to base AppVMs on it |
| `win_memory_mb` / `win_vcpus` | `12288` / `2` | resources (maxmem is forced to 0 — balancing off) |
| `win_root_size_gib` / `win_private_size_gib` | `60` / `20` | volume sizes |
| `win_max_resolution` | `2048x1152` | sizes GUI video RAM, enables fullscreen, and sets the QWT default resolution (see Display below) |
| `win_run_optimize` / `win_run_spyless` / `win_run_seamless` | `false`/`true`/`false` | post scripts (optimize off by default — it disables Defender + host firewall) |
| `win_iso_download_method` | `mirror` | `mirror` (hash-pinned 22H2) / `connector` (live MS, residential IP only) / `manual` |
| `win_iso_url` / `win_iso_sha256` | 22H2 archive.org / `a6f470ca…` | mirror source + pinned hash (integrity anchor) |
| `qwt_iso_src` | `""` | pre-staged QWT ISO; empty ⇒ download+verify the dom0 rpm |
| `win_force_reinstall` | `false` | **destructive** — re-runs install passes (wipes disk) |

## Design notes

### Why no firewall dance
Upstream attaches a netvm with a `qvm-firewall drop` rule during QWT install,
then flips to `accept`. On Qubes 4.3 both halves are broken: the leftover drop
rule blocks all post-install traffic (issue #99, needs `qvm-firewall <vm> reset`),
and changing netvm on a *running* Windows HVM has no effect until reboot
(issues #10459/#10574). For a permanently offline qube the correct airgap is one
that simply never has a NIC: `netvm ""` is set at creation and never touched.
The role asserts `netvm` is empty and `maxmem` is 0 at the end.

### CD-ROM boot from mgmtvm
`qvm-start --cdrom VM:/path/file.iso` is rejected outside dom0. The role instead
`losetup`s the ISO inside `windows-mgmt` and boots with the port-id form
`qvm-start --cdrom windows-mgmt:loopN`, which qubesadmin accepts from mgmtvm
(assign → start → auto-unassign). Each loop device is detached after its pass.

### Install-completion detection
Each pass ends either in a guest reboot (Qubes reports a shutdown) or, with the
new QWT 4.2.2 (which does not reboot after install), in qubesd setting the
feature `os=Windows`. The wait loops poll `qvm-check --running` and that feature,
with hard timeouts. A `provision-complete` feature marks the qube done so a
re-run never re-enters the destructive install passes.

### Display resolution (`win_max_resolution`, default `2048x1152`)
Two safe, parameterized steps — the playbook **never** does a live resolution
switch, because changing modes repeatedly or too quickly locks up the QWT driver
until reboot:
1. **Qubes side:** `gui-videoram-min = width*height*4/1024` KiB (2048×1152 → 9216)
   sizes the GUI framebuffer so the mode is selectable without running out of
   video RAM; `gui-videoram-overhead 0` and `gui-allow-fullscreen 1` are also set.
   These are dom0 features applied to the tagged qube via the Admin API.
2. **Windows side:** post-setup writes QWT's `FullscreenWidth`/`FullscreenHeight`
   DWORDs under `HKLM\SOFTWARE\Invisible Things Lab\Qubes Tools` (a `reg add`, not
   a live mode change). QWT reads these on boot, so the qube comes up at the set
   size and it persists across reboots.

The QWT video driver must actually offer the mode; 2048×1152 is a preset in this
build's driver. If a QWT build lacks the requested mode, Windows snaps to the
nearest supported one. Set `win_max_resolution: ""` to leave Qubes/QWT defaults.

## Validated end-to-end (2026-06-12)
Run to completion from mgmtvm against a real Win10 ISO: `windows-mgmt` built,
QWT downloaded/verified/installed, `win10-airgapped` created and installed via
the loop-device CD-ROM boots, `spyless.bat` delivered+run, `provision-complete`
set, clean shutdown — final `netvm=''`, `maxmem=0`, `os=Windows`. Gotchas found
and handled along the way (useful if you adapt this):

- **A "Windows ISO" may already be prepared media.** If `isoinfo` shows
  `Autounattend.xml`/`boot.bin` at the ISO root, `create-media.sh` collides on
  the Joliet name. The role detects this and uses the ISO directly (hardlink),
  asserting the embedded answer file has the `D:\run.bat` QWT hook.
- **`qvm-run` into a Windows qube returns the cmd.exe banner + echoed command**
  around real output. Parse with `regex_search('[a-fA-F0-9]{64}')`, never
  `stdout | trim`.
- **`cmd /c cd C:\x && y.bat`** lets `&&` bind to the outer VMShell cmd (runs
  `y.bat` from system32). Invoke post scripts by full path: `cmd /c C:\post\y.bat`.
- **`include_tasks` is not covered by `--syntax-check`** (dynamic include). Lint
  the role or YAML-parse the included files separately.

Post scripts are best-effort (`failed_when: false`) with a sha256 delivery
check; a hiccup won't fail provisioning and they can be re-applied by hand.
