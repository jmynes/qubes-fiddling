#!/bin/bash
set -euo pipefail

echo ""
echo "############################################"
echo "# Starting set-xfce4-keyboard-shortcuts.sh #"
echo "#   (This sets basic keyboard shortcuts)   #"
echo "############################################"


CHANNEL="xfce4-keyboard-shortcuts"

# TODO: make sure on next provision, that our new Super + S overrides (blanks first?)
## the original mapping (xfce4-session-logout)
### [Or, find a better key combo I guess]

declare -A SHORTCUTS=(
  ["<Super>a"]="qvm-run --pass-io mgmtvm 'xfce4-terminal'"
  ["<Super>b"]="qubes-backup"
  ["<Super>d"]="xfce4-terminal"
  ["<Super>f"]="/home/user/qubes-fiddling/dom0/open-in-focused-qube.sh files"
  ["<Super>k"]="xfce4-keyboard-settings"
  ["<Super>l"]="xflock4"
  ["<Super>m"]="qubes-qube-manager"
  ["<Super>r"]="qubes-backup-restore"
  ["<Super>s"]="/home/user/qubes-fiddling/dom0/open-in-focused-qube.sh settings"
  ["<Super>t"]="/home/user/qubes-fiddling/dom0/open-in-focused-qube.sh terminal"
  ["<Super>w"]="/home/user/qubes-fiddling/dom0/open-in-focused-qube.sh browser"
 #["<Super>w"]="qvm-run --pass-io personal firefox"
  ["<Super>f2"]="/home/user/qubes-fiddling/dom0/open-in-focused-qube.sh appfinder"
)

for KEY in "${!SHORTCUTS[@]}"; do
  CMD="${SHORTCUTS[$KEY]}"
  KEY_PATH="/commands/custom/$KEY"

  if xfconf-query -c "$CHANNEL" -p "$KEY_PATH" &>/dev/null; then
    echo "Shortcut $KEY already exists. Skipping."
    continue
  fi

  echo "Assigning $KEY --> $CMD"
  xfconf-query -c "$CHANNEL" -n -p "$KEY_PATH" -t string -s "$CMD"
done
