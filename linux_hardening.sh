#!/bin/bash

# Enterprise Hardening Script für Debian 13 (Hetzner Cloud)
# Fokus: System-Absicherung & User-Management (Ohne lokale Firewall)

set -e

# --- KONFIGURATION ---
NEW_USER="otherwise"
AUTHORIZED_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCQmVayZkGJHoGIQjRPsalfQCFahL9ni+nr4Vry2srDhM0Hm6X7zhC7u8RDYdHKtYrt40FZzRqmIrze/4/onVCMBp07QEdSNvGVdRWsj1U7P013Y9OIM+R1ccrUeRrlxIOiHQgjcf0bnZW9ArVE1OGOrQE5zBAbZSPDTAiP8Y1YTnLZHPu/nTFMmkaPobUdoshac7oXDtGXiZ8YrxPFQxG8xcviKknEllRifQbLtTMbr6jRUl5I246Vd1vQ1eIZ8iSQSvSwqwhaKc7UIntX5cB4w1YqGUiWlKQB8XUVXvMvOr+TrgMnTdSiHDzxDT0MIa8M1UV31hxi5PTHs3pfPc11 rsa-key-20251213"

echo "### [1/10] System-Update und Basis-Tools..."
apt update && apt upgrade -y
apt install -y sudo curl gnupg2 fail2ban unattended-upgrades apt-listchanges libpam-pwquality

echo "### [2/10] User '$NEW_USER' anlegen..."
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

echo "### [3/10] SSH-Dienst härten..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Strikte SSH-Konfiguration
sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
# Nur 'otherwise' darf per SSH rein
echo "AllowUsers $NEW_USER" >> /etc/ssh/sshd_config

# Configure login banner
echo "Configuring login banner..."
echo "Authorized access only. All activity may be monitored and reported." > /etc/issue.net
sed -i 's/^#Banner.*/Banner \/etc\/issue.net/' /etc/ssh/sshd_config

systemctl restart ssh

echo "### [4/10] Kernel-Hardening (Sysctl)..."
cat <<EOF > /etc/sysctl.d/99-enterprise-hardening.conf
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0
net.ipv6.conf.all.disable_ipv6 = 1
fs.suid_dumpable = 0
EOF
sysctl --system

echo "### [5/10] Sudo Command Logging aktivieren..."
# Enable logging of sudo commands
echo "Enabling logging of sudo commands..."
if ! grep -q "^Defaults logfile=" /etc/sudoers; then
    echo "Defaults logfile=/var/log/sudo.log" >> /etc/sudoers
fi

echo "### [6/10] Starke Passwort-Richtlinien setzen..."
# Set strong password policies
echo "Setting strong password policies..."
sed -i 's/^# minlen.*/minlen = 12/' /etc/security/pwquality.conf
sed -i 's/^# dcredit.*/dcredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# ucredit.*/ucredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# lcredit.*/lcredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# ocredit.*/ocredit = -1/' /etc/security/pwquality.conf

echo "### [7/10] Shared Memory absichern..."
# Secure shared memory
echo "Securing shared memory..."
if ! grep -q "tmpfs /run/shm" /etc/fstab; then
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
fi

echo "### [8/10] Log-Dateiberechtigungen setzen..."
# Set up log file permissions
echo "Setting up log file permissions..."
chmod -R go-rwx /var/log/* 2>/dev/null || true

echo "### [9/10] Cron-Jobs auf autorisierte Benutzer beschränken..."
# Restrict cron jobs to authorized users
echo "Restricting cron jobs to authorized users..."
touch /etc/cron.allow
chmod 600 /etc/cron.allow

echo "### [10/10] Core Dumps deaktivieren und Automatische Sicherheitsupdates aktivieren..."
# Disable core dumps
echo "Disabling core dumps..."
if ! grep -q "^\* hard core 0" /etc/security/limits.conf; then
    echo "* hard core 0" >> /etc/security/limits.conf
fi

# Automatische Sicherheitsupdates aktivieren
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

echo "#########################################################"
echo "HARDENING ABGESCHLOSSEN (Ohne lokale Firewall)!"
echo "User: $NEW_USER"
echo "SSH-Login: ssh $NEW_USER@$(hostname -I | awk '{print $1}')"
echo ""
echo "Angewandte Sicherheitsmaßnahmen:"
echo "  - System-Updates und Basis-Tools installiert"
echo "  - SSH-Dienst gehärtet (nur Key-Auth, Login-Banner)"
echo "  - Kernel-Hardening (Sysctl, IPv6 deaktiviert)"
echo "  - Sudo-Befehl-Logging aktiviert"
echo "  - Starke Passwort-Richtlinien konfiguriert"
echo "  - Shared Memory abgesichert"
echo "  - Log-Dateiberechtigungen gesetzt"
echo "  - Cron-Jobs auf autorisierte Benutzer beschränkt"
echo "  - Core Dumps deaktiviert"
echo "  - Automatische Sicherheitsupdates aktiviert"
echo "#########################################################"
