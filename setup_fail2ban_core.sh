#!/bin/bash

# -----------------------------------------------------------
# MODULE: Fail2Ban Core & bảo vệ SSH
# File: setup_fail2ban_core.sh
# OS Support: Ubuntu 22.04 / 24.04 LTS
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
set -euo pipefail
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- MÀU SẮC ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Bổ sung dải IP rộng hơn, phòng tự chặn trong các bối cảnh mạng LAN, VPN
IGNORE_IPS="127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- KIỂM TRA ROOT ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}Dang chuyen sang quyen root...${NC}"
   sudo -E "$0" "$@"
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- 1. CÀI ĐẶT & KIỂM TRA PHỤ THUỘC ---
echo -e "${GREEN}>>> [CORE] Kiem tra Fail2Ban & UFW...${NC}"

# Tu dong cai dat neu thieu (Dam bao script chay doc lap duoc)
if ! command -v fail2ban-client &> /dev/null; then
    echo -e "${YELLOW}Fail2Ban chua duoc cai dat. Dang cai dat...${NC}"
    apt-get update -qq && apt-get install -y fail2ban ufw
fi

# Kiem tra UFW
if ! ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}CANH BAO: UFW chua duoc bat!${NC}"
    echo -e "Fail2Ban se khong the chan IP neu UFW tat."
    echo -e "Script se tiep tuc, nhung hay nho chay: ${GREEN}ufw enable${NC} sau."
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- 2. CẤU HÌNH GLOBAL (JAIL.LOCAL) ---
echo -e "${GREEN}>>> [CORE] Tao cau hinh Global (Systemd Backend)...${NC}"

# Backup file cu neu ton tai
if [ -f /etc/fail2ban/jail.local ]; then
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak
fi

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
# 1. Whitelist
ignoreip = $IGNORE_IPS

# 2. Hanh dong (Su dung UFW)
banaction = ufw

# 3. Backend (QUAN TRONG CHO UBUNTU 22.04/24.04)
# Su dung journald thay vi log file (tranh loi missing log path)
backend = systemd

# 4. Thoi gian & Retry
bantime  = 1h
findtime = 10m
maxretry = 5

# 5. Incremental Ban (Phat nang neu tai pham)
bantime.increment = true
bantime.factor = 1
bantime.formula = ban.Time * (1<<(ban.Count if ban.Count<20 else 20)) * banFactor
EOF
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- 3. CẤU HÌNH SSH PROTECT ---
echo -e "${GREEN}>>> [CORE] Cau hinh bao ve SSH...${NC}"

# Tu dong tim SSH Port chinh xac nhat
DETECTED_PORT=$(sshd -T 2>/dev/null | grep "^port " | head -n 1 | awk '{print $2}' || true)
if [[ -z "$DETECTED_PORT" ]]; then
    # Fallback neu sshd chua chay
    DETECTED_PORT=$(grep -i "^[[:space:]]*Port" /etc/ssh/sshd_config | head -n 1 | awk '{print $2}' || true)
fi
SSH_PORT=${DETECTED_PORT:-22}
echo -e "   - SSH Port detected: ${YELLOW}${SSH_PORT}${NC}"

# Tao file cau hinh rieng cho SSH
# LUU Y: Khong can khai bao logpath vi da dung backend=systemd
cat > /etc/fail2ban/jail.d/99-ssh-wpsila.conf <<EOF
[sshd]
enabled = true
port = $SSH_PORT
mode = aggressive
EOF
# mode = aggressive giup bat duoc nhieu dang tan cong SSH hon (DDOS, Auth fail...)
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# --- 4. KHỞI ĐỘNG & VERIFY ---
echo -e "${GREEN}>>> [CORE] Khoi dong Fail2Ban...${NC}"

systemctl unmask fail2ban > /dev/null 2>&1 || true

if systemctl restart fail2ban; then
    echo "   - Dang cho Fail2Ban khoi tao socket (10s)..."
    sleep 10
    
    if fail2ban-client status sshd > /dev/null 2>&1; then
        echo -e "${GREEN}SUCCESS: Fail2Ban da bao ve SSH (Port ${SSH_PORT})!${NC}"
        echo "--------------------------------------------------------"
        fail2ban-client status sshd
        echo "--------------------------------------------------------"
    else
        echo -e "${RED}ERROR: Service chay nhung Jail SSH khong load duoc.${NC}"
        echo "Debug log:"
        journalctl -u fail2ban --no-pager -n 20
        exit 1
    fi
else
    echo -e "${RED}ERROR: Khong the start Fail2Ban.${NC}"
    fail2ban-client -d
    exit 1
fi
echo "-------------------------------------------------------------"
# -------------------------------------------------------------------------------------------------------------------------------