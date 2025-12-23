################################################
#        Defaults, run these every time        #
################################################
read -p "[dom0 - setup.sh]: Make sure you are connected to the internet before continuing! Press enter to continue, when you are connected..."

echo -e "\n[dom0 - setup.sh]: Updating dom0"
sudo qubes-dom0-update

echo -e "\n[dom0 - setup.sh]: Installing emacs-nox"
sudo qubes-dom0-update emacs-nox

echo -e "\n[dom0 - setup.sh]: Updating all templates"
read -p "(NOTE: If you are on a testing build of QubesOS, open qubes-global-config and go to the Updates tab, then select 'Enable all testing updates', and scroll down to enable whichever Template Repositories you would like to use).\nThen, press Enter to continue..."
qubes-vm-update --all

echo -e "\n[dom0 - setup.sh]: Setting keyboard shortcuts"
./dom0/set-xfce4-keyboard-shortcuts.sh
echo -e "\n[dom0 - setup.sh]: Setting window manager shortcuts"
./dom0/set-xfwm4-keyboard-shortcuts.sh


################################################
#  Set up sys-firewall-localnet, mgmtvm, pull  #
################################################
echo -e "\n[dom0 - setup.sh]: Now setting up sys-firewall-localnet..."
./dom0/create-sys-firewall-localnet.sh

echo -e "\n[dom0 - setup.sh]: Now setting up mgmtvm..."
./ansible/ansible.sh

echo -e "\n[dom0 - setup.sh]: Now setting up `pull` alias, for getting files from mgmtvm into dom0"
./dom0/pull.sh


################################################
#      Run windows.sh, setting up Win 10       #
################################################
read -p "\n[dom0 - setup.sh]: Configured! This is the last step, We are about to run windows.sh (this sets up Windows 10), so ctrl + c now if you would prefer not to do this"
./windows.sh
