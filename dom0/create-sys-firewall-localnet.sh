# TODO: Ansibilize this

echo ""
echo "############################################"
echo "# Starting create-sys-firewall-localnet.sh #"
echo "#  (This splits & configures sys-firewall) #" 
echo "############################################"

echo -e "\n[dom0 - create-sys-firewall-localnet.sh]: Cloning sys-firewall to sys-firewall-localnet"
qvm-clone sys-firewall

echo -e "\n[dom0 - create-sys-firewall-localnet.sh]: Resetting and then configuring firewall settings for sys-firewall-localnet"
qvm-firewall sys-firewall-localnet reset &&
qvm-firewall sys-firewall-localnet add action=accept dsthost=10.0.0.0/8 &&
qvm-firewall sys-firewall-localnet add action=accept dsthost=192.168.0.0/16 &&
qvm-firewall sys-firewall-localnet add action=accept proto=icmp &&
qvm-firewall sys-firewall-localnet add action=accept specialtarget=dns &&
qvm-firewall sys-firewall-localnet del action=accept &&
qvm-firewall sys-firewall-localnet add action=drop &&
sync; sleep 5
qvm-start sys-firewall-localnet;

echo -e "\n[dom0 - create-sys-firewall-localnet.sh]: Sleeping a while (50 seconds), to wait for sys-firewall-localnet to start..."
sleep 50; # probably a better way to do this...

echo -e "\n[dom0 - create-sys-firewall-localnet.sh]: Changing default_netvm to sys-firewall-localnet"
qubes-prefs default_netvm sys-firewall-localnet
