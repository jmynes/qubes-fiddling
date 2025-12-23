echo -e "\n[dom0 - pull.sh]: Adding alias for 'pull'"
cat /home/user/qubes-fiddling/dom0/alias-for-dom0-bashrc >> /home/user/.bashrc
echo -e "\n[dom0 - pull.sh]: .bashrc now ends with:"
tail "/home/user/.bashrc"
