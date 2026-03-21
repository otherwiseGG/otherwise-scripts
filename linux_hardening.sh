#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
#  Linux Security Hardening Script
# ─────────────────────────────────────────────

SSH_PORT=2222
SSH_USER="csadmin"
PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCQmVayZkGJHoGIQjRPsalfQCFahL9ni+nr4Vry2srDhM0Hm6X7zhC7u8RDYdHKtYrt40FZzRqmIrze/4/onVCMBp07QEdSNvGVdRWsj1U7P013Y9OIM+R1ccrUeRrlxIOiHQgjcf0bnZW9ArVE1OGOrQE5zBAbZSPDTAiP8Y1YTnLZHPu/nTFMmkaPobUdoshac7oXDtGXiZ8YrxPFQxG8xcviKknEllRifQbLtTMbr6jRUl5I246Vd1vQ1eIZ8iSQSvSwqwhaKc7UIntX5cB4w1YqGUiWlKQB8XUVXvMvOr+TrgMnTdSiHDzxDT0MIa8M1UV31hxi5PTHs3pfPc11 rsa-key-20251213"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

echo "[1/9] Creating user $SSH_USER ..."
if ! id "$SSH_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$SSH_USER"
  echo "$SSH_USER created."
else
  echo "$SSH_USER already exists, skipping."
fi

echo "[2/9] Adding $SSH_USER to passwordless sudo ..."
echo "$SSH_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$SSH_USER
chmod 440 /etc/sudoers.d/$SSH_USER

echo "[3/9] Adding public key ..."
USER_HOME=$(getent passwd "$SSH_USER" | cut -d: -f6)
mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
echo "$PUB_KEY" >> "$USER_HOME/.ssh/authorized_keys"
sort -u "$USER_HOME/.ssh/authorized_keys" -o "$USER_HOME/.ssh/authorized_keys"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
chown -R "$SSH_USER:$SSH_USER" "$USER_HOME/.ssh"

echo "[4/9] Hardening SSH config ..."
SSHD_CONF="/etc/ssh/sshd_config"
cp "$SSHD_CONF" "${SSHD_CONF}.bak.$(date +%F)"

apply_sshd() {
  local key="$1" val="$2"
  if grep -qE "^\s*#?\s*${key}\s" "$SSHD_CONF"; then
    sed -i -E "s|^\s*#?\s*${key}\s.*|${key} ${val}|" "$SSHD_CONF"
  else
    echo "${key} ${val}" >> "$SSHD_CONF"
  fi
}

apply_sshd Port              "$SSH_PORT"
apply_sshd Protocol          2
apply_sshd PermitRootLogin   no
apply_sshd PasswordAuthentication no
apply_sshd PubkeyAuthentication   yes
apply_sshd AuthorizedKeysFile     ".ssh/authorized_keys"
apply_sshd ChallengeResponseAuthentication no
apply_sshd UsePAM               yes
apply_sshd AllowUsers           "$SSH_USER"
apply_sshd ClientAliveInterval  300
apply_sshd ClientAliveCountMax  2
apply_sshd LoginGraceTime       30
apply_sshd MaxAuthTries         3

echo "[5/9] Installing & configuring fail2ban ..."
apt-get update -qq
apt-get install -y fail2ban

cat > /etc/fail2ban/jail.d/sshd-hardened.conf <<EOF
[sshd]
enabled  = true
port     = $SSH_PORT
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 4
bantime  = 3600
findtime = 600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

echo "[6/9] Enabling automatic security updates ..."
apt-get install -y unattended-upgrades apt-listchanges
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

echo "[7/9] Kernel hardening via sysctl ..."
cat > /etc/sysctl.d/99-hardening.conf <<'EOF'
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Disable IPv6 router advertisements
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# Disable IPv6 redirects
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Randomize VA space (ASLR)
kernel.randomize_va_space = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Restrict ptrace
kernel.yama.ptrace_scope = 1

# Prevent core dumps with setuid
fs.suid_dumpable = 0
EOF

sysctl -p /etc/sysctl.d/99-hardening.conf

echo "[8/9] Restarting SSH (new port: $SSH_PORT) ..."
systemctl restart sshd

echo ""
echo "═══════════════════════════════════════════════"
echo " Hardening complete. Summary:"
echo "  SSH Port       : $SSH_PORT"
echo "  SSH User       : $SSH_USER"
echo "  Root Login     : disabled"
echo "  Password Auth  : disabled"
echo "  Public Key     : added"
echo "  fail2ban       : active"
echo "  Auto-updates   : enabled"
echo "  Kernel sysctl  : applied"
echo ""
echo "  ⚠  Open port $SSH_PORT in your firewall before"
echo "     closing this session!"
echo "═══════════════════════════════════════════════"
