#!/bin/bash

# Enterprise Hardening Script für Debian 13 (Hetzner Cloud)
# Fokus: System-Absicherung & User-Management (Ohne lokale Firewall)

set -e

# --- KONFIGURATION ---
NEW_USER="otherwise"
AUTHORIZED_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCQmVayZkGJHoGIQjRPsalfQCFahL9ni+nr4Vry2srDhM0Hm6X7zhC7u8RDYdHKtYrt40FZzRqmIrze/4/onVCMBp07QEdSNvGVdRWsj1U7P013Y9OIM+R1ccrUeRrlxIOiHQgjcf0bnZW9ArVE1OGOrQE5zBAbZSPDTAiP8Y1YTnLZHPu/nTFMmkaPobUdoshac7oXDtGXiZ8YrxPFQxG8xcviKknEllRifQbLtTMbr6jRUl5I246Vd1vQ1eIZ8iSQSvSwqwhaKc7UIntX5cB4w1YqGUiWlKQB8XUVXvMvOr+TrgMnTdSiHDzxDT0MIa8M1UV31hxi5PTHs3pfPc11 rsa-key-20251213"

echo "### [1/5] System-Update und Basis-Tools..."
apt update && apt upgrade -y
apt install -y sudo curl gnupg2 fail2ban unattended-upgrades apt-listchanges

echo "### [2/5] User '$NEW_USER' anlegen..."
if id "$NEW_USER" &>/dev/null; then
    echo "User existiert bereits."
else
    # User ohne Passwort anlegen
    adduser --disabled-password --gecos "" $NEW_USER
    # Sudo-Rechte ohne Passwort (praktisch für Automatisierung, optional änderbar)
    echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-otherwise-init
    
    # SSH Key hinterlegen
    mkdir -p /home/$NEW_USER/.ssh
    echo "$AUTHORIZED_KEY" > /home/$NEW_USER/.ssh/authorized_keys
    chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
    chmod 700 /home/$NEW_USER/.ssh
    chmod 600 /home/$NEW_USER/.ssh/authorized_keys
fi

echo "### [3/5] SSH-Dienst härten..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Strikte SSH-Konfiguration
sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
# Nur 'otherwise' darf per SSH rein
echo "AllowUsers $NEW_USER" >> /etc/ssh/sshd_config

systemctl restart ssh

echo "### [4/5] Kernel-Hardening (Sysctl)..."
cat <<EOF > /etc/sysctl.d/99-enterprise-hardening.conf
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0
EOF
sysctl --system

echo "### [5/5] Automatische Sicherheitsupdates aktivieren..."
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

echo "#########################################################"
echo "HARDENING ABGESCHLOSSEN (Ohne lokale Firewall)!"
echo "User: $NEW_USER"
echo "SSH-Login: ssh $NEW_USER@$(hostname -I | awk '{print $1}')"
echo "#########################################################"
