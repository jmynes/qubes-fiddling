#!/usr/bin/env bash
# Deploy the Qubes Win10 4-vCPU redraw fix into a Windows qube, over qrexec.
#
# Root cause (see memory win10-mcp-4vcpu-redraw-fix): at >2 vCPUs Win10's DWM /
# Basic Display Adapter races and leaves stale pixels in GUEST VRAM that the
# emulated GUI faithfully shows. Proven (instrumented stubdom) NOT to be a
# qemu/Xen/stubdom bug. Fix is guest-side: force RedrawWindow on the events that
# create fragments. This installs redraw-hook.exe + a logon scheduled task.
#
# Run from mgmtvm (or dom0):  deploy-redraw-fix.sh <qube> [path-to-redraw-hook.cs]
set -euo pipefail

QUBE="${1:?usage: deploy-redraw-fix.sh <qube> [cs-path]}"
CS="${2:-$(dirname "$(readlink -f "$0")")/redraw-hook.cs}"
[ -f "$CS" ] || { echo "C# source not found: $CS" >&2; exit 1; }

b64() { printf '%s' "$1" | iconv -t UTF-16LE | base64 -w0; }
run() { qvm-run --pass-io --no-gui "$QUBE" "powershell -NoProfile -EncodedCommand $(b64 "$1")" | tr -d '\r'; }

# 1. ensure target dir, then stream the C# source in via stdin (no cmdline limit)
run 'New-Item -ItemType Directory -Force "C:\ProgramData\qubes-redraw" | Out-Null; Write-Output "DIR-OK"' | grep -q DIR-OK
writer='[IO.File]::WriteAllText("C:\ProgramData\qubes-redraw\redraw-hook.cs",[Console]::In.ReadToEnd());Write-Output "CS-OK"'
cat "$CS" | qvm-run --pass-io --no-gui "$QUBE" \
  "powershell -NoProfile -EncodedCommand $(b64 "$writer")" | tr -d '\r' | grep -q CS-OK

# 2. set outline dragging, compile, (re)register + start the logon task
read -r -d '' BUILD <<'PS' || true
$dir='C:\ProgramData\qubes-redraw'; $task='QubesRedrawFix'
# outline dragging (kills the live-drag repaint storm), applied live + persisted
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Spi { [DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint a,uint b,IntPtr c,uint d); }
"@
[Spi]::SystemParametersInfo(0x0025,0,[IntPtr]::Zero,3) | Out-Null   # SPI_SETDRAGFULLWINDOWS off
Set-ItemProperty 'HKCU:\Control Panel\Desktop' DragFullWindows 0 -ErrorAction SilentlyContinue
# stop any previous instance, recompile
schtasks /End /TN $task 2>$null | Out-Null
Get-Process redraw-hook -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path $csc)){$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'}
& $csc /nologo /target:winexe /out:"$dir\redraw-hook.exe" "$dir\redraw-hook.cs" | Out-Null
if(-not(Test-Path "$dir\redraw-hook.exe")){ Write-Output 'BUILD-FAIL'; exit 1 }
# logon task, runs in the interactive session
schtasks /Create /TN $task /TR "$dir\redraw-hook.exe" /SC ONLOGON /RL LIMITED /F | Out-Null
schtasks /Run /TN $task | Out-Null
Start-Sleep -Seconds 2
$r=Get-Process redraw-hook -ErrorAction SilentlyContinue
Write-Output ('INSTALL-OK running='+[bool]$r)
PS
out=$(run "$BUILD")
echo "$out" | grep -q INSTALL-OK || { echo "deploy to $QUBE failed: $out" >&2; exit 1; }
echo "$QUBE: $(echo "$out" | grep INSTALL-OK)"
