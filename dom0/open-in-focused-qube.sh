#!/bin/bash
# Unified launcher: open a terminal, settings, or file manager for the currently focused Qube
# Usage:
#   open-in-focused-qube.sh appfinder
#   open-in-focused-qube.sh browser
#   open-in-focused-qube.sh files
#   open-in-focused-qube.sh settings
#   open-in-focused-qube.sh terminal
#
# Behavior:
# - Detects the focused window's Qube name using xdotool + xprop.
#
# - If focus is in dom0 (no _QUBES_VMNAME), we run:
#     - appfinder -> opens a local appfinder popup (xfce4-appfinder --collapsed)
#     - browser   -> nothing happens! (dom0 does not have a web browser)
#     - files     -> opens a local dom0 file manager (thunar)
#     - settings  -> opens Global Qubes Settings (qubes-global-config)
#     - terminal  -> opens a local dom0 terminal (xfce4-terminal)
#
# - If focus is in a Qube, runs:
#     - appfinder -> opens the appfinder popup in a focused qube (xfce4-appfinder --collapsed)
#     - browser   -> opens the default web browser for a qube (firefox as fallback)
#     - files     -> opens the default file manager for a qube (thunar as fallback)
#     - settings  -> opens the Qubes Settings dialog for a qube
#     - terminal  -> opens the default terminal inside that qube (xfce4-terminal, and then xterm as fallbacks)
#

set -euo pipefail

usage() { echo "Usage: $(basename "$0") {appfinder|browser|terminal|settings|files}" >&2; exit 2; }

# Accepts one argument (case-insensitive), with some aliases:
[[ $# -eq 1 ]] || usage
action="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

case "$action" in
  app|appfinder|finder|applauncher|launcher) action="appfinder" ;;
  web|browser) action="browser" ;;
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
  setsid -f qvm-run -q "$vm" '
    if command -v qubes-run-terminal >/dev/null 2>&1; then
      setsid -f qubes-run-terminal >/dev/null 2>&1 &
      exit 0
    elif command -v exo-open >/dev/null 2>&1; then
      setsid -f exo-open --launch TerminalEmulator >/dev/null 2>&1 &
      exit 0
    elif command -v xfce4-terminal >/dev/null 2>&1; then
      setsid -f xfce4-terminal >/dev/null 2>&1 &
      exit 0
    elif command -v xterm >/dev/null 2>&1; then
      setsid -f xterm >/dev/null 2>&1 &
      exit 0
    else
      exit 1
    fi
  ' >/dev/null 2>&1 &

  # qvm-run --pass-io "$vm" '/usr/bin/qubes-run-terminal || xfce4-terminal || xterm' & disown
}


run_dom0_appfinder() {
  # This does the exact same thing as Alt + F2 does by default
  xfce4-appfinder --collapsed;
}

run_qube_appfinder() {
  # Open appfinder in target qube
  local vm="$1"
  qvm-run --pass-io "$vm" 'xfce4-appfinder --collapsed' & disown
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

run_dom0_browser() {
  # dom0 doesn't have a web browser
  exit
}

run_qube_browser() {
  local vm="$1"
  setsid -f qvm-run -q "$vm" '
    if command -v exo-open >/dev/null 2>&1; then
      setsid -f exo-open --launch WebBrowser >/dev/null 2>&1 &
      exit 0
    elif command -v firefox-esr >/dev/null 2>&1; then
      setsid -f firefox-esr >/dev/null 2>&1 &
      exit 0
    elif command -v firefox >/dev/null 2>&1; then
      setsid -f firefox >/dev/null 2>&1 &
      exit 0
    else
      exit 1
    fi
  ' >/dev/null 2>&1 &
}

if [[ -z "${QUBE}" ]]; then
  case "$action" in
    appfinder) run_dom0_appfinder ;;
    browser)  run_dom0_browser ;;
    files)    run_dom0_files ;;
    terminal) run_dom0_terminal ;;
    settings) run_dom0_settings ;;
  esac
else
  case "$action" in
    appfinder) run_qube_appfinder "$QUBE" ;;
    browser)  run_qube_browser "$QUBE" ;;
    files)    run_qube_files "$QUBE" ;;
    terminal) run_qube_terminal "$QUBE" ;;
    settings) run_qube_settings "$QUBE" ;;
  esac
fi
