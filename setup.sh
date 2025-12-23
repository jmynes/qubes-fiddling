################################################
#        Defaults, run these every time        #
################################################
read -p "[dom0]: Make sure you are connected to the internet before continuing! Press enter to continue, when you are connected..."

echo -e "\n[dom0]: Updating dom0"
sudo qubes-dom0-update

echo -e "\n[dom0]: Installing emacs-nox"
sudo qubes-dom0-update emacs-nox

echo -e "\n[dom0]: Updating all templates"
read -p "(NOTE: If you are on a testing build of QubesOS, open qubes-global-config and go to the Updates tab, then select 'Enable all testing updates', and scroll down to enable whichever Template Repositories you would like to use).\nThen, press Enter to continue..."
qubes-vm-update --all

echo -e "\n[dom0]: Setting keyboard shortcuts"
./dom0/set-xfce4-keyboard-shortcuts.sh
echo -e "\n[dom0]: Setting window manager shortcuts"
./dom0/set-xfwm4-keyboard-shortcuts.sh


################################################
#        Defaults, run these every time        #
################################################
read -p "[dom0]: Configured! This is the last step, We are about to run windows.sh (this sets up Windows 10), so ctrl + c now if you would prefer not to do this"
./windows.sh
