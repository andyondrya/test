# 1. Cloud-init test state
sudo cloud-init clean --logs --seed

# 2. Machine ID
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id

# 3. SSH host keys
sudo rm -f /etc/ssh/ssh_host_*

# 4. Logs, history, temp files
sudo truncate -s 0 /var/log/wtmp /var/log/lastlog /var/log/btmp
sudo find /var/log -type f -name '*.gz' -delete
sudo find /var/log -type f -name '*.log' -exec truncate -s 0 {} \;
sudo rm -rf /tmp/* /var/tmp/*
history -c
rm -f ~/.bash_history
sudo rm -f /root/.bash_history

# 5. Package cache
sudo apt-get clean
sudo apt-get autoremove --purge -y
sudo rm -rf /var/lib/apt/lists/*

# 6. Network/DHCP leases
sudo rm -f /var/lib/dhcp/*.leases
sudo rm -f /etc/udev/rules.d/70-persistent-net.rules

# 7. Zero free space (optional)
sudo fstrim -av
# or, if fstrim isn't supported:
sudo dd if=/dev/zero of=/EMPTY bs=1M || true
sudo rm -f /EMPTY
sync

# 8. Shut down (do not reboot)
sudo shutdown -h now
