# Install the EXPERIMENTAL Qubes GUI agent (`Gui` MSI feature) into the
# already-installed Qubes Windows Tools, so the qube can use the in-guest native
# GUI agent instead of the qemu-stubdom emulated framebuffer. The default QWT
# `/passive` install skips `Gui` (it's experimental). User-mode only -- there is
# NO video driver yet (a documented "TODO: custom WDDM driver" in
# qubes-gui-agent-windows), so the guest stays on Microsoft Basic Display
# Adapter; that is expected. Full-desktop mode only (no seamless).
#
# Run via: cat install-gui-agent.ps1 | qvm-run -p <vm> 'powershell -NoProfile -Command -'
# Emits GUI-OK on success (Gui feature state == 3/local), else GUI-FAIL.
$ErrorActionPreference = 'SilentlyContinue'

$keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
$pc = (Get-ChildItem $keys |
       Where-Object { (Get-ItemProperty $_.PSPath).DisplayName -match 'Qubes Windows Tools' } |
       Select-Object -First 1).PSChildName
if (-not $pc) { Write-Output 'GUI-FAIL: Qubes Windows Tools product not found'; exit 0 }

# Add the Gui feature to the installed product (MSI source is cached in C:\Windows\Installer).
Start-Process msiexec -ArgumentList "/i $pc ADDLOCAL=Gui /qn /norestart" -Wait | Out-Null

# Verify it actually went local before the caller flips gui-emulated off.
$inst = New-Object -ComObject WindowsInstaller.Installer
$st = try { $inst.FeatureState($pc, 'Gui') } catch { -1 }    # 3 = INSTALLSTATE_LOCAL
if ($st -eq 3) { Write-Output "GUI-OK product=$pc Gui=local" }
else           { Write-Output "GUI-FAIL product=$pc Gui-state=$st" }
