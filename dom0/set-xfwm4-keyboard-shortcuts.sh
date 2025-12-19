#!/bin/bash
# Set Super+Arrow XFCE tiling keybindings

echo ""
echo "############################################"
echo "# Starting set-xfwm4-keyboard-shortcuts.sh #"
echo "#    (This configures window keybinds)     #"
echo "############################################"

echo -e "\nRemoving default mapping for Alt F10 (we will remap it in just a moment, in the set-xfce4-keyboard-shortcuts.sh script"
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt>F10" -r 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/default/<Alt>F10" -r 2>/dev/null

echo -e "\nReloading the xfce window manager (xfwm4)"
xfwm4 --replace >/dev/null 2>&1 & disown

echo -e "\nAssigning <Super>Left-Arrow --> Tile Window to Left"
xfconf-query -c xfce4-keyboard-shortcuts -n -p "/xfwm4/custom/<Super>Left"  -t string -s "tile_left_key"
echo "Assigning <Super>Right-Arrow --> Tile Window to Right"
xfconf-query -c xfce4-keyboard-shortcuts -n -p "/xfwm4/custom/<Super>Right" -t string -s "tile_right_key"
echo "Assigning <Super>Up-Arrow --> Maximize Window"
xfconf-query -c xfce4-keyboard-shortcuts -n -p "/xfwm4/custom/<Super>Up"    -t string -s "maximize_window_key"
echo "Assigning <Super>Down-Arrow --> Hide (Minimize) Window"
xfconf-query -c xfce4-keyboard-shortcuts -n -p "/xfwm4/custom/<Super>Down"  -t string -s "hide_window_key"

echo -e "\nAssigning shortcuts only valid in Qubes OS 4.3 and higher (because xfce updated)"
echo "Assigning <Ctrl><Super>Left --> Move Window to Left Monitor"
xfconf-query -c xfce4-keyboard-shortcuts -n -p "/xfwm4/custom/<Primary><Super>Left"  -t string -s "move_window_to_monitor_left_key"
echo "Assigning <Ctrl><Super>Right --> Move Window to Right Monitor"
xfconf-query -c xfce4-keyboard-shortcuts -n -p "/xfwm4/custom/<Primary><Super>Right"  -t string -s "move_window_to_monitor_right_key"
echo "Assigning <Ctrl><Super>Up --> Move Window to Up Monitor"
xfconf-query -c xfce4-keyboard-shortcuts -n -p "/xfwm4/custom/<Primary><Super>Up"  -t string -s "move_window_to_monitor_up_key"
echo "Assigning <Ctrl><Super>Down --> Move Window to Down Monitor"
xfconf-query -c xfce4-keyboard-shortcuts -n -p "/xfwm4/custom/<Primary><Super>Down"  -t string -s "move_window_to_monitor_down_key"
