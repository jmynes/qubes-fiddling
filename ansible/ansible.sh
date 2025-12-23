################################################
#    Setup ansible in non-disposable mgmtvm    #
################################################

echo -e "\n[dom0]: Create non-disposable [mgmtvm] qube, with 8GB RAM, 4vCPUs, and no networking"
qvm-create --template fedora-42-xfce --label red --property memory=800 --property maxmem=8000 --property vcpus=4 --property netvm="" mgmtvm

echo -e "\n[dom0]: Set [mgmtvm] qube to 20GiB of private storage"
qvm-volume resize mgmtvm:private 20GiB

echo -e "\n[dom0]: Copying policies for qubes-ansible into /etc/qubes/policy.d and /etc/qubes/policy.d/include"
sudo cp ./policies/30-ansible.policy /etc/qubes/policy.d/
sudo cp ./policies/30-ansible.policy/include/admin-global-ro  /etc/qubes/policy.d/include/
sudo cp ./policies/30-ansible.policy/include/admin-local-rwx  /etc/qubes/policy.d/include/ 

echo -e "\n[dom0]: Tagging created-by-mgmtvm on all default qubes and templates"
qvm-tags anon-whonix add created-by-mgmtvm
qvm-tags debian-13-xfce add created-by-mgmtvm
qvm-tags fedora-42-xfce add created-by-mgmtvm
qvm-tags personal add created-by-mgmtvm
qvm-tags sys-firewall add created-by-mgmtvm
qvm-tags sys-net add created-by-mgmtvm
qvm-tags sys-usb add created-by-mgmtvm
qvm-tags sys-whonix add created-by-mgmtvm
qvm-tags untrusted add created-by-mgmtvm
qvm-tags vault add created-by-mgmtvm
qvm-tags whonix-workstation-18 add created-by-mgmtvm
qvm-tags whonix-workstation-18-dvm add created-by-mgmtvm
qvm-tags work add created-by-mgmtvm

#echo -e "\n[dom0]: Tagging created-by-mgmtvm on additional sys-usb qubes"
#qvm-tags sys-usb-2 add created-by-mgmtvm
#qvm-tags sys-usb-3 add created-by-mgmtvm

echo -e "\n[mgmtvm]: Installing qubes-ansible-vm"
qvm-run --pass-io mgmtvm "sudo dnf install qubes-ansible-vm"

echo -e "\n[dom0]: Copying playbooks to mgmtvm"
qvm-copy-to-vm mgmtvm ./playbooks 

echo -e "\n[dom0]: Copying inventory.ini to mgmtvm"
qvm-copy-to-vm mgmtvm ./inventory.ini

echo -e "\n[mgmtvm]: Staging a directory for ansible files"
qvm-run --pass-io mgmtvm "mkdir -p ~/ansible/playbooks"

echo -e "\n[mgmtvm]: Moving ansible files into place"
qvm-run --pass-io mgmtvm "mv ~/QubesIncoming/dom0/playbooks ~/ansible/playbooks"
qvm-run --pass-io mgmtvm "mv ~/QubesIncoming/dom0/inventory.ini ~/ansible/"
