#!/bin/bash
# Unified launcher: open a terminal, settings, or file manager for the currently focused Qube
# Usage:
#   open-in-focused-qube.sh files
#   open-in-focused-qube.sh settings
#   open-in-focused-qube.sh terminal
#
# Behavior:
# - Detects the focused window's Qube name using xdotool + xprop.
#
# - If focus is in dom0 (no _QUBES_VMNAME), we run:
#     - files    -> opens a local file manager (thunar)
#     - settings -> opens Global Qubes Settings (qubes-global-config)
#     - terminal -> opens a local dom0 terminal (xfce4-terminal)
#
# - If focus is in a Qube, runs:
#     - files    -> opens the default file manager for a qube
#     - settings -> opens the settings dialog for a qube
#     - terminal -> opens the default terminal inside that qube
#

set -euo pipefail

usage() { echo "Usage: $(basename "$0") {terminal|settings|files}" >&2; exit 2; }

# Accepts one argument (case-insensitive), with some aliases:
[[ $# -eq 1 ]] || usage
action="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

case "$action" in
  term|terminal) action="terminal" ;;
  set|settings)  action="settings" ;;
  file|files|fm|filemgr|file-manager|filemanager) action="files" ;;
  *) usage ;;
esac

# Get focused window id
if ! ID="$(xdotool getwindowfocus 2>/dev/null)"; then
  echo "Error: Could not determine focused window (xdotool failed)." >&2
  exit 1
fi

# Read the qube name from the focused window (_QUBES_VMNAME).
# If Empty, assume dom0
QUBE="$(xprop -id "$ID" _QUBES_VMNAME 2>/dev/null | sed -n 's/.*\"\(.*\)\".*/\1/p')"

run_dom0_terminal() {
  # Prefer xfce4-terminal, fallback to xterm if needed
  if command -v xfce4-terminal >/dev/null 2>&1; then
    xfce4-terminal & disown
  else
    xterm & disown
  fi
}

run_qube_terminal() {
  local vm="$1"
  # Prefer qubes-run-terminal within the VM, fallback to xfce4-terminal/xterm
  qvm-run --pass-io "$vm" '/usr/bin/qubes-run-terminal || xfce4-terminal || xterm' & disown
}

run_dom0_settings() {
  # Open Qubes Global Config
  qubes-global-config;
}

run_qube_settings() {
  # Open the settings for the target qube
  qubes-vm-settings "$1";
}

run_dom0_files() {
  # Prefer exo-open, fallback to xdg-open or thunar if needed
  if command -v exo-open >/dev/null 2>&1; then
    exo-open --launch FileManager "$HOME" >/dev/null 2>&1 &
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open --launch FileManager "$HOME" >/dev/null 2>&1 &
  else
    thunar "$HOME" >/dev/null 2>&1 &
  fi
}

# VM: same logic inside the focused qube, detached, and with explicit exit to avoid fallthrough
run_qube_files() {
  local vm="$1"
  setsid -f qvm-run -q "$vm" '
    if command -v exo-open >/dev/null 2>&1; then
      setsid -f exo-open --launch FileManager "$HOME" >/dev/null 2>&1 &
      exit 0
    elif command -v xdg-open >/dev/null 2>&1; then
      setsid -f xdg-open "$HOME" >/dev/null 2>&1 &
      exit 0
    elif command -v thunar >/dev/null 2>&1; then
      setsid -f thunar "$HOME" >/dev/null 2>&1 &
      exit 0
    else
      exit 1
    fi
  ' >/dev/null 2>&1 &
}

if [[ -z "${QUBE}" ]]; then
  case "$action" in
    files)    run_dom0_files ;;
    terminal) run_dom0_terminal ;;
    settings) run_dom0_settings ;;
  esac
else
  case "$action" in
    files)    run_qube_files "$QUBE" ;;
    terminal) run_qube_terminal "$QUBE" ;;
    settings) run_qube_settings "$QUBE" ;;
  esac
fi
