#!/bin/bash

# -----------------------------------------------------------
# MODULE: Fail2Ban Core & SSH Protection
# File: setup_fail2ban_core.sh
# Muc dich: Cai dat Fail2Ban, UFW va bao ve SSH (Luon luon can)
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Cau hinh
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Whitelist IP (Localhost & IP quan tri cua ban neu co)
IGNORE_IPS="127.0.0.1/8 ::1"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. Kiem tra Root
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   # -E để giữ lại biến môi trường
   sudo -E "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. Cai dat
echo -e "${GREEN}>>> [CORE] Dang cai dat Fail2Ban & UFW...${NC}"
apt-get update -qq
apt-get install -y fail2ban ufw

# Kiem tra UFW status
if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}Canh bao: UFW chua duoc bat. Fail2Ban can UFW de hoat dong.${NC}"
    echo -e "${YELLOW}Hay chay 'ufw enable' sau khi script ket thuc.${NC}"
fi

# Tao config local
if [[ ! -f /etc/fail2ban/jail.local ]]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi

# Them Whitelist
if ! grep -q "^ignoreip =" /etc/fail2ban/jail.local; then
    sed -i "/^\[DEFAULT\]/a ignoreip = $IGNORE_IPS" /etc/fail2ban/jail.local
    echo -e "${GREEN}Da them Whitelist: $IGNORE_IPS${NC}"
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++


# -------------------------------------------------------------------------------------------------------------------------------
# D. Cau hinh SSH Jail
echo -e "${GREEN}>>> [CORE] Dang cau hinh bao ve SSH...${NC}"

# Tu dong tim Port SSH
DETECTED_PORT=$(sshd -T 2>/dev/null | grep "^port " | head -n 1 | awk '{print $2}' || true)
if [[ -z "$DETECTED_PORT" ]]; then
    DETECTED_PORT=$(grep -i "^[[:space:]]*Port" /etc/ssh/sshd_config | head -n 1 | awk '{print $2}' || true)
fi
SSH_PORT=${DETECTED_PORT:-22}
echo -e "${YELLOW}Phat hien SSH Port: ${SSH_PORT}${NC}"

# Ghi file cau hinh SSH rieng biet
cat > /etc/fail2ban/jail.d/99-ssh-wpsila.conf <<EOF
[sshd]
enabled = true
port    = $SSH_PORT
logpath = %(sshd_log)s
backend = systemd
maxretry = 3
findtime = 600
bantime  = 3600
banaction = ufw
ignoreip = $IGNORE_IPS
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# E. Khoi dong
echo -e "${GREEN}>>> [CORE] Khoi dong Fail2Ban...${NC}"
systemctl unmask fail2ban > /dev/null 2>&1 || true
if systemctl restart fail2ban; then
    echo -e "${GREEN}SUCCESS: Fail2Ban Core (SSH) da hoat dong!${NC}"
    fail2ban-client status sshd
else
    echo -e "${RED}ERROR: Khong the khoi dong Fail2Ban.${NC}"
    fail2ban-client -d
    exit 1
fi
# -------------------------------------------------------------------------------------------------------------------------------