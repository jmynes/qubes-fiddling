################################################
# Setup Windows 10x64 Pro TemplateVM and AppVM #
################################################

#
#echo -e "\n[dom0]: Setting up a DisposableVM, downloads-dispvm, for downloading things in this script"
#qvm-create -C DispVM downloads-dispvm -l red
#qvm-prefs downloads-dispvm netvm sys-firewall

##### set size of storage of default-dvm next?
#

echo -e "\n[dom0]: Set [personal] qube to 20GiB of private storage"
qvm-volume resize personal:private 20GiB

echo -e "\n[personal]: Download qvm-create-windows-qube from github as zip file"
qvm-run --pass-io personal "curl -L -O https://github.com/ElliotKillick/qvm-create-windows-qube/archive/refs/heads/master.zip"

echo -e "\n[personal]: Cat zip file, outputting its contents into [dom0]; then, delete it from [personal] qube"
qvm-run --pass-io personal "cat ~/master.zip" > master.zip
qvm-run --pass-io personal "rm ~/master.zip"

echo -e "\n[dom0]: Unzipping, then removing master.zip"
unzip master.zip
rm master.zip

echo -e "\n[dom0]: Setting install.sh to be executable, then running it to set up windows-mgmt"
chmod +x ./qvm-create-windows-qube-master/install.sh
./qvm-create-windows-qube-master/install.sh

#echo -e "\n[dom0]: Copying mido.sh to [downloads-dispvm]"
#qvm-copy-to-vm downloads-dispvm ./qvm-create-windows-qube-master/windows/isos/mido.sh

echo -e "\n[dom0]: Copying mido.sh to [personal] qube"
qvm-copy-to-vm personal ./qvm-create-windows-qube-master/windows/isos/mido.sh

read -p "\n[dom0]: Since mido.sh isn't working lately, make sure to go download a Win10x64-pro.iso from Microsoft or Archive.org. Please press enter to continue when ready..."

#echo -e "\n[personal]: Download Win10x64-pro.iso from mido.sh"
#./qvm-create-windows-qube-master/windows/isos/mido.sh win10x64-pro
## I would *prefer* to use win10x64-enterprise-ltsc-eval, if it starts working again...

# Then check if it's there, then move it to windows-mgmt under ~/home/user/qvm-create-windows-qube/windows/isos

echo -e "\n[dom0]: Using [windows-mgmt] to install [win10-pro] TemplateVM, with packages: firefox, notepad++, office 365 Pro Plus, git, python3, 7zip, dotnet 6.0, steam"
qvm-create-windows-qube -n sys-firewall -oyp firefox,notepadplusplus,office365proplus,git,python3,7zip,dotnet-6.0-desktopruntime,steam -i win10x64-pro.iso -a win10x64-pro.xml -t win10-pro
