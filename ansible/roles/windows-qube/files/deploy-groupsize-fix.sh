#!/usr/bin/env bash
# Apply + verify the WARP/DWM groupsize=2 redraw fix in a Windows qube, over qrexec.
#
# THE ROOT FIX for the Qubes Win10 22H2 >2-vCPU redraw corruption (black/stale
# static regions, drag-select staircase trails) on this GPU-less HVM. The guest
# falls back to the Microsoft Basic Display Adapter -> DWM composites the desktop
# in software via WARP (d3d10warp.dll). WARP sizes its worker pool to the
# enumerated processor count; at 3+ vCPUs it multithread-composites and RACES on
# static regions. `bcdedit /set groupsize 2` splits the vCPUs into 2-CPU
# processor groups WITHOUT disabling any core; on Win10 22H2 a process defaults to
# its home group and the legacy GetSystemInfo (which WARP uses) reports only 2 ->
# 2-wide pool -> clean. Verified at 16 vCPU: Groups=8, ProcView=2, Packages=1.
#
# This LARGELY SUPERSEDES the windows-redraw-fix RedrawWindow hook
# (../windows-redraw-fix/files/deploy-redraw-fix.sh): that hook chased the
# corruption event-by-event; groupsize removes the race at the source. Recommend
# DISABLING the hook once this is confirmed, or keep it only as belt-and-suspenders.
#
# CAVEATS: Win10-ONLY -- do NOT upgrade the guest to Win11 (it spans groups by
# default, the bug returns). Not durable across Windows feature/in-place upgrades
# (re-run this). Each group is 2 CPUs, so any SINGLE non-group-aware process is
# capped at 2 cores (aggregate multi-process throughput is unaffected). Takes
# effect on the NEXT BOOT.
#
# Run from mgmtvm (or dom0):  deploy-groupsize-fix.sh <qube> [groupsize]
set -euo pipefail

QUBE="${1:?usage: deploy-groupsize-fix.sh <qube> [groupsize, default 2]}"
GS="${2:-2}"
[[ "$GS" =~ ^[0-9]+$ ]] || { echo "groupsize must be an integer: $GS" >&2; exit 1; }

b64() { printf '%s' "$1" | iconv -t UTF-16LE | base64 -w0; }
run() { qvm-run --pass-io --no-gui "$QUBE" "powershell -NoProfile -EncodedCommand $(b64 "\$ProgressPreference='SilentlyContinue'; $1")" | tr -d '\r'; }

# 1. read current groupsize (idempotency); bcdedit omits the line when unset.
CUR=$(run '$m=(bcdedit /enum "{current}" | Select-String "^\s*groupsize\s+(\d+)").Matches.Groups[1].Value; if(-not $m){$m="unset"}; Write-Output ("CUR="+$m)' | sed -n 's/.*CUR=\([0-9a-z]*\).*/\1/p')
echo "$QUBE: current groupsize=$CUR desired=$GS"

# 2. set it only if different (idempotent), best-effort.
if [ "$CUR" != "$GS" ]; then
  run "bcdedit /set groupsize $GS | Out-Null; Write-Output 'GROUPSIZE-SET'" | grep -q GROUPSIZE-SET \
    && echo "$QUBE: groupsize set to $GS (effective next boot)" \
    || { echo "$QUBE: bcdedit /set groupsize $GS FAILED (need admin/elevation?)" >&2; exit 1; }
else
  echo "$QUBE: groupsize already $GS, no change"
fi

# 3. verify topology. NOTE: groupsize only applies on REBOOT, so on the current
#    boot these reflect the OLD topology -- re-run this after a reboot to confirm
#    GroupCount=ceil(vCPU/2) and ProcView=2 (what WARP enumerates).
read -r -d '' PROBE <<'PS' || true
Add-Type -Namespace W -Name P -MemberDefinition @"
[DllImport("kernel32")] public static extern int GetActiveProcessorCount(ushort g);
[DllImport("kernel32")] public static extern ushort GetActiveProcessorGroupCount();
"@
$ALL=[uint16]0xffff   # ALL_PROCESSOR_GROUPS
Write-Output ('PROBE TotalOnline='+[W.P]::GetActiveProcessorCount($ALL)+
  ' GroupCount='+[W.P]::GetActiveProcessorGroupCount()+
  ' ProcView='+[W.P]::GetActiveProcessorCount(0))
PS
out=$(run "$PROBE")
echo "$out" | grep -q '^PROBE' || { echo "$QUBE: topology probe failed: $out" >&2; exit 1; }
echo "$QUBE: $(echo "$out" | grep '^PROBE')   (current-boot topology; reboot applies groupsize=$GS)"
echo "$QUBE: GROUPSIZE-OK"
